
import argparse
import os
import sys
import pandas as pd

try:
    import mysql.connector
except ImportError:
    print("[!] mysql-connector-python not installed.")
    print("    Run: pip install mysql-connector-python")
    sys.exit(1)


VALID_SEVERITY = {"Minor", "Moderate", "Severe", "Contraindicated"}

# 1. EXTRACT

def extract(csv_path: str) -> pd.DataFrame:
    print(f"[E] Reading {csv_path}")
    df = pd.read_csv(csv_path)
    print(f"    -> {len(df)} raw rows")
    return df

# 2. TRANSFORM / CLEAN

def transform(df: pd.DataFrame) -> pd.DataFrame:
    print("[T] Cleaning & normalising data")

    # strip whitespace from text columns
    for col in df.select_dtypes(include=["object", "string"]).columns:
        df[col] = df[col].astype(str).str.strip()

    # normalise severity capitalisation
    df["severity"] = df["severity"].str.title()

    # filter to allowed severity values
    bad = df[~df["severity"].isin(VALID_SEVERITY)]
    if len(bad):
        print(f"    Dropping {len(bad)} rows with invalid severity")
    df = df[df["severity"].isin(VALID_SEVERITY)].copy()

    # drop nulls in critical cols
    df = df.dropna(subset=["drug_a_name", "drug_b_name", "severity"])

    # remove identical-drug rows
    df = df[df["drug_a_name"].str.lower() != df["drug_b_name"].str.lower()]

    # canonicalise the pair so (A,B) and (B,A) collapse to one row
    pair = df[["drug_a_name", "drug_b_name"]].apply(
        lambda r: tuple(sorted([r.iloc[0].lower(), r.iloc[1].lower()])), axis=1
    )
    df["_pair"] = pair
    df = df.drop_duplicates(subset="_pair", keep="first").drop(columns="_pair")

    print(f"    -> {len(df)} clean rows after dedup / validation")
    return df

# 3. RESOLVE DRUG IDs FROM THE DB

def resolve_ids(df: pd.DataFrame, conn) -> pd.DataFrame:
    print("[T] Resolving drug names -> DrugIDs from DB")
    cur = conn.cursor()
    cur.execute("SELECT DrugID, GenericName FROM Drug")
    name_to_id = {row[1].lower(): row[0] for row in cur.fetchall()}
    cur.close()

    df["DrugID_A"] = df["drug_a_name"].str.lower().map(name_to_id)
    df["DrugID_B"] = df["drug_b_name"].str.lower().map(name_to_id)

    unresolved = df[df["DrugID_A"].isna() | df["DrugID_B"].isna()]
    if len(unresolved):
        print(f"    Skipping {len(unresolved)} rows whose drugs are not in Drug table")
        for _, r in unresolved.iterrows():
            print(f"       (could not resolve: {r['drug_a_name']!r} / {r['drug_b_name']!r})")
    df = df.dropna(subset=["DrugID_A", "DrugID_B"]).copy()
    df["DrugID_A"] = df["DrugID_A"].astype(int)
    df["DrugID_B"] = df["DrugID_B"].astype(int)
    return df

# 4. WRITE CLEAN CSV (consumed by LOAD DATA LOCAL INFILE)

def write_clean(df: pd.DataFrame, out_path: str) -> None:
    print(f"[T] Writing cleaned file -> {out_path}")
    out = df[
        ["DrugID_A", "DrugID_B", "severity", "mechanism",
         "clinical_effect", "management"]
    ].rename(columns={
        "severity":         "SeverityLevel",
        "mechanism":        "MechanismDescription",
        "clinical_effect":  "ClinicalEffect",
        "management":       "ManagementRecommendation",
    })
    out.to_csv(out_path, index=False, encoding="utf-8")

# 5. BULK LOAD

def load(conn, clean_csv: str) -> None:
    print("[L] Bulk loading via LOAD DATA LOCAL INFILE")
    abspath = os.path.abspath(clean_csv).replace("\\", "/")
    cur = conn.cursor()

    # Clean target table first (idempotent re-run)
    cur.execute("DELETE FROM Interaction")

    sql = f"""
        LOAD DATA LOCAL INFILE '{abspath}'
        INTO TABLE Interaction
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\\n'
        IGNORE 1 LINES
        (DrugID_A, DrugID_B, SeverityLevel,
         MechanismDescription, ClinicalEffect, ManagementRecommendation)
    """
    try:
        cur.execute(sql)
        conn.commit()
        print(f"    -> Loaded {cur.rowcount} rows into Interaction")
    except mysql.connector.Error as e:
        # Fallback: row-by-row insert if LOCAL INFILE is disabled on the server
        print(f"    LOAD DATA failed ({e.msg}); falling back to row INSERTs")
        df = pd.read_csv(clean_csv)
        for _, r in df.iterrows():
            cur.execute(
                """INSERT IGNORE INTO Interaction
                   (DrugID_A, DrugID_B, SeverityLevel,
                    MechanismDescription, ClinicalEffect, ManagementRecommendation)
                   VALUES (%s,%s,%s,%s,%s,%s)""",
                tuple(r),
            )
        conn.commit()
        print(f"    -> Inserted {len(df)} rows via fallback")
    finally:
        cur.close()

# MAIN

def main():
    p = argparse.ArgumentParser(description="PharmaSafe ETL pipeline")
    p.add_argument("--csv", default="../data/drug_interactions_raw.csv")
    p.add_argument("--host", default="localhost")
    p.add_argument("--user", default="root")
    p.add_argument("--password", default="")
    p.add_argument("--db", default="pharmasafe")
    p.add_argument("--out", default="../data/drug_interactions_clean.csv")
    args = p.parse_args()

    df = extract(args.csv)
    df = transform(df)

    print("[*] Connecting to MySQL")
    conn = mysql.connector.connect(
        host=args.host, user=args.user, password=args.password,
        database=args.db, allow_local_infile=True,
    )
    try:
        df = resolve_ids(df, conn)
        write_clean(df, args.out)
        load(conn, args.out)
        print("[OK] ETL pipeline finished successfully.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
