-- Add the 'Payment' value to the payment_method enum.
-- NOTE: ALTER TYPE ... ADD VALUE cannot run inside a transaction block in PostgreSQL,
-- so this migration must stay in its own file (only this statement), like the ride_status
-- additions in V11/V12. The new value cannot be used in the same transaction that adds it.
ALTER TYPE payment_method ADD VALUE IF NOT EXISTS 'Payment';
