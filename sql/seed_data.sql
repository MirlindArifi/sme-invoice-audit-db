-- ============================================================================
-- SME Invoice Audit DB — Data Seeding Script
-- Context: Municipal Procurement & Tax Compliance Auditor (Kosovo)
--
-- Expected Target Row Counts:
--   - vendors:            4
--   - procurement_awards: 4
--   - invoices:           24
--   - invoice_line_items: 25
--
-- Financial Verification Targets:
--   - Award 2 Billed Total: € 18,156.00 (Control baseline <= € 20,000.00 ceiling)
--   - Award 4 Billed Total: € 16,740.00 (Overrun anomaly > € 15,000.00 ceiling)
-- ============================================================================

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- ============================================================================
-- 1. VENDORS (4 records)
-- ============================================================================
INSERT INTO vendors (vendor_id, fiscal_identifier, vendor_name, vendor_type, is_synthetic)
VALUES
    (1, 'SYNTH-TAX-1001', 'Dardania Tech Solutions SH.P.K. (Synthetic)', 'SH.P.K.', 1),
    (2, 'SYNTH-TAX-1002', 'Dukagjini Office Supplies SH.P.K. (Synthetic)', 'SH.P.K.', 1),
    (3, 'SYNTH-TAX-1003', 'Kastrioti Building & Maintenance SH.P.K. (Synthetic)', 'SH.P.K.', 1),
    (4, 'SYNTH-TAX-1004', 'Prishtina Medical & Pharma SH.P.K. (Synthetic)', 'SH.P.K.', 1);

-- ============================================================================
-- 2. PROCUREMENT AWARDS (4 records)
-- ============================================================================
INSERT INTO procurement_awards (award_id, procurement_number, authority_name, vendor_id, award_date, recorded_award_value, procurement_category)
VALUES
    (1, 'SYNTH-616-23-001-521', 'Komuna e Prishtinës', 1, '2023-01-15', 50000.00, 'SUPPLIES'),
    (2, 'SYNTH-616-23-002-521', 'Komuna e Prishtinës', 2, '2023-02-01', 20000.00, 'SUPPLIES'),
    (3, 'SYNTH-616-23-003-511', 'Komuna e Prizrenit', 3, '2023-02-15', 80000.00, 'WORKS'),
    (4, 'SYNTH-616-23-004-521', 'Komuna e Pejës',      1, '2023-03-01', 15000.00, 'SUPPLIES');

-- ============================================================================
-- 3. INVOICES (24 records)
-- Note: SYNTH-INV-2023-0101 appears twice (Vendor 1 vs. Vendor 2).
-- Note: SYNTH-INV-2023-0102 appears twice (Duplicate submitted by Vendor 1).
-- ============================================================================
INSERT INTO invoices (invoice_id, invoice_number, award_id, billing_vendor_id, invoice_date, recorded_total)
VALUES
    -- Query 1 Scenarios (Duplicates & Controls)
    (1,  'SYNTH-INV-2023-0101', 1, 1, '2023-03-10', 4320.00),
    (2,  'SYNTH-INV-2023-0101', 2, 2, '2023-03-15', 3540.00),
    (3,  'SYNTH-INV-2023-0102', 1, 1, '2023-04-15', 2160.00),
    (4,  'SYNTH-INV-2023-0102', 1, 1, '2023-04-20', 2160.00),
    (5,  'SYNTH-INV-2023-0103', 2, 2, '2023-05-02', 1770.00),
    (6,  'SYNTH-INV-2023-0104', 2, 2, '2023-05-02', 1770.00),

    -- Query 2 Scenarios (Arithmetic Anomalies & Control)
    (7,  'SYNTH-INV-2023-0201', 1, 1, '2023-05-10', 4320.00),
    (8,  'SYNTH-INV-2023-0202', 2, 2, '2023-05-12', 1416.00),
    (9,  'SYNTH-INV-2023-0203', 3, 3, '2023-05-15', 1900.00),
    (10, 'SYNTH-INV-2023-0204', 2, 2, '2023-05-18', 500.00),

    -- Query 3 Scenarios (VAT Classification, Computation & Multi-line Control)
    (11, 'SYNTH-INV-2023-0301', 1, 1, '2023-06-05', 3340.00),
    (12, 'SYNTH-INV-2023-0302', 2, 2, '2023-06-08', 1080.00),
    (13, 'SYNTH-INV-2023-0303', 1, 1, '2023-06-10', 2360.00),
    (14, 'SYNTH-INV-2023-0304', 2, 2, '2023-06-12', 1000.00),
    (15, 'SYNTH-INV-2023-0305', 3, 3, '2023-06-15', 1050.00),
    (16, 'SYNTH-INV-2023-0306', 3, 3, '2023-06-18', 12000.00),
    (17, 'SYNTH-INV-2023-0307', 3, 3, '2023-06-20', 11200.00),

    -- Query 4 Scenarios (Clean Baseline for Award 2 & Overrun on Award 4)
    (18, 'SYNTH-INV-2023-0411', 2, 2, '2023-06-01', 2360.00),
    (19, 'SYNTH-INV-2023-0412', 2, 2, '2023-06-15', 2360.00),
    (20, 'SYNTH-INV-2023-0413', 2, 2, '2023-07-01', 2360.00),
    (21, 'SYNTH-INV-2023-0401', 4, 1, '2023-08-01', 8100.00),
    (22, 'SYNTH-INV-2023-0402', 4, 1, '2023-08-20', 8640.00),

    -- Query 5 Scenarios (Vendor Mismatch & Control)
    (23, 'SYNTH-INV-2023-0501', 3, 3, '2023-09-01', 11800.00),
    (24, 'SYNTH-INV-2023-0502', 3, 4, '2023-09-15', 10800.00);

