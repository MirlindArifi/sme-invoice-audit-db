# Modeling Strategy & Data Provenance

## 1. Ethical Boundary & Provenance Rules
- All transactional and entity records in this database are **explicitly synthetic**.
- No authentic registered business names or active fiscal numbers from Kosovo are used.
- Contextual administrative bodies (e.g., *Komuna e Prishtinës*) reflect realistic public administration entities, but all contracts, awards, invoices, and line items associated with them are simulated fixtures.

## 2. Identifier Conventions
| Entity | Field | Pattern / Example | Purpose |
| :--- | :--- | :--- | :--- |
| **Vendor** | `vendor_id` | Integer (Primary Key) | Internal relational key |
| **Vendor** | `fiscal_identifier` | `SYNTH-TAX-1001` | Synthetic business tax registration |
| **Vendor** | `vendor_name` | `[Name] SH.P.K. (Synthetic)` | Clear non-production label |
| **Procurement Award** | `procurement_number` | `SYNTH-616-23-001-521` | Modeled after KRPP tender codes |
| **Invoice** | `invoice_number` | `SYNTH-INV-2023-0101` | Supplier invoice reference |

## 3. Data Source Limitations
Authentic Kosovo public procurement data published under OCDS standards provides tender notices, but public portals do not publish private supplier invoice line items or detailed VAT breakdowns. This database uses modeled synthetic fixtures to demonstrate relational audit queries that would otherwise run on internal municipal financial records.
