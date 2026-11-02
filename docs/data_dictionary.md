# Data Dictionary & Schema Specification

## 1. Monetary Precision Rules and SQLite Technical Limitations
- **Storage Affinity:** All currency amounts are stored in Euros (€) using SQLite `NUMERIC` affinity.
- **Floating-Point Limitation:** Unlike production database engines (e.g., PostgreSQL `NUMERIC(12,2)`), SQLite does not provide native arbitrary-precision fixed-point decimal arithmetic. Values with fractional components are represented internally as 64-bit IEEE floating-point numbers (`REAL`).
- **Precision Audit Rule:** To prevent false positives caused by microscopic binary floating-point rounding artifacts (such as `0.1 + 0.2 = 0.30000000000000004`), all SQL analytical queries and reconciliation comparisons **must** wrap arithmetic calculations in `ROUND(expression, 2)`.
- **Date Handling:** Dates are stored as ISO 8601 strings (`YYYY-MM-DD`) using `TEXT` affinity, enabling standard lexicographical comparisons and SQLite `date()` functions.
- **Award Value Interpretation:** `recorded_award_value` is treated in this MVP as a **gross-of-VAT ceiling** for Query 4's aggregate comparison. In real Kosovo public procurement, award values are typically net-of-VAT; this is a documented simplification for the MVP, not a claim of legal accuracy.

---

## 2. Table: `vendors`
Represents registered supplier entities.

| Column | Data Type | Constraints | Description & Audit Role |
| :--- | :--- | :--- | :--- |
| `vendor_id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Relational surrogate primary key. |
| `fiscal_identifier` | `TEXT` | `NOT NULL UNIQUE` | Synthetic tax number (e.g., `SYNTH-TAX-1001`). Enforces business entity uniqueness. |
| `vendor_name` | `TEXT` | `NOT NULL` | Fictional supplier name ending with `(Synthetic)`. |
| `vendor_type` | `TEXT` | `NOT NULL` | Legal entity form (e.g., `SH.P.K.`, `B.I.`). |
| `is_synthetic` | `INTEGER` | `NOT NULL DEFAULT 1 CHECK (is_synthetic = 1)` | Database-level integrity constraint guaranteeing no non-synthetic entities exist. |

---

## 3. Table: `procurement_awards`
Represents municipal procurement awards establishing authorized expenditure baselines.

| Column | Data Type | Constraints | Description & Audit Role |
| :--- | :--- | :--- | :--- |
| `award_id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Relational surrogate primary key. |
| `procurement_number` | `TEXT` | `NOT NULL UNIQUE` | Modeled synthetic tender reference (e.g., `SYNTH-616-23-001-521`). Enforces contract uniqueness. |
| `authority_name` | `TEXT` | `NOT NULL` | Contracting municipal authority (e.g., `Komuna e Prishtinës`). |
| `vendor_id` | `INTEGER` | `NOT NULL REFERENCES vendors(vendor_id)` | Legally awarded vendor entity. |
| `award_date` | `TEXT` | `NOT NULL` | Date contract award was published (`YYYY-MM-DD`). |
| `recorded_award_value`| `NUMERIC` | `NOT NULL CHECK (recorded_award_value > 0)` | Authorized baseline contract value (€). Audited in **Query 4** against cumulative billed invoices. |
| `procurement_category`| `TEXT` | `NOT NULL` | Procurement classification: `SUPPLIES`, `SERVICES`, or `WORKS`. |

---

## 4. Table: `invoices`
Represents supplier payment claims submitted against municipal procurement awards.

