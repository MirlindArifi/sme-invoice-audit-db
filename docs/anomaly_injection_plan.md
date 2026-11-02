# Audit Anomaly Injection Plan & Test Specification

## 1. Purpose & Methodology
This document specifies the deliberate anomalies and control records designed to validate the five analytical audit queries.
- **Positive Test Cases (Anomalies):** Deliberately malformed or inconsistent records that an audit query **must flag**.
- **Negative Test Cases (Controls):** Clean, valid transactions that each query **must NOT flag** (verifying query selectivity and preventing false positives).
- **Isolation Principle:** Each anomaly is isolated to test its designated query without unintentionally triggering unrelated audit queries, unless part of the cross-query rollup in Query 5.

---

## 2. Test Entities Baseline (Fixtures)

### Synthetic Vendors
| Vendor ID | Fiscal Identifier | Vendor Name | Role in Test |
| :---: | :--- | :--- | :--- |
| `1` | `SYNTH-TAX-1001` | Dardania Tech Solutions SH.P.K. (Synthetic) | Primary IT & Electronics supplier |
| `2` | `SYNTH-TAX-1002` | Dukagjini Office Supplies SH.P.K. (Synthetic) | Furniture & Stationery supplier |
| `3` | `SYNTH-TAX-1003` | Kastrioti Building & Maintenance SH.P.K. (Synthetic) | Works & Maintenance contractor |
| `4` | `SYNTH-TAX-1004` | Prishtina Medical & Pharma SH.P.K. (Synthetic) | Healthcare supplier / Unauthorized billing entity |

### Synthetic Procurement Awards
| Award ID | Procurement Number | Authority Name | Awarded Vendor ID | Recorded Award Value | Category |
| :---: | :--- | :--- | :---: | :---: | :--- |
| `1` | `SYNTH-616-23-001-521` | Komuna e Prishtinës | `1` (Dardania) | € 50,000.00 | SUPPLIES |
| `2` | `SYNTH-616-23-002-521` | Komuna e Prishtinës | `2` (Dukagjini) | € 20,000.00 | SUPPLIES |
| `3` | `SYNTH-616-23-003-511` | Komuna e Prizrenit | `3` (Kastrioti) | € 80,000.00 | WORKS |
| `4` | `SYNTH-616-23-004-521` | Komuna e Pejës | `1` (Dardania) | € 15,000.00 | SUPPLIES |

---

## 3. Clean Baseline Invoices (Specification for Non-Target Lines)

### Baseline Rule
Every invoice in the system must possess valid line-item records to avoid triggering Query 2's header reconciliation check. For all invoices not explicitly manipulated in Query 2 or Query 3, line items follow this deterministic rule:
- `quantity = 1`
- `unit_price = line_subtotal`
- `vat_rate = statutory rate for item_category` (8.00% for IT/Pharma/Books; 18.00% for Furniture/Maintenance/Stationery/Works)
- `vat_amount = ROUND(line_subtotal * (vat_rate / 100), 2)`
- `line_total = ROUND(line_subtotal + vat_amount, 2)`
- `invoices.recorded_total = line_total`

