-- Billing and dispatch settings schema.
-- Depends on V1 (companies), V4 (rides via invoices FK path is already in V4).
-- Folded in from later ALTERs:
--   V6:  company_settings.datev_beraternummer, datev_mandantennummer, datev_sachkontenlaenge
--   V11: company_settings.airport_buffer_minutes, airport_checkin_close_minutes

-- ============================================================
-- Company settings
-- ============================================================
-- Folded in: V6 DATEV columns, V11 airport timing columns
CREATE TABLE company_settings (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    commission_rate DECIMAL(5,2) DEFAULT 15.00,
    working_hours_start TIME DEFAULT '06:00',
    working_hours_end TIME DEFAULT '22:00',
    default_currency VARCHAR(3) DEFAULT 'EUR',
    cancellation_fee_default DECIMAL(10,2) DEFAULT 0,
    no_show_fee DECIMAL(10,2) DEFAULT 0,
    auto_assign_enabled BOOLEAN DEFAULT false,
    -- V6: DATEV-specific settings for the company: Steuerberater number, Mandant number,
    -- and the Sachkontenlaenge (chart-of-accounts length). All three are optional.
    -- When Sachkontenlänge is NULL the application defaults to 4.
    datev_beraternummer    VARCHAR(7),
    datev_mandantennummer  VARCHAR(5),
    datev_sachkontenlaenge SMALLINT,
    -- V11: NULL means "use global default from AirportPickupConfig".
    airport_buffer_minutes        INTEGER,
    airport_checkin_close_minutes INTEGER,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- Company billing profile
-- ============================================================
-- Billing profile per taxi company: legally required issuer details for invoices
-- (Rechnung): full address, tax IDs, bank/IBAN, payment terms and signature.
-- These are static-per-company fields rendered into the invoice PDF, kept separate
-- from `companies` (operational) and `company_settings` (dispatch settings).
CREATE TABLE company_billing_profile (
    company_id         UUID PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
    business_type      VARCHAR(255),         -- e.g. "Mietwagenunternehmen / Transfer<>Service"
    legal_name         VARCHAR(255),         -- issuer / signatory name
    address_line1      VARCHAR(255),
    address_line2      VARCHAR(255),
    phone              VARCHAR(50),
    email              VARCHAR(255),
    tax_number         VARCHAR(50),          -- St-Nr.
    vat_id             VARCHAR(50),          -- USt-IdNr.
    bank_name          VARCHAR(255),
    bank_account_no    VARCHAR(50),          -- Konto-Nr.
    bank_code          VARCHAR(50),          -- BLZ
    iban               VARCHAR(50),
    bic                VARCHAR(50),
    payment_terms_days INTEGER NOT NULL DEFAULT 7,
    invoice_intro      TEXT,                 -- preamble printed under "Kostenrechnung"
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