-- ============================================================================
-- 4. INVOICE LINE ITEMS (25 records)
-- Note: Invoice 11 (SYNTH-INV-2023-0301) has two line items (IDs 11 and 12).
-- ============================================================================
INSERT INTO invoice_line_items (line_item_id, invoice_id, item_category, description, quantity, unit_price, line_subtotal, vat_rate, vat_amount, line_total)
VALUES
    -- Lines for Query 1 Invoices (All valid baselines)
    (1,  1,  'IT_EQUIPMENT',       'Laptops for Municipal Administration', 1, 4000.00, 4000.00, 8.00,  320.00, 4320.00),
    (2,  2,  'OFFICE_FURNITURE',   'Ergonomic Desk Sets',                 1, 3000.00, 3000.00, 18.00, 540.00, 3540.00),
    (3,  3,  'IT_EQUIPMENT',       'Desktop Workstations Batch A',        1, 2000.00, 2000.00, 8.00,  160.00, 2160.00),
    (4,  4,  'IT_EQUIPMENT',       'Desktop Workstations Batch B',        1, 2000.00, 2000.00, 8.00,  160.00, 2160.00),
    (5,  5,  'GENERAL_STATIONERY', 'Archival Paper Supply',               1, 1500.00, 1500.00, 18.00, 270.00, 1770.00),
    (6,  6,  'GENERAL_STATIONERY', 'Archival Paper Supply Duplicate',     1, 1500.00, 1500.00, 18.00, 270.00, 1770.00),

    -- Lines for Query 2 Invoices (Arithmetic Test Cases)
    (7,  7,  'IT_EQUIPMENT',       'Server Hard Drives',                 10,  400.00, 4000.00, 8.00,  320.00, 4320.00),
    (8,  8,  'OFFICE_FURNITURE',   'Conference Room Chairs',              5,  200.00, 1200.00, 18.00, 216.00, 1416.00), -- Subtotal error (5*200=1000)
    (9,  9,  'BUILDING_MAINTENANCE','HVAC Duct Repair',                   1, 1500.00, 1500.00, 18.00, 270.00, 1900.00), -- Line total error (1500+270=1770)
    (10, 10, 'GENERAL_STATIONERY', 'Toner Cartridges',                   20,   15.00,  300.00, 18.00,  54.00,  354.00), -- Header error (header is 500)

    -- Lines for Query 3 Invoices (VAT Classification & Computation Cases)
    (11, 11, 'IT_EQUIPMENT',       'Network Switches',                    1, 2000.00, 2000.00, 8.00,  160.00, 2160.00), -- Multi-line control part 1
    (12, 11, 'OFFICE_FURNITURE',   'Server Room Storage Rack',            1, 1000.00, 1000.00, 18.00, 180.00, 1180.00), -- Multi-line control part 2
    (13, 12, 'OFFICE_FURNITURE',   'Executive Desks',                     1, 1000.00, 1000.00, 8.00,   80.00, 1080.00), -- Anomaly 3A (Under-taxation 8% on furniture)
    (14, 13, 'IT_EQUIPMENT',       'Administrative Laptops',              1, 2000.00, 2000.00, 18.00, 360.00, 2360.00), -- Anomaly 3B (Over-taxation 18% on IT)
    (15, 14, 'GENERAL_STATIONERY', 'Printer Paper Bulk',                  1, 1000.00, 1000.00, 0.00,    0.00, 1000.00), -- Anomaly 3C (Rate outlier 0%)
    (16, 15, 'BUILDING_MAINTENANCE','Emergency Pipe Repair',              1, 1000.00, 1000.00, 5.00,   50.00, 1050.00), -- Anomaly 3D (Rate outlier 5%)
    (17, 16, 'CIVIL_CONSTRUCTION', 'Sidewalk Paving Works',               1,10000.00,10000.00, 20.00, 2000.00, 12000.00),-- Anomaly 3E (Rate outlier 20%)
    (18, 17, 'CIVIL_CONSTRUCTION', 'Road Resurfacing Asphalt',            1,10000.00,10000.00, 18.00, 1200.00, 11200.00),-- Anomaly 3F (VAT arithmetic diff)

    -- Lines for Query 4 Invoices
    (19, 18, 'OFFICE_FURNITURE',   'Modular Office Partitioning A',       1, 2000.00, 2000.00, 18.00, 360.00, 2360.00),
    (20, 19, 'OFFICE_FURNITURE',   'Modular Office Partitioning B',       1, 2000.00, 2000.00, 18.00, 360.00, 2360.00),
    (21, 20, 'OFFICE_FURNITURE',   'Modular Office Partitioning C',       1, 2000.00, 2000.00, 18.00, 360.00, 2360.00),
    (22, 21, 'IT_EQUIPMENT',       'Municipal Server Core Unit 1',        1, 7500.00, 7500.00, 8.00,  600.00, 8100.00),
    (23, 22, 'IT_EQUIPMENT',       'Municipal Server Core Unit 2',        1, 8000.00, 8000.00, 8.00,  640.00, 8640.00),

    -- Lines for Query 5 Invoices
    (24, 23, 'CIVIL_CONSTRUCTION', 'Prizren Public Square Paving',        1,10000.00,10000.00, 18.00, 1800.00, 11800.00),
    (25, 24, 'PHARMACEUTICALS',    'Emergency First Aid Clinical Supplies',1,10000.00,10000.00, 8.00,  800.00, 10800.00);

