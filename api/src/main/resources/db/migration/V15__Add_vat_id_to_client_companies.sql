-- Add VAT ID (USt-IdNr.) to client companies so it can be printed on invoices.
-- German B2B invoices must carry the recipient's VAT identification number.
ALTER TABLE client_companies ADD COLUMN vat_id VARCHAR(50);

COMMENT ON COLUMN client_companies.vat_id IS 'VAT ID (USt-IdNr.) of the billed client company; shown on invoices.';
