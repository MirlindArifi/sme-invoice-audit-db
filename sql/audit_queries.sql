-- ============================================================================
-- SME Invoice Audit DB — Analytical Audit Queries (1 through 3)
-- Context: Municipal Procurement & Tax Compliance Auditor (Kosovo)
-- Engine:  SQLite 3
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- QUERY 1: Duplicate Invoice Reference Detection
-- ============================================================================
-- Business Question:
-- Has a supplier submitted the same invoice number more than once to the
-- contracting authorities?
--
-- Accounting Context:
-- Legitimate vendors may independently issue identical internal invoice numbers
-- (e.g., both Vendor A and Vendor B issue "INV-001"). However, a single vendor
-- must never bill the same invoice number multiple times. Doing so indicates
-- duplicate payment claims or serious billing system errors.
--
-- Expected Output on Test Dataset:
-- - Flags 'SYNTH-INV-2023-0102' submitted twice by Vendor 1 (Dardania Tech).
-- - Ignores 'SYNTH-INV-2023-0101' because it was submitted once by Vendor 1
--   and once by Vendor 2 (valid control case).
-- ============================================================================

SELECT
    v.vendor_id,
    v.vendor_name,
    i.invoice_number,
    COUNT(i.invoice_id) AS submission_count,
    MIN(i.invoice_date) AS first_submission_date,
    MAX(i.invoice_date) AS latest_submission_date,
    ROUND(SUM(i.recorded_total), 2) AS total_amount_claimed
FROM invoices i
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
GROUP BY
    v.vendor_id,
    v.vendor_name,
    i.invoice_number
HAVING
    COUNT(i.invoice_id) > 1;

-- ============================================================================
-- QUERY 2: Line-Item & Header Arithmetic Validation
-- ============================================================================
-- Business Question:
-- Do the math calculations on invoice line items and header totals reconcile?
-- Specifically:
--   1. Does (quantity * unit_price) equal the recorded line_subtotal?
--   2. Does (line_subtotal + vat_amount) equal the recorded line_total?
--   3. Does the invoice header recorded_total equal the sum of its line totals?
--
-- Accounting Context:
-- Automated procurement audits must verify basic arithmetic. Inconsistencies
-- may stem from manual spreadsheet entry, transposition typos, or deliberate
-- inflation of invoice totals.
--
-- Expected Output on Test Dataset:
-- - Line 8 (Invoice 8): Subtotal error (5 * 200 = 1,000, recorded as 1,200).
-- - Line 9 (Invoice 9): Line total error (1,500 + 270 = 1,770, recorded as 1,900).
-- - Invoice 10: Header error (Header recorded as 500, but line total sum is 354).
-- ============================================================================

-- Part 2A: Line-Item Computational Discrepancies
SELECT
    li.line_item_id,
    li.invoice_id,
    i.invoice_number,
    v.vendor_name,
    li.item_category,
    li.quantity,
    li.unit_price,
    li.line_subtotal,
    ROUND(li.quantity * li.unit_price, 2) AS calculated_subtotal,
    ROUND(li.line_subtotal - (li.quantity * li.unit_price), 2) AS subtotal_discrepancy,
    li.vat_amount,
    li.line_total,
    ROUND(li.line_subtotal + li.vat_amount, 2) AS calculated_line_total,
    ROUND(li.line_total - (li.line_subtotal + li.vat_amount), 2) AS line_total_discrepancy
FROM invoice_line_items li
JOIN invoices i ON li.invoice_id = i.invoice_id
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
WHERE
    ROUND(li.line_subtotal, 2) != ROUND(li.quantity * li.unit_price, 2)
    OR
    ROUND(li.line_total, 2) != ROUND(li.line_subtotal + li.vat_amount, 2);

-- Part 2B: Invoice Header Total vs. Sum of Line Items Reconciliation
SELECT
    i.invoice_id,
    i.invoice_number,
    v.vendor_name,
    i.recorded_total AS header_recorded_total,
    ROUND(SUM(li.line_total), 2) AS calculated_lines_sum,
    ROUND(i.recorded_total - SUM(li.line_total), 2) AS header_discrepancy
FROM invoices i
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
JOIN invoice_line_items li ON i.invoice_id = li.invoice_id
GROUP BY
    i.invoice_id,
    i.invoice_number,
    v.vendor_name,
    i.recorded_total