COMMIT;

-- ============================================================================
-- 5. VALIDATION BLOCK
-- ============================================================================

SELECT '--- TABLE RECORD COUNTS ---' AS validation_check;
SELECT 'vendors' AS table_name, COUNT(*) AS actual_count, 4 AS expected_count FROM vendors
UNION ALL
SELECT 'procurement_awards', COUNT(*), 4 FROM procurement_awards
UNION ALL
SELECT 'invoices', COUNT(*), 24 FROM invoices
UNION ALL
SELECT 'invoice_line_items', COUNT(*), 25 FROM invoice_line_items;

SELECT '--- PROCUREMENT AWARD EXPENDITURE TOTALS ---' AS validation_check;
SELECT
    a.award_id,
    a.procurement_number,
    a.recorded_award_value,
    ROUND(SUM(i.recorded_total), 2) AS cumulative_billed_total,
    CASE
        WHEN a.award_id = 2 THEN 'Expected: 18156.00 (Compliant baseline)'
        WHEN a.award_id = 4 THEN 'Expected: 16740.00 (Overrun anomaly)'
        ELSE 'Informational'
    END AS expectation_status
FROM procurement_awards a
JOIN invoices i ON a.award_id = i.award_id
WHERE a.award_id IN (2, 4)
GROUP BY a.award_id, a.procurement_number, a.recorded_award_value;