### Explicit Baseline Line Items Table
| Invoice Number | Billing Vendor ID | Award ID | Invoice Date | Line Item ID | Category | Subtotal | VAT % | VAT € | Line Total | Header Total | Purpose |
| :--- | :---: | :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| `SYNTH-INV-2023-0101` | `1` | `1` | `2023-03-10` | `1` | `IT_EQUIPMENT` | € 4,000.00 | 8% | € 320.00 | € 4,320.00 | € 4,320.00 | Control (Q1 Vendor 1) |
| `SYNTH-INV-2023-0101` | `2` | `2` | `2023-03-15` | `2` | `OFFICE_FURNITURE` | € 3,000.00 | 18% | € 540.00 | € 3,540.00 | € 3,540.00 | Control (Q1 Vendor 2, distinct date) |
| `SYNTH-INV-2023-0102` | `1` | `1` | `2023-04-15` | `3` | `IT_EQUIPMENT` | € 2,000.00 | 8% | € 160.00 | € 2,160.00 | € 2,160.00 | Anomaly 1A (Original invoice) |
| `SYNTH-INV-2023-0102` | `1` | `1` | `2023-04-20` | `4` | `IT_EQUIPMENT` | € 2,000.00 | 8% | € 160.00 | € 2,160.00 | € 2,160.00 | Anomaly 1B (Duplicate number) |
| `SYNTH-INV-2023-0103` | `2` | `2` | `2023-05-02` | `5` | `GENERAL_STATIONERY` | € 1,500.00 | 18% | € 270.00 | € 1,770.00 | € 1,770.00 | Anomaly 1C (Original submission) |
| `SYNTH-INV-2023-0104` | `2` | `2` | `2023-05-02` | `6` | `GENERAL_STATIONERY` | € 1,500.00 | 18% | € 270.00 | € 1,770.00 | € 1,770.00 | Anomaly 1D (Split/Duplicate total) |
| `SYNTH-INV-2023-0411` | `2` | `2` | `2023-06-01` | `7` | `OFFICE_FURNITURE` | € 2,000.00 | 18% | € 360.00 | € 2,360.00 | € 2,360.00 | Control (Award 2 ceiling check) |
| `SYNTH-INV-2023-0412` | `2` | `2` | `2023-06-15` | `8` | `GENERAL_STATIONERY` | € 2,000.00 | 18% | € 360.00 | € 2,360.00 | € 2,360.00 | Control (Award 2 ceiling check) |
| `SYNTH-INV-2023-0413` | `2` | `2` | `2023-07-01` | `9` | `OFFICE_FURNITURE` | € 2,000.00 | 18% | € 360.00 | € 2,360.00 | € 2,360.00 | Control (Award 2 ceiling check) |
| `SYNTH-INV-2023-0401` | `1` | `4` | `2023-08-01` | `10` | `IT_EQUIPMENT` | € 7,500.00 | 8% | € 600.00 | € 8,100.00 | € 8,100.00 | Anomaly 4A Part 1 (Clean line) |
| `SYNTH-INV-2023-0402` | `1` | `4` | `2023-08-20` | `11` | `IT_EQUIPMENT` | € 8,000.00 | 8% | € 640.00 | € 8,640.00 | € 8,640.00 | Anomaly 4A Part 2 (Overrun trigger) |
| `SYNTH-INV-2023-0501` | `3` | `3` | `2023-09-01` | `12` | `CIVIL_CONSTRUCTION` | € 10,000.00 | 18% | € 1,800.00 | € 11,800.00 | € 11,800.00 | Control (Valid vendor billing) |
| `SYNTH-INV-2023-0502` | `4` | `3` | `2023-09-15` | `13` | `PHARMACEUTICALS` | € 10,000.00 | 8% | € 800.00 | € 10,800.00 | € 10,800.00 | Anomaly 5A (Vendor Mismatch) |

*Note on Award 2 cumulative billing:* Award 2's cumulative billed amount includes both the control invoices above AND the four anomaly invoices from other queries that also bill against Award 2 (`0202` €1,416.00, `0204` €500.00, `0302` €1,080.00, `0304` €1,000.00). Full sum: €3,540.00 + €1,770.00 + €1,770.00 + €2,360.00 + €2,360.00 + €2,360.00 + €1,416.00 + €500.00 + €1,080.00 + €1,000.00 = **€18,156.00 ≤ €20,000.00**. Utilization: 90.78%. Award 2 remains a valid Query 4 control.

---

## 4. Query 1: Duplicate Invoice Reference Detection

### Business Rule Tested
1. **Primary Check:** Same `billing_vendor_id` submitting identical `invoice_number` across multiple records (`COUNT(*) > 1`).
2. **Secondary Check:** Same `billing_vendor_id`, same `award_id`, same `invoice_date`, and identical `recorded_total` across distinct invoice numbers (suspected duplicate payment claim).

