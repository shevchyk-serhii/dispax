-- Create payment enums and migrate existing VARCHAR data

CREATE TYPE payment_status AS ENUM ('Unpaid', 'Pending', 'Paid');
CREATE TYPE payment_method AS ENUM ('Cash', 'Card', 'Invoice', 'Bank', 'Receivable');

-- Migrate existing data: normalize case before converting
UPDATE rides SET payment_status = 'Unpaid' WHERE payment_status = 'unpaid';
UPDATE rides SET payment_status = 'Paid' WHERE payment_status = 'paid';
UPDATE rides SET payment_status = 'Pending' WHERE payment_status = 'pending';

UPDATE rides SET payment_method = 'Cash' WHERE LOWER(payment_method) = 'cash';
UPDATE rides SET payment_method = 'Card' WHERE LOWER(payment_method) = 'card';
UPDATE rides SET payment_method = 'Invoice' WHERE LOWER(payment_method) = 'invoice';
UPDATE rides SET payment_method = 'Bank' WHERE LOWER(payment_method) = 'bank';
UPDATE rides SET payment_method = 'Receivable' WHERE LOWER(payment_method) = 'receivable';

-- Convert columns to enum types
ALTER TABLE rides
    ALTER COLUMN payment_status DROP DEFAULT,
    ALTER COLUMN payment_status TYPE payment_status USING payment_status::payment_status,
    ALTER COLUMN payment_status SET DEFAULT 'Unpaid';

ALTER TABLE rides
    ALTER COLUMN payment_method TYPE payment_method USING payment_method::payment_method;