HAVING
    ROUND(i.recorded_total, 2) != ROUND(SUM(li.line_total), 2);

-- ============================================================================
-- QUERY 3: VAT Rate Classification & Computation Audit
-- ============================================================================
-- Business Question:
-- Does the recorded VAT rate match statutory rates under Law No. 05/L-037,
-- and does the recorded vat_amount equal line_subtotal * (vat_rate / 100)?
--
-- Statutory Classification Schedule:
-- - Standard 18%: OFFICE_FURNITURE, GENERAL_STATIONERY, CIVIL_CONSTRUCTION,
--                 BUILDING_MAINTENANCE (Art. 26(1))
-- - Reduced 8%:   IT_EQUIPMENT (Art. 26(2)(11)), PHARMACEUTICALS (Art. 26(2)(12)),
--                 TEXTBOOKS_AND_BOOKS (Art. 26(2)(9-10))
--
-- Audit Findings Categorized:
-- 1. FLAG_UNDER_TAXATION: Non-qualifying supplies billed at 8% (tax evasion/misclassification).
-- 2. FLAG_OVER_TAXATION:  Qualifying 8% supplies billed at 18% (municipal over-billing).
-- 3. FLAG_RATE_OUTLIER:   Arbitrary or invalid rates (0%, 5%, 20%).
-- 4. FLAG_VAT_ARITHMETIC: Correct rate stated, but vat_amount mathematically miscalculated.
--
-- Expected Output on Test Dataset:
-- - Line 13 (Inv 12): Under-taxation (OFFICE_FURNITURE at 8%).
-- - Line 14 (Inv 13): Over-taxation (IT_EQUIPMENT at 18%).
-- - Line 15 (Inv 14): Rate outlier (0.00% on taxable stationery).
-- - Line 16 (Inv 15): Rate outlier (5.00% non-statutory rate).
-- - Line 17 (Inv 16): Rate outlier (20.00% foreign rate).
-- - Line 18 (Inv 17): VAT arithmetic mismatch (18% stated, 1,200 recorded vs 1,800 calculated).
-- ============================================================================

SELECT
    li.line_item_id,
    i.invoice_number,
    v.vendor_name,
    li.item_category,
    li.line_subtotal,
    li.vat_rate AS recorded_vat_rate,
    li.vat_amount AS recorded_vat_amount,
    ROUND(li.line_subtotal * (li.vat_rate / 100.0), 2) AS calculated_vat_amount,
    ROUND(li.vat_amount - (li.line_subtotal * (li.vat_rate / 100.0)), 2) AS vat_arithmetic_diff,
    CASE
        -- 1. Rate Outliers: Rates other than the statutory 8% or 18%
        WHEN li.vat_rate NOT IN (8.00, 18.00) THEN
            'FLAG_RATE_OUTLIER'

        -- 2. Under-taxation: Standard items improperly billed at 8% reduced rate
        WHEN li.item_category IN ('OFFICE_FURNITURE', 'GENERAL_STATIONERY', 'CIVIL_CONSTRUCTION', 'BUILDING_MAINTENANCE')
             AND li.vat_rate = 8.00 THEN
            'FLAG_UNDER_TAXATION'

        -- 3. Over-taxation: Statutory reduced items billed at standard 18%
        WHEN li.item_category IN ('IT_EQUIPMENT', 'PHARMACEUTICALS', 'TEXTBOOKS_AND_BOOKS')
             AND li.vat_rate = 18.00 THEN
            'FLAG_OVER_TAXATION'

        -- 4. VAT Math Error: Rate is valid, but recorded VAT amount is wrong
        WHEN ROUND(li.vat_amount, 2) != ROUND(li.line_subtotal * (li.vat_rate / 100.0), 2) THEN
            'FLAG_VAT_ARITHMETIC'

        ELSE
            'COMPLIANT'
    END AS audit_finding
FROM invoice_line_items li
JOIN invoices i ON li.invoice_id = i.invoice_id
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
WHERE
    -- Filter out compliant rows to present only audit exceptions
    li.vat_rate NOT IN (8.00, 18.00)
    OR (li.item_category IN ('OFFICE_FURNITURE', 'GENERAL_STATIONERY', 'CIVIL_CONSTRUCTION', 'BUILDING_MAINTENANCE') AND li.vat_rate = 8.00)
    OR (li.item_category IN ('IT_EQUIPMENT', 'PHARMACEUTICALS', 'TEXTBOOKS_AND_BOOKS') AND li.vat_rate = 18.00)
    OR (ROUND(li.vat_amount, 2) != ROUND(li.line_subtotal * (li.vat_rate / 100.0), 2));