### Test Cases
| Case Type | Invoice Number | Billing Vendor ID | Award ID | Invoice Date | Recorded Total | Anomaly Details | Expected Query Behavior |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- | :--- |
| **Control** | `SYNTH-INV-2023-0101` | `1` | `1` | `2023-03-10` | € 4,320.00 | Unique invoice number, clean values. | **Ignored** (Not flagged). |
| **Control** | `SYNTH-INV-2023-0101` | `2` | `2` | `2023-03-15` | € 3,540.00 | Same invoice number as above, but **different vendor and date**. | **Ignored** (Distinct vendors may legitimately have matching internal numbering). |
| **Positive (Anomaly 1A)** | `SYNTH-INV-2023-0102` | `1` | `1` | `2023-04-15` | € 2,160.00 | Original submission. | **Flagged** alongside 1B as a duplicate invoice number group (`COUNT(*) > 1`). |
| **Positive (Anomaly 1B)** | `SYNTH-INV-2023-0102` | `1` | `1` | `2023-04-20` | € 2,160.00 | **Exact duplicate invoice number** reused by Vendor 1 on a later date. | **Flagged** alongside 1A as a duplicate invoice number group (`COUNT(*) > 1`). |
| **Positive (Anomaly 1C)** | `SYNTH-INV-2023-0103` | `2` | `2` | `2023-05-02` | € 1,770.00 | Distinct invoice number. | **Flagged** under secondary check: identical vendor, award, date, and amount as 1D. |
| **Positive (Anomaly 1D)** | `SYNTH-INV-2023-0104` | `2` | `2` | `2023-05-02` | € 1,770.00 | Different invoice number, but **same vendor, same award, same date, identical total**. | **Flagged** under secondary check: suspected duplicate payment claim. |

---

## 5. Query 2: Invoice Line-Item & Header Arithmetic Validation

### Business Rule Tested
1. Line Subtotal: `line_subtotal = ROUND(quantity * unit_price, 2)`.
2. Line Total: `line_total = ROUND(line_subtotal + vat_amount, 2)`.
3. Header Reconciliation: `invoices.recorded_total = ROUND(SUM(invoice_line_items.line_total), 2)`.

### Test Cases
| Case Type | Invoice Number | Billing Vendor ID | Award ID | Invoice Date | Line Item ID | Category | Qty | Unit Price | Line Subtotal | VAT % | VAT € | Line Total | Header Total | Anomaly Details | Expected Query Output |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| **Control** | `SYNTH-INV-2023-0201` | `1` | `1` | `2023-05-10` | `101` | `IT_EQUIPMENT` | `10` | € 400.00 | € 4,000.00 | 8% | € 320.00 | € 4,320.00 | € 4,320.00 | Perfectly calculated. | **Ignored** (No discrepancy). |
| **Positive (Anomaly 2A)** | `SYNTH-INV-2023-0202` | `2` | `2` | `2023-05-12` | `102` | `OFFICE_FURNITURE` | `5` | € 200.00 | **€ 1,200.00** | 18% | € 216.00 | € 1,416.00 | € 1,416.00 | **Subtotal Error:** `5 * 200 = 1,000.00`, but recorded as `1,200.00`. | Flagged on Line 102: `subtotal_discrepancy = 200.00`. |
| **Positive (Anomaly 2B)** | `SYNTH-INV-2023-0203` | `3` | `3` | `2023-05-15` | `103` | `BUILDING_MAINTENANCE` | `1` | € 1,500.00 | € 1,500.00 | 18% | € 270.00 | **€ 1,900.00** | € 1,900.00 | **Line Total Error:** `1,500 + 270 = 1,770.00`, but recorded as `1,900.00`. | Flagged on Line 103: `line_total_discrepancy = 130.00`. |
| **Positive (Anomaly 2C)** | `SYNTH-INV-2023-0204` | `2` | `2` | `2023-05-18` | `104` | `GENERAL_STATIONERY` | `20` | € 15.00 | € 300.00 | 18% | € 54.00 | € 354.00 | **€ 500.00** | **Header Error:** Line total is `€ 354.00`, but invoice header claims `€ 500.00`. | Flagged on Invoice header: `header_vs_lines_discrepancy = 146.00`. |

---

## 6. Query 3: VAT Rate Classification & Computation Audit

