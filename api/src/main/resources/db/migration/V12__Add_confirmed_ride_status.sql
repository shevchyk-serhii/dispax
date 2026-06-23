-- Add 'Confirmed' to the ride_status enum.
-- This must run outside a transaction (see the .conf sidecar) because PostgreSQL
-- does not allow new enum values to be used in the same transaction where they
-- are added. V11 adds the columns that use this value.
ALTER TYPE ride_status ADD VALUE IF NOT EXISTS 'Confirmed' AFTER 'Assigned';
