-- ============================================================================
-- SME Invoice Audit DB — Relational Schema Definition
-- Context: Municipal Procurement & Tax Compliance Auditor (Kosovo)
-- Engine:  SQLite 3
-- ============================================================================

-- Enforce foreign key constraints for the current connection.
-- In SQLite, this must be executed by every new connection.
PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. Table: vendors
-- Independent parent table storing supplier business entities.
-- ----------------------------------------------------------------------------
CREATE TABLE vendors (
    vendor_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    fiscal_identifier   TEXT NOT NULL UNIQUE,
    vendor_name         TEXT NOT NULL,
    vendor_type         TEXT NOT NULL,
    -- Enforce that this database strictly contains synthetic test entities.
    is_synthetic        INTEGER NOT NULL DEFAULT 1 CHECK (is_synthetic = 1)
);

-- ----------------------------------------------------------------------------
-- 2. Table: procurement_awards
-- Municipal contracts establishing the legal expenditure ceiling.
-- ----------------------------------------------------------------------------
CREATE TABLE procurement_awards (
    award_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    procurement_number   TEXT NOT NULL UNIQUE,
    authority_name       TEXT NOT NULL,
    vendor_id            INTEGER NOT NULL,
    award_date           TEXT NOT NULL,
    recorded_award_value NUMERIC NOT NULL CHECK (recorded_award_value > 0),
    procurement_category TEXT NOT NULL,
    CONSTRAINT fk_awards_vendor
        FOREIGN KEY (vendor_id) REFERENCES vendors (vendor_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 3. Table: invoices
-- Supplier invoices submitted against procurement awards.
-- NOTE: invoice_number is intentionally NOT constrained as UNIQUE to permit
-- ingesting duplicate billing submissions for detection by Audit Query 1.
-- ----------------------------------------------------------------------------
CREATE TABLE invoices (
    invoice_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number      TEXT NOT NULL,
    award_id            INTEGER NOT NULL,
    billing_vendor_id   INTEGER NOT NULL,
    invoice_date        TEXT NOT NULL,
    recorded_total      NUMERIC NOT NULL CHECK (recorded_total >= 0),
    CONSTRAINT fk_invoices_award
        FOREIGN KEY (award_id) REFERENCES procurement_awards (award_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_invoices_billing_vendor
        FOREIGN KEY (billing_vendor_id) REFERENCES vendors (vendor_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- 4. Table: invoice_line_items
-- Itemized goods and services billed under a parent invoice.
-- NOTE: vat_rate permits 0-100% to allow loading non-compliant rates (0%, 5%, 20%)
-- so that Audit Query 3 can inspect and flag them.
-- ----------------------------------------------------------------------------
CREATE TABLE invoice_line_items (
    line_item_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id          INTEGER NOT NULL,
    item_category       TEXT NOT NULL,
    description         TEXT NOT NULL,
    quantity            NUMERIC NOT NULL CHECK (quantity > 0),
    unit_price          NUMERIC NOT NULL CHECK (unit_price >= 0),
    line_subtotal       NUMERIC NOT NULL CHECK (line_subtotal >= 0),
    vat_rate            NUMERIC NOT NULL CHECK (vat_rate >= 0 AND vat_rate <= 100),
    vat_amount          NUMERIC NOT NULL CHECK (vat_amount >= 0),
    line_total          NUMERIC NOT NULL CHECK (line_total >= 0),
    CONSTRAINT fk_line_items_invoice
        FOREIGN KEY (invoice_id) REFERENCES invoices (invoice_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ----------------------------------------------------------------------------
-- Indexes for Analytical Query Optimization
-- In SQLite, primary keys and UNIQUE columns are indexed automatically.
-- We index foreign keys frequently joined, grouped, or filtered in Queries 2–5.
-- ----------------------------------------------------------------------------

-- Optimizes Query 4: Aggregating invoice totals by procurement award ceiling.
CREATE INDEX idx_invoices_award_id ON invoices (award_id);

-- Optimizes Query 5: Filtering and aggregating exception rollups by billing vendor.
CREATE INDEX idx_invoices_billing_vendor ON invoices (billing_vendor_id);

-- Optimizes Queries 2 & 3: Joining line items back to their parent invoice.
CREATE INDEX idx_line_items_invoice_id ON invoice_line_items (invoice_id);