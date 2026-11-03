# SME Invoice Audit DB — Municipal Procurement & Tax Compliance Auditor

A relational database and analytical SQL audit suite designed for municipal internal auditors and public finance controllers. The project models an audit workflow that reviews supplier invoices submitted against municipal procurement awards in Kosovo, enforcing relational integrity constraints and detecting billing anomalies, contract value overruns, and potential VAT discrepancies under Kosovo Law No. 05/L-037.

---

## The Business Problem

Municipal public finance departments process thousands of supplier invoices annually across public works, goods supplies, and municipal services. Manual spreadsheet reviews often fail to detect:

- **Duplicate payment claims** submitted across billing cycles or under slightly different invoice numbers.
- **Arithmetic errors** between unit prices, line subtotals, and invoice header totals.
- **Potential VAT misclassifications**: for example, applying the reduced 8% rate to standard-rated commercial goods, or applying a non-statutory rate to a taxable supply.
- **Progressive billing** that runs past the recorded procurement award value without documented amendment.
- **Vendor-mismatch invoices** where the entity that submitted the invoice is not the entity awarded the referenced contract.

This project implements a normalized relational database and reproducible SQL audit queries to automate these controls and surface explainable audit exceptions for review.

---

## Data Provenance & Ethics

- **Strictly synthetic fixtures.** All suppliers, procurement awards, invoices, and line-item records are **100% synthetic demonstration fixtures**. No real invoice data is used.
- **No accusations against real businesses.** Fictional company names and synthetic tax identifiers (`SYNTH-TAX-1001`) are used exclusively. Database-level constraints (`CHECK (is_synthetic = 1)`) physically reject any non-synthetic vendor row.
- **Administrative context.** Municipal authority names and procurement numbering patterns reflect authentic Kosovo public administration structures so that audit logic is transferable to real records.
- **Why synthetic invoices?** Itemized supplier invoices are private treasury documents, not public procurement records. See [`docs/data_feasibility.md`](docs/data_feasibility.md) for the full source investigation.

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

### Core Design Decisions

1. **Audit staging vs. operational constraints.** `invoices.invoice_number` intentionally lacks a `UNIQUE` constraint, and `invoice_line_items.vat_rate` permits any value between 0 and 100. An audit database must be able to ingest erroneous external submissions so that analytical queries can surface them rather than rejecting them at write time.
2. **Vendor-mismatch audit.** Invoices carry an explicit `billing_vendor_id` foreign key. Query 5 compares it against `procurement_awards.vendor_id` to identify invoices submitted by an entity other than the awarded contractor.
3. **Monetary precision handling.** SQLite does not have an arbitrary precision fixed-point decimal type, so currency amounts use `NUMERIC` affinity. All analytical calculations wrap operations in `ROUND(..., 2)` and cast to `REAL` where division is involved, to avoid integer truncation artifacts.

---

## Analytical Audit Queries & Test Results

The SQL audit engine implements seven analytical queries in `sql/audit_queries.sql`, grouped into five audit categories. `sql/test_queries.sql` asserts the expected exception counts against the seed dataset.

| # | Audit | Business Question | Expected Result on Seed Dataset |
|---|---|---|---|
| 1 | Duplicate Invoice Reference Detection | Has a vendor submitted the same invoice number more than once, or submitted distinct invoice numbers that share the same award, date, and amount? | Flags `SYNTH-INV-2023-0102` (Vendor 1, two submissions) as `DUPLICATE_INVOICE_NUMBER`, and `SYNTH-INV-2023-0103` / `SYNTH-INV-2023-0104` (Vendor 2, identical billing context) as `SUSPECTED_SPLIT_OR_DUPLICATE_CLAIM`. Correctly ignores `SYNTH-INV-2023-0101` across Vendors 1 and 2. |
| 2 | Line & Header Arithmetic Reconciliation | Do line-item calculations (qty × price = subtotal, subtotal + VAT = total) and header sums match? | Flags Line 8 (subtotal overstated by €200.00), Line 9 (line total overstated by €130.00), and Invoice 10 (header €500.00 vs calculated €354.00, detected via `LEFT JOIN` so invoices without line items are not skipped). |
| 3 | VAT Classification & Computation Review | Does the recorded VAT rate match the MVP's statutory schedule (18% standard, 8% reduced under Art. 26(2)), and does `vat_amount` compute correctly? | Six rows: Line 13 (`POTENTIAL_MISCLASSIFICATION_REDUCED_ON_STANDARD`), Line 14 (`POTENTIAL_OVERCHARGE_STANDARD_ON_REDUCED`), Lines 15–17 (`NON_STATUTORY_RATE`: 0%, 5%, 20%), Line 18 (`VAT_ARITHMETIC_MISMATCH`, −€600.00). Labels identify candidates for review, not conclusions of wrongdoing. |
| 4 | Invoice Totals Exceeding Recorded Award Value | Do cumulative invoice totals for an award exceed the recorded award baseline? | Flags Award 4 (Peja, Supplies): €16,740.00 billed against a recorded award value of €15,000.00 (111.60% utilization, €1,740.00 above the baseline). Does not flag compliant awards. A flag here is a candidate for investigation, not proof of a contract breach. |
| 5 | Vendor Mismatch & Billing Summary | Has an invoice been submitted by a vendor other than the one awarded the referenced contract, and what is each vendor's total billing and mismatch count? | 5A flags Invoice 24 (award to Kastrioti Building, billed by Prishtina Medical). 5B rolls up invoice counts, total billing, and mismatch counts across all four vendors. |