### Statutory Framework (Law No. 05/L-037)
- **Standard Rate (18%):** Default for `OFFICE_FURNITURE`, `BUILDING_MAINTENANCE`, `GENERAL_STATIONERY`, `CIVIL_CONSTRUCTION` (Art. 26(1)).
- **Reduced Rate (8%):** Legally restricted to qualifying supplies, including `IT_EQUIPMENT` (Art. 26(2)(11)), `TEXTBOOKS_AND_BOOKS` (Art. 26(2)(9–10)), and `PHARMACEUTICALS` (Art. 26(2)(12–13)).

### Audit Semantic Distinction: Under-Taxation vs. Over-Taxation
- **Anomaly 3A (Under-Taxation):** Applying the 8% reduced rate to non-qualifying goods (`OFFICE_FURNITURE`). The reduced rate is a legal restriction; applying it improperly constitutes a tax classification violation and under-remittance of statutory tax.
- **Anomaly 3B (Over-Taxation / Municipal Over-Billing):** Applying the 18% standard rate to legally reduced goods (`IT_EQUIPMENT`). While collecting 18% does not violate minimum tax remittance rules to TAK, it represents failure to claim statutory rate relief and results in unwarranted public expenditure by the contracting authority.

### Test Cases
| Case Type | Invoice Number | Billing Vendor ID | Award ID | Invoice Date | Line Item ID | Category | Subtotal | Rec. VAT % | Rec. VAT € | Line Total | Header Total | Anomaly Subtype | Expected Query Output |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| **Control** | `SYNTH-INV-2023-0301` | `1` | `1` | `2023-06-05` | `201` | `IT_EQUIPMENT` | € 2,000.00 | 8.00% | € 160.00 | € 2,160.00 | € 3,340.00* | Valid | **Ignored** (Compliant). |
| **Control** | `SYNTH-INV-2023-0301` | `1` | `1` | `2023-06-05` | `202` | `OFFICE_FURNITURE` | € 1,000.00 | 18.00% | € 180.00 | € 1,180.00 | € 3,340.00* | Valid | **Ignored** (Compliant). |
| **Positive (Anomaly 3A)** | `SYNTH-INV-2023-0302` | `2` | `2` | `2023-06-08` | `203` | `OFFICE_FURNITURE` | € 1,000.00 | **8.00%** | € 80.00 | € 1,080.00 | € 1,080.00 | **Category Mismatch: Under-Taxation** | Flagged: `FLAG_UNDER_TAXATION` (Recorded 8%, Statutory 18%). |
| **Positive (Anomaly 3B)** | `SYNTH-INV-2023-0303` | `1` | `1` | `2023-06-10` | `204` | `IT_EQUIPMENT` | € 2,000.00 | **18.00%** | € 360.00 | € 2,360.00 | € 2,360.00 | **Category Mismatch: Over-Taxation** | Flagged: `FLAG_OVER_TAXATION` (Recorded 18%, Statutory 8%). |
| **Positive (Anomaly 3C)** | `SYNTH-INV-2023-0304` | `2` | `2` | `2023-06-12` | `205` | `GENERAL_STATIONERY` | € 1,000.00 | **0.00%** | € 0.00 | € 1,000.00 | € 1,000.00 | **Rate Outlier** | Flagged: `FLAG_RATE_OUTLIER` (0.00% invalid for taxable supply). |
| **Positive (Anomaly 3D)** | `SYNTH-INV-2023-0305` | `3` | `3` | `2023-06-15` | `206` | `BUILDING_MAINTENANCE` | € 1,000.00 | **5.00%** | € 50.00 | € 1,050.00 | € 1,050.00 | **Rate Outlier** | Flagged: `FLAG_RATE_OUTLIER` (5.00% non-existent under Kosovo law). |
| **Positive (Anomaly 3E)** | `SYNTH-INV-2023-0306` | `3` | `3` | `2023-06-18` | `207` | `CIVIL_CONSTRUCTION` | € 10,000.00 | **20.00%** | € 2,000.00 | € 12,000.00 | € 12,000.00 | **Rate Outlier** | Flagged: `FLAG_RATE_OUTLIER` (20.00% invalid rate). |
| **Positive (Anomaly 3F)** | `SYNTH-INV-2023-0307` | `3` | `3` | `2023-06-20` | `208` | `CIVIL_CONSTRUCTION` | € 10,000.00 | 18.00% | **€ 1,200.00** | **€ 11,200.00** | **€ 11,200.00** | **Arithmetic Discrepancy** | Flagged: `FLAG_VAT_ARITHMETIC` (`calc_vat = 1800.00`, `diff = -600.00`). |

