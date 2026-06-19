-- V9: Add vehicle_class to rides for the new client booking flow.
-- Nullable + default 'business': legacy rows and rows created without an
-- explicit class read back as Business (see VehicleClass.Default in the domain).
-- Stored as a plain string (not a PG enum) to match how AirportCheckpoint is
-- persisted and to avoid an enum-alter migration when classes change.

ALTER TABLE rides
    ADD COLUMN IF NOT EXISTS vehicle_class VARCHAR(20) NOT NULL DEFAULT 'business';
