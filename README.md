# SME Invoice Audit DB — Municipal Procurement & Tax Compliance Auditor

## Overview
A relational database and analytical SQL audit system designed for municipal internal auditors and financial controllers. The project models an audit workflow reviewing supplier invoices submitted against municipal procurement awards, enforcing referential integrity and detecting billing anomalies and statutory VAT discrepancies under Kosovo Law No. 05/L-037.

## Data Provenance & Ethics
All suppliers, procurement awards, invoices, and line-item records in this project are **strictly synthetic demonstration fixtures**. Identifiers use synthetic naming conventions (e.g., `SYNTH-TAX-1001`, `SYNTH-616-23-001-521`). Contracting authority names (*Komuna e Prishtines*, *Komuna e Prizrenit*, etc.) reflect authentic administrative structures, but no authentic registered business or taxpayer data is used.

## Repository Structure
```
sme-invoice-audit-db/
├── data/                  # Seed datasets and fixture files (Checkpoint 5)
├── docs/
│   ├── modeling_strategy.md
│   ├── data_dictionary.md
│   └── anomaly_injection_plan.md
├── sql/
│   ├── schema.sql         # DDL: CREATE TABLE, indexes, PRAGMA
│   └── verify_schema.sql  # Constraint verification test suite
├── .gitignore             # Excludes binary databases and temporary locks
└── README.md
```

## How to Recreate the Database
```powershell
sqlite3 audit.db ".read sql/schema.sql"
```

Creates `audit.db` in the project root with four tables (`vendors`, `procurement_awards`, `invoices`, `invoice_line_items`), all constraints, and three indexes. `audit.db` is git-ignored.

## How to Verify the Schema
```powershell
sqlite3 audit.db ".read sql/verify_schema.sql" 2>&1
```

The verification script wraps all inserts in a transaction and rolls back at the end. Expected output:

- **Inside transaction:** four counts, all equal to 1 (positive insertion chain succeeded)
- **Seven error messages** — each one a rejected constraint violation (foreign key ×2, CHECK ×3, UNIQUE ×1, NOT NULL ×1)
- **Post-rollback:** four counts, all equal to 0 (rollback confirmed — database is left empty)

## Documentation
- [Data Dictionary](docs/data_dictionary.md)
- [Modeling Strategy](docs/modeling_strategy.md)
- [Anomaly Injection Plan](docs/anomaly_injection_plan.md)