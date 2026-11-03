-- ============================================================================
-- SME Invoice Audit DB — Automated Query Regression Test Suite
-- Executes assertions on all 5 audit queries and reports PASS / FAIL.
-- Expected state: every row should return PASS.
-- ============================================================================

PRAGMA foreign_keys = ON;

WITH
-- Query 1: Duplicate detection (both scenarios) — expect 2 rows
test_q1 AS (
    SELECT COUNT(*) AS row_count FROM (
        SELECT v.vendor_id, i.invoice_number
        FROM invoices i
        JOIN vendors v ON i.billing_vendor_id = v.vendor_id
        GROUP BY v.vendor_id, i.invoice_number
        HAVING COUNT(i.invoice_id) > 1
        UNION ALL
        SELECT v.vendor_id, GROUP_CONCAT(i.invoice_number)
        FROM invoices i
        JOIN vendors v ON i.billing_vendor_id = v.vendor_id
        GROUP BY v.vendor_id, i.award_id, i.invoice_date, i.recorded_total
        HAVING COUNT(DISTINCT i.invoice_number) > 1
    )
),

-- Query 2A: Line arithmetic — expect 2 rows
test_q2a AS (
    SELECT COUNT(*) AS row_count
    FROM invoice_line_items li
    WHERE ROUND(li.line_subtotal, 2) != ROUND(li.quantity * li.unit_price, 2)
       OR ROUND(li.line_total, 2) != ROUND(li.line_subtotal + li.vat_amount, 2)
),

-- Query 2B: Header reconciliation — expect 1 row
test_q2b AS (
    SELECT COUNT(*) AS row_count FROM (
        SELECT i.invoice_id
        FROM invoices i
        LEFT JOIN invoice_line_items li ON i.invoice_id = li.invoice_id
        GROUP BY i.invoice_id, i.recorded_total
        HAVING ROUND(i.recorded_total, 2) != ROUND(COALESCE(SUM(li.line_total), 0), 2)
    )
),

-- Query 3: VAT rate and computation — expect 6 rows
test_q3 AS (
    SELECT COUNT(*) AS row_count
    FROM invoice_line_items li
    WHERE li.vat_rate NOT IN (8.00, 18.00)
       OR (li.item_category IN ('OFFICE_FURNITURE', 'GENERAL_STATIONERY', 'CIVIL_CONSTRUCTION', 'BUILDING_MAINTENANCE') AND li.vat_rate = 8.00)
       OR (li.item_category IN ('IT_EQUIPMENT', 'PHARMACEUTICALS', 'TEXTBOOKS_AND_BOOKS') AND li.vat_rate = 18.00)
       OR (ROUND(li.vat_amount, 2) != ROUND(li.line_subtotal * (li.vat_rate / 100.0), 2))
),

-- Query 4: Award overrun — expect 1 row
test_q4 AS (
    SELECT COUNT(*) AS row_count FROM (
        SELECT a.award_id
        FROM procurement_awards a
        JOIN invoices i ON a.award_id = i.award_id
        GROUP BY a.award_id, a.recorded_award_value
        HAVING ROUND(SUM(i.recorded_total), 2) > a.recorded_award_value
    )
),

-- Query 5A: Vendor mismatch — expect 1 row
test_q5a AS (
    SELECT COUNT(*) AS row_count
    FROM invoices i
    JOIN procurement_awards a ON i.award_id = a.award_id
    WHERE i.billing_vendor_id != a.vendor_id
)

SELECT
    'Query 1: Duplicate Invoices' AS query_name,
    row_count AS actual_rows,
    2 AS expected_rows,
    CASE WHEN row_count = 2 THEN 'PASS' ELSE 'FAIL' END AS status
FROM test_q1
UNION ALL
SELECT
    'Query 2A: Line Arithmetic',
    row_count, 2,
    CASE WHEN row_count = 2 THEN 'PASS' ELSE 'FAIL' END
FROM test_q2a
UNION ALL
SELECT
    'Query 2B: Header Reconciliation',
    row_count, 1,
    CASE WHEN row_count = 1 THEN 'PASS' ELSE 'FAIL' END
FROM test_q2b
UNION ALL
SELECT
    'Query 3: VAT Rate & Computation',
    row_count, 6,
    CASE WHEN row_count = 6 THEN 'PASS' ELSE 'FAIL' END
FROM test_q3
UNION ALL
SELECT
    'Query 4: Award Ceiling Overrun',
    row_count, 1,
    CASE WHEN row_count = 1 THEN 'PASS' ELSE 'FAIL' END
FROM test_q4
UNION ALL
SELECT
    'Query 5A: Unauthorized Vendor Mismatch',
    row_count, 1,
    CASE WHEN row_count = 1 THEN 'PASS' ELSE 'FAIL' END
FROM test_q5a;