-- ============================================================================
-- QUERY 4: Recorded Award Value Overrun
-- ============================================================================
-- Business Question:
-- Has the cumulative amount billed against a procurement award exceeded the
-- authorized recorded award value?
--
-- Accounting Context:
-- In municipal public finance, a contract award value represents an authorized
-- expenditure ceiling. If cumulative billing exceeds this baseline without a
-- documented contract annex or formal amendment, it indicates unauthorized
-- spending, budget overruns, or improper invoice allocation.
--
-- Expected Output on Test Dataset:
-- - Flags Award ID 4 (Peja, Supplies): Award value € 15,000.00, total billed
--   € 16,740.00 across 2 invoices, resulting in an overrun of € 1,740.00 (111.60%).
-- - Ignores Award ID 2 (Control baseline: € 18,156.00 billed against € 20,000.00 ceiling).
-- ============================================================================

SELECT
    a.award_id,
    a.procurement_number,
    a.authority_name,
    a.recorded_award_value,
    ROUND(SUM(i.recorded_total), 2) AS total_billed,
    ROUND(SUM(i.recorded_total) - a.recorded_award_value, 2) AS overrun_amount,
    ROUND((CAST(SUM(i.recorded_total) AS REAL) / a.recorded_award_value) * 100.0, 2) AS utilization_pct
FROM procurement_awards a
JOIN invoices i ON a.award_id = i.award_id
GROUP BY
    a.award_id,
    a.procurement_number,
    a.authority_name,
    a.recorded_award_value
HAVING
    ROUND(SUM(i.recorded_total), 2) > a.recorded_award_value;

-- ============================================================================
-- QUERY 5: Vendor Exception Summary & Entity Mismatch
-- ============================================================================
-- Business Question:
-- Part 5A: Are there invoices billed by a vendor other than the entity awarded
-- the procurement contract?
-- Part 5B: What is the total billed exposure and frequency of unassigned award
-- billings across all registered vendors?
--
-- Accounting Context:
-- Only the vendor legally awarded a contract is authorized to submit payment
-- claims against it. If Vendor B submits an invoice citing an award issued to
-- Vendor A, this represents unauthorized third-party billing, improper contract
-- subcontracting, or severe misrouting in municipal treasury accounts.
--
-- Expected Output on Test Dataset:
-- - Part 5A flags Invoice ID 24 (SYNTH-INV-2023-0502 for € 10,800.00):
--   Awarded to Kastrioti Building & Maintenance (Vendor 3), but billed by
--   Prishtina Medical & Pharma (Vendor 4).
-- - Part 5B rolls up all 4 vendors, showing invoice counts, total monetary
--   exposure, and identifying Vendor 4's 1 unauthorized submission.
-- ============================================================================

-- Part 5A: Unauthorized Third-Party Billing Detection
SELECT
    i.invoice_id,
    i.invoice_number,
    i.invoice_date,
    i.recorded_total,
    a.procurement_number,
    a.authority_name,
    aw_v.vendor_name AS awarded_vendor,
    bill_v.vendor_name AS billing_vendor
FROM invoices i
JOIN procurement_awards a ON i.award_id = a.award_id
JOIN vendors aw_v ON a.vendor_id = aw_v.vendor_id
JOIN vendors bill_v ON i.billing_vendor_id = bill_v.vendor_id
WHERE
    i.billing_vendor_id != a.vendor_id;

-- Part 5B: Vendor Billing & Exception Summary Rollup
SELECT
    v.vendor_id,
    v.vendor_name,
    COUNT(i.invoice_id) AS total_invoices_billed,
    ROUND(COALESCE(SUM(i.recorded_total), 0), 2) AS total_amount_billed,
    SUM(CASE WHEN i.billing_vendor_id != a.vendor_id THEN 1 ELSE 0 END) AS unauthorized_billing_count
FROM vendors v
LEFT JOIN invoices i ON v.vendor_id = i.billing_vendor_id
LEFT JOIN procurement_awards a ON i.award_id = a.award_id
GROUP BY
    v.vendor_id,
    v.vendor_name
ORDER BY
    total_amount_billed DESC;