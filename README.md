# PharmaSafe
A database-enforced pharmacy safety system built with MySQL and MS Access. Features a 13-entity normalized schema, 8 triggers that detect drug interactions, block contraindicated prescriptions, validate pharmacist identity, prevent over-dispensing, an ACID stored procedure, ETL pipeline, and a Python analytics dashboard.
## 💊 Drug Interaction & Prescription Safety Management System

> **A full-stack pharmacy safety system where the database itself is the safety net — not the application.**

---

## 📖 Overview

PharmaSafe is a database-enforced pharmacy safety and prescription management system built as a final project for **CS2013 — Introduction to Database Systems** at **FAST-NUCES, Islamabad (Spring 2026)**. It addresses one of the most critical yet overlooked problems in healthcare: prescription errors caused by dangerous drug interactions, incorrect dispensing, and poor inventory tracking.

Most pharmacy systems enforce their safety rules inside the application layer — inside buttons, forms, and frontend code. If someone connects directly to the database and inserts a row manually, all those checks are bypassed. **PharmaSafe is designed differently.** Every safety rule — from drug interaction detection to over-dispensing prevention — lives inside MySQL itself through triggers, constraints, and stored procedures. No matter how you access the database (MS Access, MySQL Workbench, phpMyAdmin, or the command line), the rules always fire.

---

## ✨ Key Features

- 🔬 **Automatic Drug Interaction Detection** — triggers scan a patient's current medications and compute interaction severity (Minor / Moderate / Severe / Contraindicated) on every new prescription item
- 🚫 **Contraindication Blocking** — database-level SIGNAL prevents dispensing of contraindicated drug pairs
- 💉 **Dispensing Validation Chain** — 4 BEFORE triggers verify pharmacist identity, patient ownership, prescribed quantity limits, and stock availability before any dispense is logged
- 📦 **Real-time Inventory Tracking** — AFTER triggers automatically deduct stock on successful dispense and write restock alerts when levels fall below threshold
- 🔄 **ACID Transaction Wrapper** — `DispenseItem` stored procedure ensures the entire dispense workflow is atomic; any failure rolls back everything
- 🗂️ **ETL Pipeline** — Python script ingests drug interaction data from DrugBank/FDA CSV exports, cleans and normalizes it, and bulk-loads via `LOAD DATA LOCAL INFILE`
- 📊 **Analytics Dashboard** — Python + matplotlib charts showing top dispensed drugs and interaction severity distribution
- 🖥️ **MS Access Front-End** — 4 forms with cascading combos, auto-fill fields, conditional formatting, and real-time trigger error popups via ODBC

---

## 🗄️ Database Schema

13 core entities + `RestockAlert` auxiliary table, fully normalized to **3NF/BCNF**.

| Entity | Purpose |
|---|---|
| `Category` | Therapeutic drug classes |
| `Drug` | Master medicine catalogue |
| `Ingredient` | Active pharmaceutical ingredients |
| `DrugIngredient` | M:N bridge between Drug and Ingredient |
| `Interaction` | Dangerous drug pairs with severity levels |
| `Doctor` | Prescriber records |
| `Patient` | Patient profiles including allergy notes |
| `PharmacyBranch` | Physical pharmacy locations |
| `Pharmacist` | Staff tied to specific branches |
| `Prescription` | Doctor-written prescription headers |
| `PrescriptionItem` | Individual drug lines with AlertLevel |
| `Inventory` | Per-branch stock counts with reorder thresholds |
| `DispensingLog` | Immutable audit log of every dispense event |
| `RestockAlert` | Auto-populated by inventory trigger |

---

## ⚡ 8 Safety Triggers

