# Data Feasibility & Source Provenance Investigation

This document records the investigation that determined which parts of the
SME Invoice Audit DB could be sourced from authentic public records and which
parts had to be modelled as synthetic fixtures. It exists so a reviewer can
see what was actually checked, what was found, and why the project ended up
using fully synthetic invoice data.

---

## 1. Source investigated — Kosovo KRPP / OCDS

The Kosovo Public Procurement Regulatory Commission (KRPP) publishes
procurement data through an Open Contracting Data Standard (OCDS) API.

### What the API documents

Official API documentation: <https://ocdskrpp.rks-gov.net/Help>

The documentation describes endpoints for:

- Tender releases
- Award releases
- Parties (suppliers)
- Bids
- Documents

The **Award** endpoint documentation exposes fields such as tender number,
award date, award value, currency, contract period, and supplier information.

### What the OCP Data Registry publishes

Publication: <https://data.open-contracting.org/en/publication/115>

The Open Contracting Partnership's registry lists a Kosovo PPRC dataset with:

| Metric | Value |
|:---|:---|
| Tender records | ~75,710 |
| Party records | ~211,313 |
| Award objects in published snapshot | 0 |
| Contract objects in published snapshot | 0 |

The registry also documents a known data-quality issue: the `awards` array in
some releases is misspelled as `award`, which can cause award records to be
silently dropped by naive consumers of the dataset.

### What this means for the project

The public procurement layer publishes tender-stage and party metadata, but
the standard award and contract objects are **not reliably present** in the
published OCDS snapshot. A project that wants a full "awarded supplier, award
value, invoiced line items, VAT amounts" chain cannot be built from this
snapshot alone without doing significant additional reconciliation and
recovery work that is outside the scope of this portfolio project.

---

## 2. The public / private accounting boundary

Even where award metadata is available, public procurement portals **do not
publish itemized supplier invoices**:

| Data type | Availability |
|:---|:---|
| Procurement notices and tender dossiers | Public |
| Winning supplier names and identifiers | Public (in most releases) |
| Authorized contract / award value | Public (in some releases) |
| Itemized supplier invoices | **Private commercial records** |
| Delivered quantities and unit prices | **Private commercial records** |
| Per-line VAT breakdowns | **Private commercial records** |

Invoices are submitted by vendors directly to municipal treasury departments
and are not part of any public procurement dataset. A tax-compliance audit
project that wants to model invoice-level checks therefore cannot draw its
invoice layer from open data, regardless of which procurement source it uses.

---

## 3. Engineering decision

Because the invoice layer is intrinsically private, and because the public
award/contract layer is not reliably present in the OCP registry snapshot,
the project adopts the following split:

| Layer | Source |
|:---|:---|
| Municipal authority names (`Komuna e Prishtinës`, `Komuna e Prizrenit`, `Komuna e Pejës`) | Authentic Kosovo administrative structures |
| Procurement numbering pattern (`SYNTH-616-…`) | Modelled after the visible KRPP reference format, prefixed with `SYNTH-` |
| VAT categories and rate schedule | Sourced from Law No. 05/L-037 (see section 4) |
| Suppliers, awards, invoices, line items, all financial values | **100% synthetic** |

All synthetic records are enforced at the database level by
`CHECK (is_synthetic = 1)` on the `vendors` table. No real company name,
fiscal number, or real financial value appears anywhere in the dataset.

The synthetic anomalies (duplicate invoices, arithmetic errors, VAT
misclassifications, award overruns, vendor mismatches) are deliberately
constructed to exercise the analytical queries. They do not represent any
actual behaviour by any Kosovo business.

---

## 4. VAT legal reference

The reduced-rate categories modelled by the project are based on Law
No. 05/L-037 on Value Added Tax:

- Official law text: <https://gzk.rks-gov.net/ActDetail.aspx?ActID=11015&langid=2>
- English text (with Annexes): <https://www.atk-ks.org/wp-content/uploads/2017/07/LAW_NO._05_L-037_ON_VALUE_ADDED_TAX___ANNEX.pdf>
- Tax Administration of Kosovo interactive guide: <https://crmm.atk-ks.org>

The MVP models only the 18% standard rate and the 8% reduced rate for a
defined set of categories (`IT_EQUIPMENT`, `PHARMACEUTICALS`,
`TEXTBOOKS_AND_BOOKS` at 8%; `OFFICE_FURNITURE`, `GENERAL_STATIONERY`,
`CIVIL_CONSTRUCTION`, `BUILDING_MAINTENANCE` at 18%).

Exempt supplies under Article 27 (including regulated public passenger
transport) and any special treatments outside these categories are **not
audited** by the MVP. This is a deliberate scope restriction, not a claim
about the full range of Kosovo VAT law.

---

## 5. Known limitations

- The public procurement data available at the time of writing does not
  include award or contract objects in its standard published form, so the
  project does not attempt to reconcile synthetic invoices against real
  awards.
- A single tendering portal (KRPP / OCP) was investigated. Commercial
  aggregators may expose additional Kosovo award records, but they are
  outside the scope of this project.
- The synthetic dataset (4 vendors, 4 awards, 24 invoices, 25 line items) is
  sized to demonstrate the query logic clearly, not to model municipal
  production volumes. Scaling is left as a documented future improvement.

---

## 6. Summary

The project is an **honest, fully reproducible demonstration** of municipal
invoice-audit SQL against a synthetic dataset, using authentic administrative
context and authentic legal VAT categories. It does not claim to audit real
Kosovo public procurement records, and it does not present synthetic
anomalies as evidence of real wrongdoing.