-- Core authentication and company schema.
-- All 9 enums are declared here (before any table that references them).
-- Folded in from later ALTERs:
--   V7:  client_companies.preferred_language
--   V11: client_companies.airport_buffer_minutes, airport_checkin_close_minutes
--   V8:  persons.avatar, persons.avatar_content_type
--   V12: persons.preferred_language
--   V15: client_companies.vat_id
--   V18: persons.must_change_password
-- Enum values folded from later ALTER TYPE ... ADD VALUE migrations (so no
-- non-transactional ADD VALUE migration is needed):
--   ride_status:    'Confirmed' (V12, after 'Assigned'), 'HandedOff' (V11, appended)
--   payment_method: 'Payment'   (V16, appended)
-- The driver_unavailability_reason enum (originally V10) lives here so that
-- V3__schedule_schema.sql can reference it without a forward dependency.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- Enums (all 9, in dependency order)
-- ============================================================
-- ride_status value order matches the historical ADD VALUE sequence:
--   'Confirmed' was inserted AFTER 'Assigned' (V12); 'HandedOff' was appended (V11).
CREATE TYPE ride_status AS ENUM ('Requested', 'Assigned', 'Confirmed', 'InProgress', 'Completed', 'Cancelled', 'HandedOff');
CREATE TYPE person_role AS ENUM ('driver', 'client', 'secretary', 'dispatcher', 'admin', 'client_secretary', 'super_admin');
CREATE TYPE driver_status AS ENUM ('Available', 'Busy', 'Offline');
CREATE TYPE schedule_day_status AS ENUM ('Scheduled', 'Active', 'Completed', 'Cancelled');
CREATE TYPE payment_status AS ENUM ('Unpaid', 'Pending', 'Paid');
-- 'Payment' was appended to payment_method (V16).
CREATE TYPE payment_method AS ENUM ('Cash', 'Card', 'Invoice', 'Bank', 'Receivable', 'Payment');
CREATE TYPE company_status AS ENUM ('Active', 'Suspended', 'Trial', 'Inactive');
CREATE TYPE subscription_plan AS ENUM ('Free', 'Starter', 'Professional', 'Enterprise');
CREATE TYPE driver_unavailability_reason AS ENUM ('Lunch', 'Vacation', 'Personal');

-- ============================================================
-- Companies
-- ============================================================
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    -- Lifecycle status and subscription plan, used by SuperAdmin platform management.
    status company_status NOT NULL DEFAULT 'Active',
    subscription_plan subscription_plan NOT NULL DEFAULT 'Free',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- Client companies
-- ============================================================
-- Folded in: V7 preferred_language, V11 airport_buffer_minutes + airport_checkin_close_minutes
CREATE TABLE client_companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    taxi_company_id UUID NOT NULL REFERENCES companies(id),
    -- V7: nullable; NULL maps to None in Scala and triggers the config default (EMAIL_DEFAULT_LANG, default "de").
    preferred_language VARCHAR(5),
    -- V11: NULL means "use global default from AirportPickupConfig".
    airport_buffer_minutes        INTEGER,
    airport_checkin_close_minutes INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- V15: appended last (matches the old ALTER chain's physical column order).
    -- VAT ID (USt-IdNr.) of the billed client company; shown on invoices.
    vat_id VARCHAR(50)
);

COMMENT ON COLUMN client_companies.vat_id IS 'VAT ID (USt-IdNr.) of the billed client company; shown on invoices.';

CREATE INDEX idx_client_companies_taxi_company ON client_companies(taxi_company_id);

-- ============================================================
-- Persons (single source of truth for all users)
-- ============================================================
-- `role` is the primary role; `roles` is the full set a person can act as
-- (e.g. a dispatcher who also drives). The invariant role = ANY(roles) is enforced
-- by the CHECK constraints below, and the persons_default_roles trigger backfills
-- roles = ARRAY[role] when a caller omits it.
-- Folded in: V8 avatar + avatar_content_type, V12 preferred_language
CREATE TABLE persons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role person_role NOT NULL,
    roles person_role[] NOT NULL DEFAULT '{}',
    company_id UUID REFERENCES companies(id),
    client_company_id UUID REFERENCES client_companies(id),
    password_hash VARCHAR(255) NOT NULL,
    license_number VARCHAR(50),
    phone VARCHAR(20),
    is_vip BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_driver_id UUID REFERENCES persons(id),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    last_login_at TIMESTAMP WITH TIME ZONE,
    -- How many minutes before the ride to send the driver a push reminder
    reminder_minutes INTEGER NOT NULL DEFAULT 60,
    -- V8: nullable; NULL means no photo has been uploaded.
    avatar BYTEA,
    avatar_content_type TEXT,
    -- V12: stores the user-selected UI language (en, de, uk); NULL means default/system locale.
    preferred_language VARCHAR(5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- V18: appended last (matches the old ALTER chain's physical column order).
    -- Users created by a dispatcher/admin get a temporary password and must change it on first login.
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_persons_email ON persons(email);
CREATE INDEX idx_persons_company_id ON persons(company_id);
CREATE INDEX idx_persons_role ON persons(role);
CREATE INDEX idx_persons_status ON persons(status);
CREATE INDEX idx_persons_client_company ON persons(client_company_id);
-- GIN index for efficient ANY(roles) lookups (e.g. "list drivers" = 'driver' = ANY(roles)).
CREATE INDEX idx_persons_roles ON persons USING GIN (roles);

-- ------------------------------------------------------------
-- persons.roles invariants + auto-population trigger
-- ------------------------------------------------------------
-- Auto-populate roles when the caller omits it (or leaves it empty). This lets
-- seed inserts and integration tests that do raw `INSERT INTO persons (..., role, ...)`
-- without a `roles` column continue to work: the BEFORE trigger fires before
-- NOT NULL / CHECK evaluation and sets roles = ARRAY[role]. When roles is already
-- provided and non-empty the trigger is a no-op.
CREATE OR REPLACE FUNCTION persons_default_roles()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.roles IS NULL OR cardinality(NEW.roles) = 0 THEN
        NEW.roles := ARRAY[NEW.role];
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER persons_default_roles
    BEFORE INSERT OR UPDATE ON persons
    FOR EACH ROW EXECUTE FUNCTION persons_default_roles();

-- Enforce invariants (the BEFORE trigger guarantees roles is non-empty and contains
-- the primary role before these checks are evaluated).
ALTER TABLE persons
    ADD CONSTRAINT persons_role_in_roles CHECK (role = ANY(roles));

ALTER TABLE persons
    ADD CONSTRAINT persons_roles_nonempty CHECK (cardinality(roles) >= 1);

-- ============================================================
-- Tokens
-- ============================================================
CREATE TABLE tokens (
    token VARCHAR(512) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_tokens_user_id ON tokens(user_id);

-- ============================================================
-- Sessions
-- ============================================================
CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES persons(id),
    token TEXT NOT NULL,
    device_info VARCHAR(255),
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_active ON sessions(user_id, is_active);

-- ============================================================
-- GDPR
-- ============================================================
CREATE TABLE gdpr_consents (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES persons(id),
    consent_type VARCHAR(50) NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45),
    UNIQUE(user_id, consent_type)
);

CREATE TABLE gdpr_requests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES persons(id),
    request_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

CREATE INDEX idx_gdpr_consents_user ON gdpr_consents(user_id);
CREATE INDEX idx_gdpr_requests_user ON gdpr_requests(user_id);
