-- Fix paid_at column type to match other timestamp columns
-- TIMESTAMP (without tz) causes doobie OffsetDateTime mapping to fail
ALTER TABLE rides ALTER COLUMN paid_at TYPE TIMESTAMP WITH TIME ZONE;