| Trigger | When | What It Does |
|---|---|---|
| `trg_pi_before_insert` | BEFORE INSERT on PrescriptionItem | Detects interactions, sets AlertLevel, blocks Contraindicated dispenses |
| `trg_pi_check_stock` | BEFORE INSERT on PrescriptionItem | Blocks prescription if quantity exceeds branch stock |
| `trg_pi_check_quantity` | BEFORE INSERT on PrescriptionItem | Rejects extreme or negative quantities |
| `trg_dispensing_validate_pharmacist` | BEFORE INSERT on DispensingLog | Verifies pharmacist is assigned to this branch |
| `trg_dispensing_validate_patient` | BEFORE INSERT on DispensingLog | Verifies patient owns the prescription |
| `trg_dispensing_validate_quantity` | BEFORE INSERT on DispensingLog | Prevents cumulative over-dispensing across visits |
| `trg_dispensing_after_insert` | AFTER INSERT on DispensingLog | Deducts dispensed quantity from inventory |
| `trg_inventory_after_update` | AFTER UPDATE on Inventory | Writes RestockAlert when stock falls below threshold |

---

## 🔒 ACID Transaction

The `DispenseItem` stored procedure wraps the entire dispense workflow in `START TRANSACTION ... COMMIT` with an `EXIT HANDLER FOR SQLEXCEPTION` that calls `ROLLBACK` on any failure. Inside: re-reads AlertLevel under `FOR UPDATE` lock, verifies stock, inserts the DispensingLog row (firing all triggers), and marks the item as Dispensed. If anything fails, everything rolls back atomically.

---

## 🖥️ MS Access Forms

| Form | Purpose |
|---|---|
| Drug Entry | Add/update drug catalogue with ENUM-backed combo boxes |
| Prescription | Parent form + embedded subform; AlertLevel set by trigger and colour-coded 🔴🟠🟡🟢 |
| PrescriptionItem | Datasheet subform embedded inside Prescription |
| Dispensing | Cascading combos, auto-fill quantity, locked fields, Save & Next button |

---

## 📊 Views & Queries

| # | Name | Technique |
|---|---|---|
| View 1 | ActivePatientMedications | Last-90-days join across 5 tables |
| View 2 | SevereDrugPairs | Pre-filtered Severe/Contraindicated interactions |
| Q1 | Full Prescription Print | 5-table JOIN + LEFT JOIN to interaction view |
| Q2 | Dangerous Combo Rankings | GROUP BY pair + COUNT |
| Q3 | At-Risk Patient List | Correlated EXISTS sub-query |
| Q4 | Dispensing Frequency Report | GROUP BY with ROLLUP |
| Q5 | Inventory Reorder Report | Data source for Access grouped report |
| Q6 | Doctor Prescribing Patterns | COUNT DISTINCT + severity percentage |

---

## 🐍 Python Scripts

**`analytics_dashboard.py`** — connects via `mysql-connector-python`, generates a horizontal bar chart of top 10 dispensed drugs and a donut chart of interaction severity distribution using `matplotlib`. Falls back to synthetic data if MySQL is unreachable.

**`etl_pipeline.py`** — Extract → Transform → Resolve → Load pipeline for DrugBank/FDA interaction data. Normalizes severity casing, removes self-pairs, deduplicates (A,B)↔(B,A), resolves drug names to IDs, and bulk-loads via `LOAD DATA LOCAL INFILE`. Fully idempotent.

---

## 🛡️ Safety Matrix

| Rule | Enforced By |
|---|---|
| Drug interaction detection | `trg_pi_before_insert` |
| Block contraindicated dispensing | SIGNAL in `trg_pi_before_insert` |
| Prescription vs. stock check | `trg_pi_check_stock` |
| Sane prescription quantities | `trg_pi_check_quantity` |
| Pharmacist branch match | `trg_dispensing_validate_pharmacist` |
| Patient prescription ownership | `trg_dispensing_validate_patient` |
| No cumulative over-dispensing | `trg_dispensing_validate_quantity` |
| No negative stock | `CHECK (QuantityInStock >= 0)` |
| No self-interactions | `CHECK (DrugID_A <> DrugID_B)` |
| No future date of birth | `CHECK (DOB <= CURRENT_DATE)` |
| Unique drug formulations | `UNIQUE(GenericName, Strength, DosageForm)` |

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Database | MySQL 8.0 |
| Front-End | Microsoft Access |
| ODBC Driver | MySQL Connector/ODBC 8.0 |
| Analytics | Python 3, matplotlib |
| ETL | Python 3, pandas |

---

## 👥 Author

**Muhammad Shazil Khan**

For serious inquiries, contact: shazilk82@gmail.com

---

> *"Application code can come and go — but the rules stay."*
