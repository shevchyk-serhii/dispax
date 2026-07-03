-- Per-company counter for human-readable ride booking references (mirrors invoice_sequences).
CREATE TABLE booking_reference_sequences (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    last_number INTEGER NOT NULL DEFAULT 0
);

-- Human-readable, client-facing reference (e.g. 'R-2026-00123'). Allocated at creation;
-- NULL only for legacy rows (pre-V14). The internal ride id (UUID) stays the identifier everywhere.
ALTER TABLE rides ADD COLUMN booking_reference VARCHAR(20);

-- Unique per company (references from different companies may collide by design).
CREATE UNIQUE INDEX uq_rides_company_booking_reference
    ON rides (company_id, booking_reference)
    WHERE booking_reference IS NOT NULL;
