# Anomaly Injection Plan

## Purpose

This document maps every deliberately-injected anomaly in `sql/seed_data.sql`
to the analytical query that should detect it, and to the control rows that
must **not** be flagged.

Every identifier here (line-item ID, invoice ID, invoice number) matches the
rows actually present in `sql/seed_data.sql`. If you change the seed data,
you must update this document — the tests in `sql/test_queries.sql` will fail
if the two diverge.

---

## Dataset overview

| Entity              | Rows |
|---------------------|------|
| vendors             | 4    |
| procurement_awards  | 4    |
| invoices            | 24   |
| invoice_line_items  | 25   |

---

## Audit coverage map

| Query  | Detects                                          | Line-item IDs            | Invoice IDs      |
|--------|--------------------------------------------------|--------------------------|------------------|
| 1A     | Reused invoice number by same vendor             | n/a                      | 3, 4             |
| 1B     | Split/duplicate claim across distinct numbers    | n/a                      | 5, 6             |
| 2A     | Line-item arithmetic discrepancies               | 8, 9                     | 8, 9             |
| 2B     | Header vs sum-of-lines reconciliation            | 10                       | 10               |
| 3      | VAT classification & computation review          | 13, 14, 15, 16, 17, 18   | 12–17            |
| 4      | Invoice totals exceeding recorded award value    | n/a                      | 21, 22           |
| 5A     | Vendor mismatch requiring review                 | n/a                      | 24               |
| 5B     | Vendor billing & exception summary               | n/a                      | all              |

---

## Query 1 — Duplicate invoice reference detection

### Scenario A — same vendor, same invoice number

| Invoice | Invoice number         | Vendor   | Date        | Amount   |
|---------|------------------------|----------|-------------|----------|
| 3       | SYNTH-INV-2023-0102    | Vendor 1 | 2023-04-15  | 2,160.00 |
| 4       | SYNTH-INV-2023-0102    | Vendor 1 | 2023-04-20  | 2,160.00 |

Expected: one row, `duplicate_scenario = 'DUPLICATE_INVOICE_NUMBER'`,
`submission_count = 2`, `total_amount_claimed = 4320.00`.

### Scenario B — distinct numbers, identical billing context

| Invoice | Invoice number         | Vendor   | Award | Date        | Amount   |
|---------|------------------------|----------|-------|-------------|----------|
| 5       | SYNTH-INV-2023-0103    | Vendor 2 | 2     | 2023-05-02  | 1,770.00 |
| 6       | SYNTH-INV-2023-0104    | Vendor 2 | 2     | 2023-05-02  | 1,770.00 |

Expected: one row, `duplicate_scenario = 'SUSPECTED_SPLIT_OR_DUPLICATE_CLAIM'`,
`flagged_references = 'SYNTH-INV-2023-0103, SYNTH-INV-2023-0104'`,
`submission_count = 2`, `total_amount_claimed = 3540.00`.

### Control case — must NOT be flagged

| Invoice | Invoice number         | Vendor   |
|---------|------------------------|----------|
| 1       | SYNTH-INV-2023-0101    | Vendor 1 |
| 2       | SYNTH-INV-2023-0101    | Vendor 2 |

Same invoice number across two different vendors is legitimate. If either of
these appears in the Query 1 output, the grouping logic is wrong.

---

## Query 2A — Line-item arithmetic discrepancies

### Line 8 — subtotal does not equal quantity × unit_price

| Field               | Value      |
|---------------------|------------|
| Line item           | 8          |
| Invoice             | 8 (SYNTH-INV-2023-0202, Vendor 2) |
| Quantity × unit_price | 5 × 200.00 = 1,000.00 |
| Recorded line_subtotal | 1,200.00 |
| **Discrepancy**     | **+200.00** |
| VAT amount recorded | 216.00 (18% of 1,200) |
| Line total recorded | 1,416.00 (1,200 + 216) |
| Line total check    | consistent — only the subtotal is wrong |

### Line 9 — line_total does not equal line_subtotal + vat_amount

| Field               | Value      |
|---------------------|------------|
| Line item           | 9          |
| Invoice             | 9 (SYNTH-INV-2023-0203, Vendor 3) |
| Quantity × unit_price | 1 × 1,500.00 = 1,500.00 |
| Recorded line_subtotal | 1,500.00 — consistent |
| VAT amount recorded | 270.00 (18%) |
| Recorded line_total | 1,900.00 |
| Calculated line_total | 1,770.00 |
| **Discrepancy**     | **+130.00** |

### Controls — must NOT be flagged

- Line 7 (Invoice 7): 10 × 400.00 = 4,000.00, VAT 320.00 (8%), total 4,320.00 — fully consistent.
- Lines 11 & 12 (Invoice 11): 2,000.00 + 160.00 = 2,160.00 and 1,000.00 + 180.00 = 1,180.00 — each consistent.

---

## Query 2B — Invoice header vs sum of line items

### Invoice 10 — header total does not match line items

| Field                  | Value      |
|------------------------|------------|
| Invoice                | 10 (SYNTH-INV-2023-0204, Vendor 2) |
| Recorded header total  | 500.00 |
| Sum of line totals (Line 10) | 354.00 |
| **Discrepancy**        | **146.00** |

Line 10 itself (20 × 15.00 = 300.00, VAT 54.00, total 354.00) is internally
consistent — the error is only in the invoice header.

