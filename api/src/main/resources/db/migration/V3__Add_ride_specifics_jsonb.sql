-- Migration: Add JSONB specifics column to replace airport-specific fields
-- This migration consolidates airport_code, flight_number, and is_airport_transfer
-- into a flexible JSONB column that can support multiple ride types

-- Step 1: Add the new specifics column
ALTER TABLE rides ADD COLUMN specifics JSONB;

-- Step 2: Migrate existing airport transfer data to JSONB
-- Only migrate rides where is_airport_transfer is true and data exists
UPDATE rides
SET specifics = jsonb_build_object(
    'type', 'AirportTransfer',
    'airportCode', airport_code,
    'flightNumber', flight_number
)
WHERE is_airport_transfer = TRUE
  AND airport_code IS NOT NULL
  AND flight_number IS NOT NULL;

-- Step 3: Drop the old index
DROP INDEX IF EXISTS idx_rides_is_airport_transfer;

-- Step 4: Drop the old columns
ALTER TABLE rides DROP COLUMN IF EXISTS airport_code;
ALTER TABLE rides DROP COLUMN IF EXISTS flight_number;
ALTER TABLE rides DROP COLUMN IF EXISTS is_airport_transfer;

-- Step 5: Create GIN index on specifics for efficient querying
-- GIN index allows querying inside JSONB structure
CREATE INDEX idx_rides_specifics ON rides USING gin(specifics);

-- Step 6: Create index on specifics type for filtering by ride type
CREATE INDEX idx_rides_specifics_type ON rides ((specifics->>'type'));
