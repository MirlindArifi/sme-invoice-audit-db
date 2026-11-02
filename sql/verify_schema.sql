-- ============================================================================
-- SME Invoice Audit DB — Schema Integrity Verification Script
-- Context: Automated Constraint and Referential Integrity Test Suite
-- ============================================================================

-- Enforce foreign keys for this connection
PRAGMA foreign_keys = ON;

-- Wrap the entire test suite in a transaction that rolls back at the end.
-- This allows testing inserts without polluting the database with test data.
BEGIN TRANSACTION;

-- ============================================================================
-- 1. POSITIVE INTEGRITY TESTS (Valid Parent-Child Relational Chain)
-- ============================================================================

-- 1.1 Insert valid synthetic vendor
INSERT INTO vendors (
    vendor_id, fiscal_identifier, vendor_name, vendor_type, is_synthetic
) VALUES (
    1, 'SYNTH-TAX-0001', 'Dardania Tech Solutions SH.P.K. (Synthetic)', 'SH.P.K.', 1
);

-- 1.2 Insert valid procurement award referencing vendor 1
INSERT INTO procurement_awards (
    award_id, procurement_number, authority_name, vendor_id,
    award_date, recorded_award_value, procurement_category
) VALUES (
    1, 'SYNTH-616-23-001-521', 'Komuna e Prishtines', 1,
    '2023-01-15', 50000.00, 'SUPPLIES'
);

-- 1.3 Insert valid invoice referencing award 1 and vendor 1
INSERT INTO invoices (
    invoice_id, invoice_number, award_id, billing_vendor_id,
    invoice_date, recorded_total
) VALUES (
    1, 'SYNTH-INV-2023-0001', 1, 1,
    '2023-02-10', 1080.00
);

-- 1.4 Insert valid line item referencing invoice 1
INSERT INTO invoice_line_items (
    line_item_id, invoice_id, item_category, description,
    quantity, unit_price, line_subtotal, vat_rate, vat_amount, line_total
) VALUES (
    1, 1, 'IT_EQUIPMENT', 'Server Rack Unit',
    1, 1000.00, 1000.00, 8.00, 80.00, 1080.00
);

-- Display table counts inside active transaction (Must all be 1)
SELECT '--- POSITIVE CHAIN VERIFICATION (Inside Transaction) ---' AS test_status;
SELECT 'vendors' AS table_name, COUNT(*) AS row_count FROM vendors
UNION ALL
SELECT 'procurement_awards', COUNT(*) FROM procurement_awards
UNION ALL
SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL
SELECT 'invoice_line_items', COUNT(*) FROM invoice_line_items;

-- ============================================================================
-- 2. NEGATIVE INTEGRITY TESTS (Each statement MUST fail on execution)
-- ============================================================================

-- Test 2.1: Foreign Key Violation — Non-existent vendor_id on procurement_awards
INSERT INTO procurement_awards (
    procurement_number, authority_name, vendor_id,
    award_date, recorded_award_value, procurement_category
) VALUES (
    'SYNTH-FAIL-FK-01', 'Komuna e Prishtines', 999,
    '2023-01-15', 10000.00, 'SUPPLIES'
);

-- Test 2.2: Foreign Key Violation — Non-existent invoice_id on invoice_line_items
INSERT INTO invoice_line_items (
    invoice_id, item_category, description,
    quantity, unit_price, line_subtotal, vat_rate, vat_amount, line_total
) VALUES (
    999, 'IT_EQUIPMENT', 'Orphan Item',
    1, 100.00, 100.00, 8.00, 8.00, 108.00
);

-- Test 2.3: CHECK Violation — Synthetic guard allows only is_synthetic = 1
INSERT INTO vendors (
    fiscal_identifier, vendor_name, vendor_type, is_synthetic
) VALUES (
    'SYNTH-TAX-0002', 'Non-Synthetic Entity', 'SH.P.K.', 0
);

-- Test 2.4: CHECK Violation — Negative quantity (all other fields pass their checks)
INSERT INTO invoice_line_items (
    invoice_id, item_category, description,
    quantity, unit_price, line_subtotal, vat_rate, vat_amount, line_total
) VALUES (
    1, 'IT_EQUIPMENT', 'Negative Quantity Item',
    -5, 0.00, 0.00, 8.00, 0.00, 0.00
);

-- Test 2.5: CHECK Violation — VAT rate exceeding physical 0-100 boundary
INSERT INTO invoice_line_items (
    invoice_id, item_category, description,
    quantity, unit_price, line_subtotal, vat_rate, vat_amount, line_total
) VALUES (
    1, 'IT_EQUIPMENT', 'Impossible VAT Rate',
    1, 100.00, 100.00, 150.00, 15.00, 115.00
);

-- Test 2.6: UNIQUE Violation — Duplicate fiscal_identifier on vendors
INSERT INTO vendors (
    fiscal_identifier, vendor_name, vendor_type, is_synthetic
) VALUES (
    'SYNTH-TAX-0001', 'Duplicate Tax ID Entity', 'SH.P.K.', 1
);

-- Test 2.7: NOT NULL Violation — Missing invoice_date on invoices
INSERT INTO invoices (
    invoice_number, award_id, billing_vendor_id, recorded_total
) VALUES (
    'SYNTH-INV-FAIL-01', 1, 1, 500.00
);

-- ============================================================================
-- 3. ROLLBACK & POST-CLEANUP VERIFICATION
-- ============================================================================

-- Revert all test insertions
ROLLBACK;

-- Verify database is completely empty post-rollback (Must all be 0)
SELECT '--- POST-ROLLBACK VERIFICATION (Database Cleanliness) ---' AS test_status;
SELECT 'vendors' AS table_name, COUNT(*) AS row_count FROM vendors
UNION ALL
SELECT 'procurement_awards', COUNT(*) FROM procurement_awards
UNION ALL
SELECT 'invoices', COUNT(*) FROM invoices
UNION ALL
SELECT 'invoice_line_items', COUNT(*) FROM invoice_line_items;