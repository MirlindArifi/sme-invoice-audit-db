# SME Invoice Audit DB — Municipal Procurement & Tax Compliance Auditor

A relational database and analytical SQL audit suite designed for municipal internal auditors and public finance controllers. The project models an audit workflow that reviews supplier invoices submitted against municipal procurement awards in Kosovo, enforcing relational integrity constraints and detecting billing anomalies, contract threshold overruns, and statutory VAT discrepancies under Kosovo Law No. 05/L-037.

---

## The Business Problem

Municipal public finance departments process thousands of supplier invoices annually across public works, goods supplies, and municipal services. Manual spreadsheet reviews often fail to detect:
- Duplicate payment claims submitted across different billing cycles.
- Arithmetic errors between unit prices, line subtotals, and invoice headers.
- Tax misclassifications (e.g., applying the restricted 8% reduced VAT rate to standard-rated commercial goods, or arbitrary foreign tax rates).
- Progressive billing that silently exceeds authorized procurement contract ceilings.
- Unauthorized third-party billing where the invoicing entity does not match the legally awarded contractor.

This project implements a normalized relational database engine and reproducible SQL audit queries to automate these controls and surface explainable audit exceptions.

---

## Data Provenance & Ethics

- **Strictly Synthetic Fixtures:** All suppliers, procurement awards, invoices, and line-item records in this database are **100% synthetic demonstration fixtures**.
- **No Accusations Against Real Businesses:** To protect commercial reputations, fictional company names (e.g., *Dardania Tech Solutions SH.P.K.*) and synthetic tax identifiers (`SYNTH-TAX-1001`) are used exclusively. Database-level constraints (`CHECK (is_synthetic = 1)`) guarantee that non-synthetic entities cannot be stored.
- **Administrative Context:** Municipal authority names (*Komuna e Prishtines*, *Komuna e Prizrenit*, *Komuna e Pejes*) and procurement numbering patterns (`SYNTH-616-23-001-521`) reflect authentic Kosovo public administration structures.
- **Why Synthetic Invoices?** While public procurement platforms (e.g., KRPP) publish tender notices and award metadata, itemized supplier invoices are private treasury documents submitted directly to municipal finance departments. Modeled synthetic fixtures enable full testing of invoice-level audit logic without compromising private accounting data.

---

## Relational Schema & Design Highlights

The database is implemented in **SQLite 3** and structured in Third Normal Form (3NF):

```text
[vendors] 1 ──< awarded >── N [procurement_awards]
    │                              │
    │ billed_by                    │ billed_against
    v                              v
    └───────────────> N [invoices]
                           │
                           │ contains
                           v
                    N [invoice_line_items]
```

### Core Design Decisions:
1. **Audit Staging vs. Operational Constraints:** The `invoices.invoice_number` column intentionally lacks a `UNIQUE` constraint, and `invoice_line_items.vat_rate` permits rates between `0` and `100`. An audit staging database must be able to ingest erroneous external submissions so that analytical queries can discover and report them, rather than failing at write-time.
2. **Third-Party Billing Audit:** Invoices carry an explicit `billing_vendor_id` foreign key, allowing Query 5 to audit whether the invoicing entity matches the legally awarded vendor on the contract (`procurement_awards.vendor_id`).
3. **Monetary Precision Handling:** Because SQLite does not feature an arbitrary-precision fixed-point decimal type, currency amounts use `NUMERIC` affinity. All analytical calculations explicitly wrap operations in `ROUND(..., 2)` and cast expressions to floating-point (`REAL`) to avoid integer division truncation artifacts.

---

## Analytical Audit Queries & Test Results

The SQL audit engine executes five core analytical queries (`sql/audit_queries.sql`), validated against positive test anomalies and clean control baselines:

