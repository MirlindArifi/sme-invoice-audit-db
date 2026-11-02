# Entity-Relationship (ER) Diagram

This diagram documents the physical relational model implemented in `sql/schema.sql`.

```mermaid
erDiagram
    VENDORS ||--o{ PROCUREMENT_AWARDS : "awarded"
    VENDORS ||--o{ INVOICES : "billed_by"
    PROCUREMENT_AWARDS ||--o{ INVOICES : "billed_against"
    INVOICES ||--o{ INVOICE_LINE_ITEMS : "contains"

    VENDORS {
        INTEGER vendor_id PK "AUTOINCREMENT"
        TEXT fiscal_identifier UK "SYNTH-TAX-XXXX"
        TEXT vendor_name "Fictional Supplier Name"
        TEXT vendor_type "Legal Form (SH.P.K. / B.I.)"
        INTEGER is_synthetic "CHECK (is_synthetic = 1)"
    }

    PROCUREMENT_AWARDS {
        INTEGER award_id PK "AUTOINCREMENT"
        TEXT procurement_number UK "SYNTH-XXX-XX-XXX-XXX"
        TEXT authority_name "Municipality Name"
        INTEGER vendor_id FK "REFERENCES vendors(vendor_id)"
        TEXT award_date "ISO 8601 (YYYY-MM-DD)"
        NUMERIC recorded_award_value "CHECK (recorded_award_value > 0)"
        TEXT procurement_category "SUPPLIES / SERVICES / WORKS"
    }

    INVOICES {
        INTEGER invoice_id PK "AUTOINCREMENT"
        TEXT invoice_number "Non-unique for duplicate audit"
        INTEGER award_id FK "REFERENCES procurement_awards(award_id)"
        INTEGER billing_vendor_id FK "REFERENCES vendors(vendor_id)"
        TEXT invoice_date "ISO 8601 (YYYY-MM-DD)"
        NUMERIC recorded_total "CHECK (recorded_total >= 0)"
    }

    INVOICE_LINE_ITEMS {
        INTEGER line_item_id PK "AUTOINCREMENT"
        INTEGER invoice_id FK "REFERENCES invoices(invoice_id)"
        TEXT item_category "Audited against statutory schedule"
        TEXT description "Delivered goods/services"
        NUMERIC quantity "CHECK (quantity > 0)"
        NUMERIC unit_price "CHECK (unit_price >= 0)"
        NUMERIC line_subtotal "CHECK (line_subtotal >= 0)"
        NUMERIC vat_rate "CHECK (vat_rate >= 0 AND vat_rate <= 100)"
        NUMERIC vat_amount "CHECK (vat_amount >= 0)"
        NUMERIC line_total "CHECK (line_total >= 0)"
    }
```

## Relational Cardinalities & Keys
- **vendors to procurement_awards (1:N)**: A vendor can be awarded multiple public contracts; an award belongs to exactly one winning vendor.
- **procurement_awards to invoices (1:N)**: An award can be billed progressively across multiple invoices; an invoice references exactly one procurement award.
- **vendors to invoices (1:N)**: An invoice header identifies one billing vendor entity (`billing_vendor_id`), which is audited against `procurement_awards.vendor_id` to flag unauthorized third-party billing.
- **invoices to invoice_line_items (1:N)**: An invoice contains one or more itemized lines; a line item belongs to exactly one parent invoice.