**Scope note on VAT.** Only the 18% standard rate and 8% reduced rate are audited. Exempt supplies under Article 27 of Law No. 05/L-037 (including regulated public passenger transport) are outside the MVP's scope. A rate outside 8%/18% is surfaced as `NON_STATUTORY_RATE` for review, not declared invalid.

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

### 2. Initialize the Database Schema

Creates the four normalized tables and their indexes:

```powershell
sqlite3 audit.db ".read sql/schema.sql"
```

### 3. Run Constraint & Integrity Verification

Executes the test suite of positive insertion chains and seven negative constraint tests:

```powershell
sqlite3 audit.db ".read sql/verify_schema.sql" 2>&1
```

Expected output: exactly seven constraint-violation errors on STDERR (corresponding to the seven deliberate negative tests), with clean row counts on STDOUT (`1,1,1,1` inside the transaction and `0,0,0,0` post-rollback).

### 4. Seed the Database

Populates the database with 4 vendors, 4 awards, 24 invoices, and 25 line items:

```powershell
sqlite3 audit.db ".read sql/seed_data.sql"
```

### 5. Execute Analytical Audit Queries

Prints each exception report:

```powershell
sqlite3 -header -column audit.db ".read sql/audit_queries.sql"
```

### 6. Run Automated Query Regression Tests

Asserts the expected exception count for each analytical query. The suite is standalone and can be run on its own against the seeded database, in any shell session:

```powershell
sqlite3 -header -column audit.db ".read sql/test_queries.sql"
```

Expected output: six rows, all reporting `PASS`.

---

## Repository Structure

```text
sme-invoice-audit-db/
├── data/
│   ├── .gitkeep                      # Ensures directory is tracked by Git
│   └── README.md                     # Seed data and fixture directory overview
├── docs/
│   ├── anomaly_injection_plan.md     # Test plan mapping all positive/negative cases
│   ├── data_dictionary.md            # Schema specifications, types, and constraints
│   ├── data_feasibility.md           # Public procurement vs. private invoice investigation
│   ├── er_diagram.md                 # Mermaid.js Entity-Relationship diagram
│   └── modeling_strategy.md          # Ethical provenance and identifier conventions
├── sql/
│   ├── audit_queries.sql             # Seven analytical audit queries
│   ├── schema.sql                    # Core DDL schema initialization
│   ├── seed_data.sql                 # Seed dataset (24 invoices, 25 line items)
│   ├── test_queries.sql              # Automated query regression tests
│   └── verify_schema.sql             # Automated constraint verification suite
├── .gitignore                        # Excludes SQLite binaries (*.db) and OS artifacts
└── README.md                         # Project overview and documentation
```

---

## Technical Limitations & Assumptions

- **Synthetic nature.** The dataset is intentionally modeled to provide controlled test fixtures. It does not reflect real business fraud or non-compliance in Kosovo.
- **Recorded award value as baseline.** `procurement_awards.recorded_award_value` is compared directly against invoice gross totals. In complex public procurement, award values may be net of VAT or modified by formal contract annexes. Query 4's output is a candidate for investigation, not proof of an unauthorized contract breach.
- **SQLite numeric affinity.** SQLite lacks native fixed-point arbitrary precision arithmetic. `ROUND(..., 2)` eliminates rounding artifacts for the dataset at this scale, but high-concurrency enterprise accounting would typically rely on PostgreSQL `NUMERIC` or integer-cent storage.
- **VAT scope.** Only the 18% standard and 8% reduced rates are audited. Exempt supplies and reduced-rate categories outside the MVP's documented scope are not checked.

---

## Performance Observations

At the demonstration volume (24 invoices, 25 line items, 4 awards, 4 vendors), all audit queries execute in a few milliseconds each on a local SQLite 3 instance. To reproduce the measurement:

```powershell
sqlite3 audit.db
sqlite> .timer on
sqlite> .read sql/audit_queries.sql
```

Record the reported wall-clock times alongside your SQLite version (`sqlite3 --version`) if you intend to quote them, because the numbers are specific to your machine.

The schema deliberately defines two secondary indexes:

- `idx_invoices_award_id`: supports Query 4's aggregation of invoice sums by award.
- `idx_invoices_billing_vendor`: supports Query 5's join and grouping by billing vendor.

These indexes demonstrate indexing practice that would matter at municipal production volumes (tens of thousands of annual procurement transactions), even though the current dataset is small enough that they have negligible impact on observed latency.

---

## Future Improvements

1. **Vendor exception summary view.** A materialized or standard SQL view (`CREATE VIEW v_vendor_exception_summary AS ...`) rolling up duplicate counts, arithmetic flags, vendor-mismatch counts, and total financial exposure into a reusable auditor-facing summary.
2. **PostgreSQL migration.** Move the DDL to PostgreSQL for arbitrary-precision `NUMERIC(12,2)` fixed-point arithmetic, enum types for procurement categories, and connection-level foreign key enforcement by default.
3. **Application and reporting layer.** A lightweight Python CLI or FastAPI service that ingests raw municipal CSV files and exports formatted Excel/PDF audit exception packages.
4. **Automated KRPP ingestion pipeline.** An ETL connector that ingests authentic public tender metadata from Kosovo's OCDS API and reconciles published award baselines against internal treasury invoice submissions.