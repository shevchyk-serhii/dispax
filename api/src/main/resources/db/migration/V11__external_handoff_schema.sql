-- V11: External hand-off support
-- Adds HandedOff status, partner_companies and external_drivers tables, and FK columns on rides.
--
-- IMPORTANT: `ALTER TYPE ... ADD VALUE` is allowed inside a transaction on PostgreSQL 12+,
-- *provided the new value is NOT used in any DML within the same transaction*. This migration
-- never references 'HandedOff' in INSERT/UPDATE/DEFAULT clauses, so it is safe with community
-- Flyway (no executeInTransaction=false required).

-- 1. Extend the ride_status enum
ALTER TYPE ride_status ADD VALUE IF NOT EXISTS 'HandedOff';

-- 2. Partner companies: external transport firms to which rides may be handed off
CREATE TABLE partner_companies (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             VARCHAR(255) NOT NULL,
    email            VARCHAR(255),
    phone            VARCHAR(20),
    address          TEXT,
    taxi_company_id  UUID NOT NULL REFERENCES companies(id),
    created_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at       TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_partner_companies_taxi_company ON partner_companies(taxi_company_id);

-- 3. External drivers: individual drivers employed by (or freelancing for) partner companies
CREATE TABLE external_drivers (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                VARCHAR(255) NOT NULL,
    phone               VARCHAR(20),
    partner_company_id  UUID REFERENCES partner_companies(id) ON DELETE SET NULL,
    taxi_company_id     UUID NOT NULL REFERENCES companies(id),
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_external_drivers_taxi_company ON external_drivers(taxi_company_id);
CREATE INDEX idx_external_drivers_partner ON external_drivers(partner_company_id);

-- 4. New FK columns on rides table
ALTER TABLE rides
    ADD COLUMN external_driver_id  UUID REFERENCES external_drivers(id) ON DELETE SET NULL,
    ADD COLUMN partner_company_id  UUID REFERENCES partner_companies(id) ON DELETE SET NULL;