| # | Audit Query | Business Question | Test Result on Seed Dataset |
|---|:---|:---|:---|
| **1** | **Duplicate Invoice Reference Detection** | Has a vendor submitted the same invoice number more than once, or submitted identical amounts on the same date? | Correctly flags `SYNTH-INV-2023-0102` (Vendor 1, 2 submissions). Selectively ignores legitimate identical invoice numbers across different vendors. |
| **2** | **Line & Header Arithmetic Reconciliation** | Do line-item calculations (`qty * price = subtotal`, `subtotal + vat = total`) and header sums match? | Flags Line 8 (subtotal error), Line 9 (line total error), and Invoice 10 (header total €500.00 vs calculated €354.00). |
| **3** | **VAT Classification & Computation Audit** | Does the VAT rate match Law No. 05/L-037 (18% standard vs. 8% reduced under Art. 26(2)), and does `vat_amount` compute correctly? | Correctly categorizes: Line 13 (Under-taxation: 8% on furniture), Line 14 (Over-taxation: 18% on IT), Lines 15–17 (Rate outliers: 0%, 5%, 20%), Line 18 (Arithmetic difference of -€600.00). |
| **4** | **Recorded Award Value Overrun** | Does cumulative billed invoice expenditure exceed the baseline contract award ceiling? | Flags Award 4 (Peja, Supplies): €16,740.00 billed against €15,000.00 ceiling (111.60% utilization, €1,740.00 overrun). Ignores compliant Award 2 (€18,156.00 / €20,000.00). |
| **5** | **Vendor Exception Summary & Entity Mismatch** | Did an unauthorized vendor bill against another contractor's award, and what is each vendor's total financial exposure? | Flags Invoice 24 (Awarded to Kastrioti Works, billed by Prishtina Medical). Summarizes invoice volume and exception counts across all 4 vendors. |

---

## Quickstart: How to Recreate and Verify

### Prerequisites
- Git
- SQLite 3 command-line interface

### 1. Clone the Repository
```powershell
git clone https://github.com/MirlindArifi/sme-invoice-audit-db.git
cd sme-invoice-audit-db
```

### 2. Initialize Database Schema
Creates the 4 normalized tables and indexes:
```powershell
sqlite3 audit.db ".read sql/schema.sql"
```

### 3. Run Automated Constraint & Integrity Verification
Executes the test suite of positive insertion chains and 7 negative constraint tests:
```powershell
sqlite3 audit.db ".read sql/verify_schema.sql" 2>&1
```
*Expected output: Exactly 7 constraint violation errors on STDERR, with clean row counts on STDOUT.*

### 4. Seed the Database
Populates the database with 4 vendors, 4 awards, 24 invoices, and 25 line items:
```powershell
sqlite3 audit.db ".read sql/seed_data.sql"
```

### 5. Execute Analytical Audit Queries
Runs all five analytical audit queries and outputs the exception reports:
```powershell
sqlite3 -header -column audit.db ".read sql/audit_queries.sql"
```

---

## Repository Structure

```text
sme-invoice-audit-db/
├── data/
│   └── .gitkeep                 # Seed data and fixture directory
├── docs/
│   ├── anomaly_injection_plan.md# Test plan mapping all positive/negative test cases
│   ├── data_dictionary.md       # Full schema specifications, types, and constraints
│   ├── er_diagram.md            # Mermaid.js relational Entity-Relationship diagram
│   └── modeling_strategy.md     # Ethical provenance and identifier conventions
├── sql/
│   ├── audit_queries.sql        # The 5 analytical audit queries
│   ├── schema.sql               # Core DDL schema initialization
│   ├── seed_data.sql            # Seed dataset (24 invoices, 25 line items)
│   └── verify_schema.sql        # Automated constraint verification suite
├── .gitignore                   # Excludes SQLite binaries (*.db) and OS artifacts
└── README.md                    # Project overview and documentation
```

---

## Technical Limitations & Assumptions

- **Synthetic Nature:** The dataset is intentionally modeled to provide controlled test fixtures. It does not reflect real business fraud or non-compliance in Kosovo.
- **Gross-of-VAT Award Baseline:** For the purposes of this MVP, `procurement_awards.recorded_award_value` is evaluated directly against invoice gross totals (`recorded_total`). In complex public procurement environments, award values may be defined net of VAT or modified through formal contract annexes.
- **SQLite Floating-Point Affinity:** SQLite lacks native fixed-point arbitrary precision arithmetic (DECIMAL). While `ROUND(..., 2)` eliminates rounding artifacts for our dataset, high-concurrency enterprise accounting typically relies on PostgreSQL fixed-point decimals or integer-cent storage.