| Column | Data Type | Constraints | Description & Audit Role |
| :--- | :--- | :--- | :--- |
| `invoice_id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Relational surrogate primary key. |
| `invoice_number` | `TEXT` | `NOT NULL` | Supplier invoice reference. **Deliberately NOT UNIQUE** to permit ingesting duplicate invoice submissions for detection by **Query 1**. |
| `award_id` | `INTEGER` | `NOT NULL REFERENCES procurement_awards(award_id)` | Contract award being billed against. |
| `billing_vendor_id` | `INTEGER` | `NOT NULL REFERENCES vendors(vendor_id)` | Vendor entity stated on invoice header. Compared against `procurement_awards.vendor_id` in **Query 5** to detect supplier billing mismatches. |
| `invoice_date` | `TEXT` | `NOT NULL` | Date invoice was issued (`YYYY-MM-DD`). |
| `recorded_total` | `NUMERIC` | `NOT NULL CHECK (recorded_total >= 0)` | Billed invoice header total (€). Audited in **Query 2 (Invoice-Level Reconciliation)** against the sum of line totals. |

---

## 5. Table: `invoice_line_items`
Represents itemized goods or services billed within a supplier invoice.

| Column | Data Type | Constraints | Description & Audit Role |
| :--- | :--- | :--- | :--- |
| `line_item_id` | `INTEGER` | `PRIMARY KEY AUTOINCREMENT` | Relational surrogate primary key. |
| `invoice_id` | `INTEGER` | `NOT NULL REFERENCES invoices(invoice_id)` | Foreign key linking line item to parent invoice. |
| `item_category` | `TEXT` | `NOT NULL` | Statutory category (e.g., `IT_EQUIPMENT`, `OFFICE_FURNITURE`). Audited in **Query 3** against Law No. 05/L-037 schedule. |
| `description` | `TEXT` | `NOT NULL` | Itemized description of delivered goods or services. |
| `quantity` | `NUMERIC` | `NOT NULL CHECK (quantity > 0)` | Quantity delivered. |
| `unit_price` | `NUMERIC` | `NOT NULL CHECK (unit_price >= 0)` | Unit price net of VAT (€). |
| `line_subtotal` | `NUMERIC` | `NOT NULL CHECK (line_subtotal >= 0)` | Recorded subtotal (€). Audited in **Query 2** against `ROUND(quantity * unit_price, 2)`. |
| `vat_rate` | `NUMERIC` | `NOT NULL CHECK (vat_rate >= 0 AND vat_rate <= 100)` | Recorded VAT rate percentage as stated on the invoice. **Deliberately permissive** — permits ingesting incorrect rates (e.g., 0%, 5%, 20%) so that **Query 3** can detect and flag them. Only nonsensical values (<0 or >100) are rejected. |
| `vat_amount` | `NUMERIC` | `NOT NULL CHECK (vat_amount >= 0)` | Recorded tax amount (€). Audited in **Query 3** against `ROUND(line_subtotal * (vat_rate / 100), 2)`. |
| `line_total` | `NUMERIC` | `NOT NULL CHECK (line_total >= 0)` | Recorded gross total (€). Audited in **Query 2** against `ROUND(line_subtotal + vat_amount, 2)`. |

---

## 6. Audit Query Mapping Summary

1. **Query 1 — Duplicate Invoices:** Evaluates `invoices.invoice_number` and `invoices.billing_vendor_id` (and identical totals on same date under same award).
2. **Query 2 — Line & Header Arithmetic Validation:**
   - *Line-level:* Verifies `line_subtotal = ROUND(quantity * unit_price, 2)` and `line_total = ROUND(line_subtotal + vat_amount, 2)`.
   - *Invoice-level:* Verifies `invoices.recorded_total = ROUND(SUM(invoice_line_items.line_total), 2)`.
3. **Query 3 — VAT Rate & Computation Audit:**
   - Evaluates `item_category` vs `vat_rate` according to Law No. 05/L-037 Art. 26(1) (18%) and Art. 26(2)(9–13) (8%).
   - Verifies `vat_amount = ROUND(line_subtotal * (vat_rate / 100), 2)`.
4. **Query 4 — Recorded Award Value Overrun:** Compares `procurement_awards.recorded_award_value` against `ROUND(SUM(invoices.recorded_total), 2)` grouped by award.
5. **Query 5 — Vendor Exception Summary & Discrepancies:** Identifies billing vendor mismatches (`invoices.billing_vendor_id != procurement_awards.vendor_id`) and aggregates audit exceptions by vendor.