### Control — must NOT be flagged

- Invoice 7: header 4,320.00, single line 7 totals 4,320.00.
- Invoice 11: header 3,340.00, lines 11 + 12 total 3,340.00.

---

## Query 3 — VAT classification & computation review

All Query 3 findings are labelled `REQUIRES_REVIEW - …`. They are candidates
for an auditor's review, not legal conclusions of tax evasion or
non-compliance. The MVP models only the two statutory taxable rates (18% and
8%); exempt supplies under Article 27 are out of scope.

### Potential misclassification — reduced rate on standard-rated category

| Line | Invoice | Category           | Rate   | Finding |
|------|---------|--------------------|--------|---------|
| 13   | 12      | OFFICE_FURNITURE   | 8.00%  | POTENTIAL_MISCLASSIFICATION_REDUCED_ON_STANDARD |

### Potential overcharge — standard rate on reduced-rated category

| Line | Invoice | Category     | Rate   | Finding |
|------|---------|--------------|--------|---------|
| 14   | 13      | IT_EQUIPMENT | 18.00% | POTENTIAL_OVERCHARGE_STANDARD_ON_REDUCED |

### Non-statutory rate (outside MVP scope)

| Line | Invoice | Category              | Rate   | Finding |
|------|---------|-----------------------|--------|---------|
| 15   | 14      | GENERAL_STATIONERY    | 0.00%  | NON_STATUTORY_RATE |
| 16   | 15      | BUILDING_MAINTENANCE  | 5.00%  | NON_STATUTORY_RATE |
| 17   | 16      | CIVIL_CONSTRUCTION    | 20.00% | NON_STATUTORY_RATE |

### VAT arithmetic mismatch — correct rate, wrong amount

| Line | Invoice | Category           | Rate   | Subtotal | Recorded VAT | Calculated VAT | Diff     | Finding |
|------|---------|--------------------|--------|----------|--------------|----------------|----------|---------|
| 18   | 17      | CIVIL_CONSTRUCTION | 18.00% | 10,000.00 | 1,200.00    | 1,800.00       | −600.00  | VAT_ARITHMETIC_MISMATCH |

### Controls — must NOT be flagged

Compliant lines for both reduced and standard rates:

- Line 1 (IT_EQUIPMENT @ 8%), Line 2 (OFFICE_FURNITURE @ 18%)
- Line 11 (IT_EQUIPMENT @ 8%), Line 12 (OFFICE_FURNITURE @ 18%)
- Lines 22 & 23 (IT_EQUIPMENT @ 8%), Line 24 (CIVIL_CONSTRUCTION @ 18%)
- Line 25 (PHARMACEUTICALS @ 8%)

---

## Query 4 — Invoice totals exceeding recorded award value

### Flagged

| Award | Authority       | Recorded award | Invoices | Total billed | Over by | Utilization |
|-------|-----------------|----------------|----------|--------------|---------|-------------|
| 4     | Komuna e Pejës  | 15,000.00      | 21, 22   | 16,740.00    | 1,740.00 | 111.60% |

Invoice 21 = 8,100.00, Invoice 22 = 8,640.00, sum = 16,740.00.

### Controls — must NOT be flagged

| Award | Recorded award | Total billed | Utilization |
|-------|----------------|--------------|-------------|
| 1     | 50,000.00      | 18,660.00    | 37.32%      |
| 2     | 20,000.00      | 18,156.00    | 90.78%      |
| 3     | 80,000.00      | 48,750.00    | 60.94%      |

Note: `recorded_award_value` is the recorded award figure. In a real public
procurement environment this may be net of VAT, or may have been amended by a
contract annex. A row in Query 4 is a candidate for investigation, not proof
of an unauthorized contract breach.

---

## Query 5A — Vendor mismatch requiring review

| Invoice | Number                | Date        | Amount    | Awarded vendor             | Billing vendor                    |
|---------|-----------------------|-------------|-----------|----------------------------|-----------------------------------|
| 24      | SYNTH-INV-2023-0502   | 2023-09-15  | 10,800.00 | Vendor 3 (Kastrioti Building) | Vendor 4 (Prishtina Medical)   |

The invoice references Award 3, which was awarded to Vendor 3, but was
submitted by Vendor 4. This may reflect subcontracting, data-entry error, or
misdirected billing. It is flagged for review, not asserted as unauthorized.

---

## Query 5B — Vendor billing & exception summary

Expected rollup across all four vendors:

| Vendor | Invoices | Total billed | Vendor mismatches |
|--------|----------|--------------|-------------------|
| 1 — Dardania Tech         | 8  | 35,400.00 | 0 |
| 2 — Dukagjini Office      | 10 | 18,156.00 | 0 |
| 3 — Kastrioti Building    | 5  | 37,950.00 | 0 |
| 4 — Prishtina Medical     | 1  | 10,800.00 | 1 |

Total invoice count = 24, matching `sql/seed_data.sql`.

---

## Expected row counts (used by `sql/test_queries.sql`)

| Query  | Expected rows |
|--------|---------------|
| 1      | 2             |
| 2A     | 2             |
| 2B     | 1             |
| 3      | 6             |
| 4      | 1             |
| 5A     | 1             |
| 5B     | 4             |

If any test reports FAIL, the seed data or the query definition has changed
relative to this plan. Do not “fix” the test by changing the expected count
without first understanding why the data or query changed.