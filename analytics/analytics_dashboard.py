import argparse
import os
import sys
import pandas as pd
import matplotlib

matplotlib.use("Agg")          # headless rendering for terminals/servers
import matplotlib.pyplot as plt

try:
    import mysql.connector
    HAS_MYSQL = True
except ImportError:
    HAS_MYSQL = False


# Brand palette (matches PharmaSafe theme)
SEVERITY_COLORS = {
    "None":            "#9ca3af",
    "Minor":           "#60a5fa",
    "Moderate":        "#fbbf24",
    "Severe":          "#f97316",
    "Contraindicated": "#dc2626",
}


def load_data(args):
    """Returns (top10_df, severity_df). Falls back to demo data if no DB."""
    if not HAS_MYSQL:
        print("[!] mysql-connector-python not installed - using demo data")
        return _demo_data()

    try:
        conn = mysql.connector.connect(
            host=args.host, user=args.user, password=args.password,
            database=args.db,
        )
    except mysql.connector.Error as e:
        print(f"[!] Cannot reach MySQL ({e.msg}) - using demo data")
        return _demo_data()

    print("[*] Connected to MySQL - querying live data")
    top10 = pd.read_sql(
        """
        SELECT d.GenericName AS Drug, SUM(dl.DispensedQty) AS QtyDispensed
        FROM DispensingLog dl
        JOIN PrescriptionItem pi ON pi.ItemID = dl.ItemID
        JOIN Drug             d  ON d.DrugID  = pi.DrugID
        GROUP BY d.GenericName
        ORDER BY QtyDispensed DESC
        LIMIT 10
        """,
        conn,
    )
    severity = pd.read_sql(
        """
        SELECT SeverityLevel AS Severity, COUNT(*) AS Cnt
        FROM Interaction
        GROUP BY SeverityLevel
        ORDER BY FIELD(SeverityLevel,'Minor','Moderate','Severe','Contraindicated')
        """,
        conn,
    )
    conn.close()
    return top10, severity


def _demo_data():
    top10 = pd.DataFrame({
        "Drug": ["Paracetamol", "Metformin", "Aspirin", "Lisinopril",
                 "Warfarin", "Amoxicillin", "Omeprazole", "Ibuprofen",
                 "Fluoxetine", "Simvastatin"],
        "QtyDispensed": [300, 180, 120, 90, 80, 70, 65, 60, 45, 30],
    })
    severity = pd.DataFrame({
        "Severity": ["Minor", "Moderate", "Severe", "Contraindicated"],
        "Cnt":      [2,        4,          5,        1],
    })
    return top10, severity

def plot_top10(df: pd.DataFrame, out: str):
    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.barh(df["Drug"][::-1], df["QtyDispensed"][::-1],
                   color="#2563eb", edgecolor="white", linewidth=1.2)
    for bar, val in zip(bars, df["QtyDispensed"][::-1]):
        ax.text(val + max(df["QtyDispensed"]) * 0.01,
                bar.get_y() + bar.get_height() / 2,
                f"{val:,}", va="center", fontsize=10, color="#1f2937")

    ax.set_title("Top 10 Dispensed Drugs", fontsize=15, fontweight="bold", pad=14)
    ax.set_xlabel("Quantity Dispensed (units)", fontsize=11)
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(axis="x", linestyle=":", alpha=0.5)

    plt.tight_layout()
    plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"   wrote {out}")

def plot_severity(df: pd.DataFrame, out: str):
    fig, ax = plt.subplots(figsize=(8, 6))
    colors = [SEVERITY_COLORS.get(s, "#999999") for s in df["Severity"]]

    wedges, texts, autotexts = ax.pie(
        df["Cnt"], labels=df["Severity"], colors=colors, autopct="%1.0f%%",
        startangle=90, pctdistance=0.78, wedgeprops=dict(width=0.42, edgecolor="white", linewidth=2),
        textprops=dict(fontsize=11),
    )
    for at in autotexts:
        at.set_color("white")
        at.set_fontweight("bold")

    ax.set_title("Drug Interaction Severity Distribution",
                 fontsize=15, fontweight="bold", pad=18)
    plt.tight_layout()
    plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"   wrote {out}")


def plot_dashboard(top10: pd.DataFrame, severity: pd.DataFrame, out: str):
    fig = plt.figure(figsize=(16, 7))
    fig.suptitle("PharmaSafe - Analytics Dashboard",
                 fontsize=18, fontweight="bold", y=0.98)

    # left: bar chart
    ax1 = fig.add_subplot(1, 2, 1)
    ax1.barh(top10["Drug"][::-1], top10["QtyDispensed"][::-1],
             color="#2563eb", edgecolor="white", linewidth=1.2)
    ax1.set_title("Top 10 Dispensed Drugs", fontsize=13, fontweight="bold")
    ax1.set_xlabel("Quantity Dispensed")
    ax1.spines[["top", "right"]].set_visible(False)
    ax1.grid(axis="x", linestyle=":", alpha=0.5)

    # right: pie
    ax2 = fig.add_subplot(1, 2, 2)
    colors = [SEVERITY_COLORS.get(s, "#999") for s in severity["Severity"]]
    wedges, texts, autos = ax2.pie(
        severity["Cnt"], labels=severity["Severity"], colors=colors,
        autopct="%1.0f%%", startangle=90, pctdistance=0.78,
        wedgeprops=dict(width=0.42, edgecolor="white", linewidth=2),
        textprops=dict(fontsize=10),
    )
    for at in autos:
        at.set_color("white")
        at.set_fontweight("bold")
    ax2.set_title("Interaction Severity Distribution", fontsize=13, fontweight="bold")

    plt.tight_layout()
    plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"   wrote {out}")


def main():
    p = argparse.ArgumentParser(description="PharmaSafe analytics dashboard")
    p.add_argument("--host", default="localhost")
    p.add_argument("--user", default="root")
    p.add_argument("--password", default="")
    p.add_argument("--db", default="pharmasafe")
    p.add_argument("--outdir", default=".")
    args = p.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    top10, severity = load_data(args)

    print("[*] Generating charts ...")
    plot_top10(top10, os.path.join(args.outdir, "top10_dispensed.png"))
    plot_severity(severity, os.path.join(args.outdir, "severity_distribution.png"))
    plot_dashboard(top10, severity, os.path.join(args.outdir, "dashboard.png"))
    print("[OK] All charts written.")


if __name__ == "__main__":
    main()