*\*Note on Invoice `SYNTH-INV-2023-0301`: Multi-line invoice containing Lines 201 and 202 (`2,160.00 + 1,180.00 = 3,340.00`). Header total is € 3,340.00.*

*\*Note on Anomaly 3F Query Isolation: Line total is recorded as € 11,200.00 and Header total is recorded as € 11,200.00. Therefore, Query 2 arithmetic checks pass cleanly (`10,000.00 + 1,200.00 = 11,200.00` and header matches line sum). The fault is isolated 100% to Query 3.*

---

## 7. Query 4: Invoice Totals Exceeding Recorded Award Value

### Business Rule Tested
- Billed expenditure against an award must not exceed the authorized baseline:
  `ROUND(SUM(invoices.recorded_total), 2) <= procurement_awards.recorded_award_value`.

### Test Cases
| Case Type | Award ID | Procurement Number | Recorded Award Value | Invoices Associated | Cumulative Billed | Utilization % | Expected Query Output |
| :--- | :---: | :--- | :---: | :--- | :---: | :---: | :--- |
| **Control** | `2` | `SYNTH-616-23-002-521` | € 20,000.00 | 10 invoices (`0101`, `0103`, `0104`, `0411`, `0412`, `0413`, `0202`, `0204`, `0302`, `0304`) | € 18,156.00 | 90.78% | **Ignored** (No overrun). |
| **Positive (Anomaly 4A)** | `4` | `SYNTH-616-23-004-521` | € 15,000.00 | `SYNTH-INV-2023-0401` (€ 8,100.00)<br>`SYNTH-INV-2023-0402` (€ 8,640.00) | **€ 16,740.00** | **111.60%** | Flagged: Award ID 4, `overrun_amount = € 1,740.00` (`utilization_pct = 111.60%`). |

---

## 8. Query 5: Vendor Exception Summary & Entity Mismatch

### Business Rule Tested
1. An invoice header must identify the same vendor entity awarded the contract:
   `invoices.billing_vendor_id = procurement_awards.vendor_id`.
2. Cross-query rollup aggregates total exceptions and financial exposure per vendor.

### Test Cases
| Case Type | Invoice Number | Billing Vendor ID | Award ID | Awarded Vendor ID | Invoice Date | Recorded Total | Anomaly Details | Expected Query Output |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- | :--- |
| **Control** | `SYNTH-INV-2023-0501` | `3` (Kastrioti) | `3` | `3` (Kastrioti) | `2023-09-01` | € 11,800.00 | Billing vendor matches awarded vendor. | **Ignored** by mismatch filter. |
| **Positive (Anomaly 5A)** | `SYNTH-INV-2023-0502` | **`4` (Prishtina Medical)** | `3` | `3` (Kastrioti) | `2023-09-15` | € 10,800.00 | **Entity Mismatch:** Contract was awarded to Kastrioti (Works), but invoice submitted by Prishtina Medical. | Flagged under Mismatch Audit: `awarded_vendor != billing_vendor`. |
| **Aggregation Check** | *All Vendors* | — | — | — | — | — | Rollup across Queries 1–5. | Ranks vendors by total exceptions and flagged exposure. |

---

## 9. Date Collision Audit Matrix (Selectivity Verification)

To guarantee that Query 1's secondary check (`billing_vendor_id, award_id, invoice_date, recorded_total`) does not produce false positives among clean records, every invoice has a verified distinct date/amount combination:

