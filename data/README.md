# Seed Data & Fixture Directory

This directory is designated for raw tabular data files, external reference schedules, and analytical export artifacts.

## Current Seeding Strategy
To guarantee 100% offline reproducibility without requiring external Python data-loading packages or CSV parsers, the primary seed dataset for this project is implemented as pure SQL DML statements in:
`sql/seed_data.sql`

Executing `sql/seed_data.sql` directly seeds the relational schema with our 4 synthetic vendors, 4 procurement awards, 24 invoices, and 25 line items, complete with inline financial validation checks.

## Future Directory Usage
As the project evolves, this directory is reserved for:
1. **Raw CSV Ingestion:** Bulk CSV exports of synthetic procurement notices or historical test fixtures for automated staging ingestion.
2. **Statutory Reference Schedules:** Static mapping files (e.g., CSV lookups of CPV codes and corresponding Kosovo VAT classifications under Law No. 05/L-037).
3. **Audit Exception Exports:** Automated exports of analytical query results (e.g., `flagged_duplicates.csv`, `vat_discrepancies.csv`) generated for review by municipal financial controllers.