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

-- Seed billing profile for the demo company (Dispax München).
INSERT INTO company_billing_profile
    (company_id, business_type, legal_name, address_line1, address_line2,
     phone, email, tax_number, vat_id,
     bank_name, bank_account_no, bank_code, iban, bic, payment_terms_days, invoice_intro)
VALUES
    ('10101010-1010-1010-1010-101010101010',
     'Mietwagenunternehmen / Transfer<>Service',
     'Dispax München',
     'Leopoldstraße 1',
     '80802 München',
     '+49 89 12345678',
     'info@dispax-muenchen.de',
     '146/116/61550',
     'DE123456789',
     'Deutsche Bank',
     '3939543',
     '70070024',
     'DE24 7007 0024 0393 9543 00',
     'DEUTDEDBMUC',
     7,
     'Ich gestatte mir, die Auftragsfahrtkosten wie folgt in Rechnung zu stellen.')
ON CONFLICT (company_id) DO NOTHING;