| Invoice Number | Billing Vendor | Award | Date | Total | Check Status |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `SYNTH-INV-2023-0101` | `1` | `1` | `2023-03-10` | € 4,320.00 | Clean Control (Unique date/vendor/award) |
| `SYNTH-INV-2023-0101` | `2` | `2` | `2023-03-15` | € 3,540.00 | Clean Control (Unique date/vendor/award) |
| `SYNTH-INV-2023-0102` | `1` | `1` | `2023-04-15` | € 2,160.00 | Anomaly 1A (Unique date) |
| `SYNTH-INV-2023-0102` | `1` | `1` | `2023-04-20` | € 2,160.00 | Anomaly 1B (Duplicate number, distinct date) |
| `SYNTH-INV-2023-0103` | `2` | `2` | `2023-05-02` | € 1,770.00 | Anomaly 1C (Target collision pair with 1D) |
| `SYNTH-INV-2023-0104` | `2` | `2` | `2023-05-02` | € 1,770.00 | Anomaly 1D (Target collision pair with 1C) |
| `SYNTH-INV-2023-0201` | `1` | `1` | `2023-05-10` | € 4,320.00 | Clean Control (Distinct date from 0101) |
| `SYNTH-INV-2023-0202` | `2` | `2` | `2023-05-12` | € 1,416.00 | Anomaly 2A (Unique date) |
| `SYNTH-INV-2023-0203` | `3` | `3` | `2023-05-15` | € 1,900.00 | Anomaly 2B (Unique date) |
| `SYNTH-INV-2023-0204` | `2` | `2` | `2023-05-18` | € 500.00 | Anomaly 2C (Unique date) |
| `SYNTH-INV-2023-0301` | `1` | `1` | `2023-06-05` | € 3,340.00 | Clean Control (Unique date) |
| `SYNTH-INV-2023-0302` | `2` | `2` | `2023-06-08` | € 1,080.00 | Anomaly 3A (Unique date) |
| `SYNTH-INV-2023-0303` | `1` | `1` | `2023-06-10` | € 2,360.00 | Anomaly 3B (Unique date) |
| `SYNTH-INV-2023-0304` | `2` | `2` | `2023-06-12` | € 1,000.00 | Anomaly 3C (Unique date) |
| `SYNTH-INV-2023-0305` | `3` | `3` | `2023-06-15` | € 1,050.00 | Anomaly 3D (Unique date) |
| `SYNTH-INV-2023-0306` | `3` | `3` | `2023-06-18` | € 12,000.00 | Anomaly 3E (Unique date) |
| `SYNTH-INV-2023-0307` | `3` | `3` | `2023-06-20` | € 11,200.00 | Anomaly 3F (Unique date) |
| `SYNTH-INV-2023-0411` | `2` | `2` | `2023-06-01` | € 2,360.00 | Clean Control (Unique date) |
| `SYNTH-INV-2023-0412` | `2` | `2` | `2023-06-15` | € 2,360.00 | Clean Control (Unique date) |
| `SYNTH-INV-2023-0413` | `2` | `2` | `2023-07-01` | € 2,360.00 | Clean Control (Unique date) |
| `SYNTH-INV-2023-0401` | `1` | `4` | `2023-08-01` | € 8,100.00 | Anomaly 4A Part 1 (Unique date) |
| `SYNTH-INV-2023-0402` | `1` | `4` | `2023-08-20` | € 8,640.00 | Anomaly 4A Part 2 (Unique date) |
| `SYNTH-INV-2023-0501` | `3` | `3` | `2023-09-01` | € 11,800.00 | Clean Control (Unique date) |
| `SYNTH-INV-2023-0502` | `4` | `3` | `2023-09-15` | € 10,800.00 | Anomaly 5A (Unique date) |

---

## 10. Final Count Sanity Check

- **Total Injected Anomalies:** 15 (`1A`, `1B`, `1C`, `1D`, `2A`, `2B`, `2C`, `3A`, `3B`, `3C`, `3D`, `3E`, `3F`, `4A`, `5A`).
- **Total Clean Controls:** 7 distinct control test scenarios (Q1 Vendor 1, Q1 Vendor 2, Q2 Control, Q3 Controls [Lines 201 & 202], Q4 Control Award 2 [with 3 baseline invoices 0411–0413], Q5 Control).
- **Total Physical Invoices:** 24 invoice records (comprising 22 distinct invoice numbers: `SYNTH-INV-2023-0101` used by two vendors, `SYNTH-INV-2023-0102` duplicated by Vendor 1).
- **Total Physical Line Items:** 25 line items (13 baseline lines + 4 in Query 2 + 8 in Query 3, with Invoice 0301 having 2 lines).