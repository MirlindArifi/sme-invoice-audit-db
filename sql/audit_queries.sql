-- ============================================================================
-- SME Invoice Audit DB — Analytical Audit Queries
-- Context: Municipal Procurement & Tax Compliance Auditor (Kosovo)
-- Engine:  SQLite 3
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- QUERY 1: Duplicate Invoice Reference Detection
-- ============================================================================
-- Scenario A: Same vendor submits identical invoice_number more than once.
-- Scenario B: Same vendor, same award, same date, same amount across
--             distinct invoice numbers (suspected split/duplicate claim).
--
-- Expected on seed dataset:
--   Scenario A flags SYNTH-INV-2023-0102 (Vendor 1, 2 submissions).
--   Scenario B flags SYNTH-INV-2023-0103 + 0104 (Vendor 2, 1,770.00).
--   SYNTH-INV-2023-0101 across Vendors 1 and 2 is a legitimate control
--   and must not be flagged.
-- ============================================================================

SELECT
    'DUPLICATE_INVOICE_NUMBER' AS duplicate_scenario,
    v.vendor_id,
    v.vendor_name,
    i.invoice_number AS flagged_references,
    COUNT(i.invoice_id) AS submission_count,
    MIN(i.invoice_date) AS min_date,
    MAX(i.invoice_date) AS max_date,
    ROUND(SUM(i.recorded_total), 2) AS total_amount_claimed
FROM invoices i
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
GROUP BY
    v.vendor_id,
    v.vendor_name,
    i.invoice_number
HAVING
    COUNT(i.invoice_id) > 1

UNION ALL

SELECT
    'SUSPECTED_SPLIT_OR_DUPLICATE_CLAIM' AS duplicate_scenario,
    v.vendor_id,
    v.vendor_name,
    GROUP_CONCAT(i.invoice_number, ', ') AS flagged_references,
    COUNT(i.invoice_id) AS submission_count,
    i.invoice_date AS min_date,
    i.invoice_date AS max_date,
    ROUND(SUM(i.recorded_total), 2) AS total_amount_claimed
FROM invoices i
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
GROUP BY
    v.vendor_id,
    v.vendor_name,
    i.award_id,
    i.invoice_date,
    i.recorded_total
HAVING
    COUNT(DISTINCT i.invoice_number) > 1;

-- ============================================================================
-- QUERY 2: Line-Item & Header Arithmetic Validation
-- ============================================================================

-- Part 2A: Line-item computational discrepancies
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

-- Part 2B: Invoice header total vs. sum of line items
-- Uses LEFT JOIN so invoices with zero line items are still surfaced.
SELECT
    i.invoice_id,
    i.invoice_number,
    v.vendor_name,
    i.recorded_total AS header_recorded_total,
    ROUND(COALESCE(SUM(li.line_total), 0), 2) AS calculated_lines_sum,
    ROUND(i.recorded_total - COALESCE(SUM(li.line_total), 0), 2) AS header_discrepancy
FROM invoices i
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
LEFT JOIN invoice_line_items li ON i.invoice_id = li.invoice_id
GROUP BY
    i.invoice_id,
    i.invoice_number,
    v.vendor_name,
    i.recorded_total
HAVING
    ROUND(i.recorded_total, 2) != ROUND(COALESCE(SUM(li.line_total), 0), 2);

-- ============================================================================
-- QUERY 3: VAT Classification & Computation Review
-- ============================================================================
-- Findings are labelled as candidates for review, not conclusions of tax
-- non-compliance. Only the 18% standard rate and the 8% reduced rate for
-- the defined MVP categories are audited. Exempt supplies under Article 27
-- of Law No. 05/L-037 are outside scope.
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
        WHEN li.vat_rate NOT IN (8.00, 18.00) THEN
            'NON_STATUTORY_RATE'
        WHEN li.item_category IN ('OFFICE_FURNITURE', 'GENERAL_STATIONERY', 'CIVIL_CONSTRUCTION', 'BUILDING_MAINTENANCE')
             AND li.vat_rate = 8.00 THEN
            'POTENTIAL_MISCLASSIFICATION_REDUCED_ON_STANDARD'
        WHEN li.item_category IN ('IT_EQUIPMENT', 'PHARMACEUTICALS', 'TEXTBOOKS_AND_BOOKS')
             AND li.vat_rate = 18.00 THEN
            'POTENTIAL_OVERCHARGE_STANDARD_ON_REDUCED'
        WHEN ROUND(li.vat_amount, 2) != ROUND(li.line_subtotal * (li.vat_rate / 100.0), 2) THEN
            'VAT_ARITHMETIC_MISMATCH'
        ELSE
            'COMPLIANT'
    END AS audit_finding
FROM invoice_line_items li
JOIN invoices i ON li.invoice_id = i.invoice_id
JOIN vendors v ON i.billing_vendor_id = v.vendor_id
WHERE
    li.vat_rate NOT IN (8.00, 18.00)
    OR (li.item_category IN ('OFFICE_FURNITURE', 'GENERAL_STATIONERY', 'CIVIL_CONSTRUCTION', 'BUILDING_MAINTENANCE') AND li.vat_rate = 8.00)
    OR (li.item_category IN ('IT_EQUIPMENT', 'PHARMACEUTICALS', 'TEXTBOOKS_AND_BOOKS') AND li.vat_rate = 18.00)
    OR (ROUND(li.vat_amount, 2) != ROUND(li.line_subtotal * (li.vat_rate / 100.0), 2));

-- ============================================================================
-- QUERY 4: Invoice Totals Exceeding Recorded Award Value
-- ============================================================================
-- `recorded_award_value` is a baseline for review, not a legally enforced
-- ceiling. A positive result is a candidate for investigation, not proof
-- of a contract breach.
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
-- QUERY 5: Vendor Mismatch & Billing Summary
-- ============================================================================

-- Part 5A: Invoices submitted by a vendor other than the awarded one
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

-- Part 5B: Vendor billing & exception summary
SELECT
    v.vendor_id,
    v.vendor_name,
    COUNT(i.invoice_id) AS total_invoices_billed,
    ROUND(COALESCE(SUM(i.recorded_total), 0), 2) AS total_amount_billed,
    SUM(CASE WHEN i.billing_vendor_id != a.vendor_id THEN 1 ELSE 0 END) AS mismatch_billing_count
FROM vendors v
LEFT JOIN invoices i ON v.vendor_id = i.billing_vendor_id
LEFT JOIN procurement_awards a ON i.award_id = a.award_id
GROUP BY
    v.vendor_id,
    v.vendor_name
ORDER BY
    total_amount_billed DESC;