-- Dispax Taxi Database Schema (consolidated)
--
-- This single migration is the entire production schema PLUS the seed accounts that
-- ship in every environment (the demo/quick-login accounts). It supersedes the old
-- V1..V5 chain (schema, seed accounts, airport config, schedule visibility, roles
-- array). Development-only data lives in db/migration-dev/V1001__Insert_dev_data.sql.
--
-- Object creation order matters: the persons_default_roles trigger and the
-- role/roles CHECK constraints must exist BEFORE any INSERT into persons, because
-- seed rows (and raw integration-test inserts) may omit the `roles` column and rely
-- on the trigger to populate it before NOT NULL / CHECK evaluation.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE ride_status AS ENUM ('Requested', 'Assigned', 'InProgress', 'Completed', 'Cancelled');
CREATE TYPE person_role AS ENUM ('driver', 'client', 'secretary', 'dispatcher', 'admin', 'client_secretary', 'super_admin');
CREATE TYPE driver_status AS ENUM ('Available', 'Busy', 'Offline');
CREATE TYPE schedule_day_status AS ENUM ('Scheduled', 'Active', 'Completed', 'Cancelled');
CREATE TYPE payment_status AS ENUM ('Unpaid', 'Pending', 'Paid');
CREATE TYPE payment_method AS ENUM ('Cash', 'Card', 'Invoice', 'Bank', 'Receivable');
CREATE TYPE company_status AS ENUM ('Active', 'Suspended', 'Trial', 'Inactive');
CREATE TYPE subscription_plan AS ENUM ('Free', 'Starter', 'Professional', 'Enterprise');

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
CREATE TABLE client_companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    taxi_company_id UUID NOT NULL REFERENCES companies(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_client_companies_taxi_company ON client_companies(taxi_company_id);

-- ============================================================
-- Persons (single source of truth for all users)
-- ============================================================
-- `role` is the primary role; `roles` is the full set a person can act as
-- (e.g. a dispatcher who also drives). The invariant role = ANY(roles) is enforced
-- by the CHECK constraints below, and the persons_default_roles trigger backfills
-- roles = ARRAY[role] when a caller omits it.
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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

-- ============================================================
-- Drivers
-- ============================================================
CREATE TABLE drivers (
    id UUID PRIMARY KEY REFERENCES persons(id),
    current_location_address VARCHAR(500),
    current_location_lat DOUBLE PRECISION,
    current_location_lng DOUBLE PRECISION,
    status driver_status NOT NULL DEFAULT 'Available',
    company_id UUID NOT NULL REFERENCES companies(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_company_id ON drivers(company_id);

-- ============================================================
-- Tariffs
-- ============================================================
CREATE TABLE tariffs (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    base_price_amount DECIMAL(10,2) NOT NULL,
    base_price_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    price_per_km_amount DECIMAL(10,2) NOT NULL,
    price_per_km_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    airport_surcharge_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    airport_surcharge_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    night_surcharge_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    night_surcharge_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- Schedule days
-- ============================================================
CREATE TABLE schedule_days (
    id UUID PRIMARY KEY,
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status schedule_day_status NOT NULL DEFAULT 'Scheduled',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_driver_date UNIQUE (driver_id, date)
);

CREATE INDEX idx_schedule_days_driver_id ON schedule_days(driver_id);
CREATE INDEX idx_schedule_days_company_id ON schedule_days(company_id);
CREATE INDEX idx_schedule_days_date ON schedule_days(date);
CREATE INDEX idx_schedule_days_status ON schedule_days(status);
CREATE INDEX idx_schedule_days_company_date ON schedule_days(company_id, date);

-- ============================================================
-- Ride pools
-- ============================================================
CREATE TABLE ride_pools (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL,
    name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    driver_id UUID,
    max_passengers INT NOT NULL DEFAULT 4,
    current_passengers INT NOT NULL DEFAULT 0,
    route_direction VARCHAR(200),
    scheduled_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL
);

CREATE INDEX idx_ride_pools_company ON ride_pools(company_id);
CREATE INDEX idx_ride_pools_status ON ride_pools(status);

-- ============================================================
-- Invoice sequences
-- ============================================================
CREATE TABLE invoice_sequences (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    last_number INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- Client companies invoices
-- ============================================================
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    number VARCHAR(50) NOT NULL,
    client_company_id UUID NOT NULL REFERENCES client_companies(id),
    taxi_company_id UUID NOT NULL REFERENCES companies(id),
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    period_from DATE NOT NULL,
    period_to DATE NOT NULL,
    subtotal_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    notes TEXT,
    due_date DATE,
    sent_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    -- When an overdue-payment reminder was sent, so the background scheduler
    -- emails each unpaid invoice at most once.
    reminder_sent_at TIMESTAMP WITH TIME ZONE,
    pdf_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (number, taxi_company_id)
);

CREATE INDEX idx_invoices_taxi_company ON invoices(taxi_company_id);
CREATE INDEX idx_invoices_client_company ON invoices(client_company_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_period ON invoices(period_from, period_to);

-- Supports the scheduler's candidate query (sent + unpaid + overdue + not yet reminded).
CREATE INDEX idx_invoices_overdue
    ON invoices (due_date)
    WHERE status = 'sent' AND paid_at IS NULL AND reminder_sent_at IS NULL;

-- ============================================================
-- Rides
-- ============================================================
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES persons(id),
    creator_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,

    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,

    pickup_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_time TIMESTAMP WITH TIME ZONE,
    request_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,

    status ride_status NOT NULL DEFAULT 'Requested',
    tariff_id UUID REFERENCES tariffs(company_id),
    estimated_price_amount DECIMAL(10,2),
    estimated_price_currency VARCHAR(3) DEFAULT 'EUR',
    final_price_amount DECIMAL(10,2),
    final_price_currency VARCHAR(3) DEFAULT 'EUR',
    price_amount DECIMAL(10,2),
    price_currency VARCHAR(3),
    estimated_distance_km DOUBLE PRECISION,

    flight_number VARCHAR(20),
    flight_time TIMESTAMP WITH TIME ZONE,
    flight_gate VARCHAR(10),
    flight_terminal VARCHAR(10),
    flight_status VARCHAR(50),
    flight_is_arrival BOOLEAN,
    -- Current airport checkpoint for arrival-transfer rides: landed | arrivals_hall | terminal_exit
    airport_checkpoint VARCHAR(30) DEFAULT NULL,
    specifics JSONB,

    schedule_day_id UUID REFERENCES schedule_days(id),

    notes TEXT,
    special_requirements TEXT,

    payment_status payment_status NOT NULL DEFAULT 'Unpaid',
    payment_method payment_method,
    paid_at TIMESTAMP WITH TIME ZONE,

    cancellation_reason VARCHAR(50),
    cancellation_fee DECIMAL(10,2) DEFAULT 0,
    cancelled_by UUID,

    is_vip_ride BOOLEAN DEFAULT FALSE,
    preferred_driver_used BOOLEAN DEFAULT FALSE,

    pool_id UUID REFERENCES ride_pools(id),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rides_client_id ON rides(client_id);
CREATE INDEX idx_rides_driver_id ON rides(driver_id);
CREATE INDEX idx_rides_company_id ON rides(company_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_pickup_datetime ON rides(pickup_datetime);
CREATE INDEX idx_rides_scheduled_time ON rides(scheduled_time);
CREATE INDEX idx_rides_request_time ON rides(request_time);
CREATE INDEX idx_rides_specifics ON rides USING gin(specifics);
CREATE INDEX idx_rides_specifics_type ON rides ((specifics->>'type'));
CREATE INDEX idx_rides_schedule_day_id ON rides(schedule_day_id);
CREATE INDEX idx_rides_invoice_id ON rides(invoice_id);

-- ============================================================
-- Sent reminders (deduplication of ride push reminders)
-- ============================================================
CREATE TABLE sent_reminders (
    ride_id   UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    person_id UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    sent_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, person_id)
);

-- ============================================================
-- Invoice items
-- ============================================================
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_ride ON invoice_items(ride_id);

-- ============================================================
-- Client locations
-- ============================================================
CREATE TABLE client_locations (
    ride_id UUID NOT NULL REFERENCES rides(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (ride_id)
);

CREATE INDEX idx_client_locations_client_id ON client_locations(client_id);

-- ============================================================
-- Chat messages
-- ============================================================
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES persons(id),
    message TEXT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_ride_id ON chat_messages(ride_id);
CREATE INDEX idx_chat_messages_sent_at ON chat_messages(sent_at);

-- ============================================================
-- Expenses
-- ============================================================
CREATE TABLE expenses (
    id UUID PRIMARY KEY,
    ride_id UUID REFERENCES rides(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    category VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    description TEXT,
    receipt_url TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expenses_ride_id ON expenses(ride_id);
CREATE INDEX idx_expenses_driver_id ON expenses(driver_id);
CREATE INDEX idx_expenses_company_id ON expenses(company_id);

-- ============================================================
-- Ride templates
-- ============================================================
CREATE TABLE ride_templates (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    creator_id UUID NOT NULL REFERENCES persons(id),
    name VARCHAR(255) NOT NULL,
    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,
    preferred_driver_id UUID REFERENCES persons(id),
    notes TEXT,
    recurrence_pattern VARCHAR(50) NOT NULL,
    recurrence_days VARCHAR(50),
    pickup_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT true,
    flight_number VARCHAR(20),
    is_airport_transfer BOOLEAN DEFAULT false,
    price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_ride_templates_company ON ride_templates(company_id);
CREATE INDEX idx_ride_templates_client ON ride_templates(client_id);

-- ============================================================
-- Notifications
-- ============================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY,
    person_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_notifications_person ON notifications(person_id);
CREATE INDEX idx_notifications_company ON notifications(company_id);
CREATE INDEX idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- Company settings
-- ============================================================
CREATE TABLE company_settings (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    commission_rate DECIMAL(5,2) DEFAULT 15.00,
    working_hours_start TIME DEFAULT '06:00',
    working_hours_end TIME DEFAULT '22:00',
    default_currency VARCHAR(3) DEFAULT 'EUR',
    cancellation_fee_default DECIMAL(10,2) DEFAULT 0,
    no_show_fee DECIMAL(10,2) DEFAULT 0,
    auto_assign_enabled BOOLEAN DEFAULT false,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- Audit log
-- ============================================================
CREATE TABLE audit_log (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id),
    actor_id UUID NOT NULL REFERENCES persons(id),
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    old_value TEXT,
    new_value TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_log_company ON audit_log(company_id);
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);

-- ============================================================
-- Ride ratings
-- ============================================================
CREATE TABLE ride_ratings (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_ride_ratings_ride ON ride_ratings(ride_id);
CREATE INDEX idx_ride_ratings_driver ON ride_ratings(driver_id);

-- ============================================================
-- Geofences
-- ============================================================
CREATE TABLE geofences (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id),
    name VARCHAR(255) NOT NULL,
    geofence_type VARCHAR(50) NOT NULL,
    center_latitude DOUBLE PRECISION NOT NULL,
    center_longitude DOUBLE PRECISION NOT NULL,
    radius_meters INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    notify_on_entry BOOLEAN DEFAULT true,
    notify_on_exit BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_geofences_company ON geofences(company_id);
CREATE INDEX idx_geofences_active ON geofences(is_active);

CREATE TABLE geofence_alerts (
    id UUID PRIMARY KEY,
    geofence_id UUID NOT NULL REFERENCES geofences(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    alert_type VARCHAR(10) NOT NULL,
    geofence_name VARCHAR(255) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_geofence_alerts_driver ON geofence_alerts(driver_id);
CREATE INDEX idx_geofence_alerts_company ON geofence_alerts(company_id);
CREATE INDEX idx_geofence_alerts_created ON geofence_alerts(created_at DESC);

-- ============================================================
-- Blacklist
-- ============================================================
CREATE TABLE blacklist_entries (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    reason TEXT,
    created_by UUID NOT NULL REFERENCES persons(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(client_id, driver_id)
);

CREATE INDEX idx_blacklist_company ON blacklist_entries(company_id);
CREATE INDEX idx_blacklist_client ON blacklist_entries(client_id);
CREATE INDEX idx_blacklist_driver ON blacklist_entries(driver_id);

-- ============================================================
-- Emergency reassignments
-- ============================================================
CREATE TABLE emergency_reassignments (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    original_driver_id UUID NOT NULL REFERENCES persons(id),
    new_driver_id UUID REFERENCES persons(id),
    reason VARCHAR(50) NOT NULL,
    notes TEXT,
    reassigned_by UUID NOT NULL REFERENCES persons(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
);

CREATE INDEX idx_emergency_reassign_ride ON emergency_reassignments(ride_id);
CREATE INDEX idx_emergency_reassign_company ON emergency_reassignments(company_id);

-- ============================================================
-- Ride pool members
-- ============================================================
CREATE TABLE ride_pool_members (
    id UUID PRIMARY KEY,
    pool_id UUID NOT NULL REFERENCES ride_pools(id),
    ride_id UUID NOT NULL,
    client_id UUID NOT NULL,
    pickup_order INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ride_pool_members_pool ON ride_pool_members(pool_id);
CREATE INDEX idx_ride_pool_members_ride ON ride_pool_members(ride_id);

-- ============================================================
-- Notification preferences
-- ============================================================
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY,
    person_id UUID NOT NULL UNIQUE,
    ride_updates BOOLEAN NOT NULL DEFAULT TRUE,
    chat_messages BOOLEAN NOT NULL DEFAULT TRUE,
    driver_approaching BOOLEAN NOT NULL DEFAULT TRUE,
    geofence_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    pool_updates BOOLEAN NOT NULL DEFAULT TRUE,
    email_notifications BOOLEAN NOT NULL DEFAULT FALSE,
    sms_notifications BOOLEAN NOT NULL DEFAULT FALSE,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_prefs_person ON notification_preferences(person_id);

-- ============================================================
-- FCM tokens
-- ============================================================
CREATE TABLE fcm_tokens (
    person_id UUID NOT NULL REFERENCES persons(id),
    token TEXT NOT NULL UNIQUE,
    platform VARCHAR(20) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fcm_tokens_person ON fcm_tokens(person_id);

-- ============================================================
-- Client addresses
-- ============================================================
CREATE TABLE client_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    label VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    use_count INTEGER NOT NULL DEFAULT 1,
    aliases TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_client_addresses_client_id ON client_addresses(client_id);

-- ============================================================
-- Company billing profile
-- ============================================================
-- Billing profile per taxi company: legally required issuer details for invoices
-- (Rechnung): full address, tax IDs, bank/IBAN, payment terms and signature.
-- These are static-per-company fields rendered into the invoice PDF, kept separate
-- from `companies` (operational) and `company_settings` (dispatch settings).
CREATE TABLE company_billing_profile (
    company_id         UUID PRIMARY KEY REFERENCES companies(id) ON DELETE CASCADE,
    business_type      VARCHAR(255),         -- e.g. "Mietwagenunternehmen / Transfer<>Service"
    legal_name         VARCHAR(255),         -- issuer / signatory name
    address_line1      VARCHAR(255),
    address_line2      VARCHAR(255),
    phone              VARCHAR(50),
    email              VARCHAR(255),
    tax_number         VARCHAR(50),          -- St-Nr.
    vat_id             VARCHAR(50),          -- USt-IdNr.
    bank_name          VARCHAR(255),
    bank_account_no    VARCHAR(50),          -- Konto-Nr.
    bank_code          VARCHAR(50),          -- BLZ
    iban               VARCHAR(50),
    bic                VARCHAR(50),
    payment_terms_days INTEGER NOT NULL DEFAULT 7,
    invoice_intro      TEXT,                 -- preamble printed under "Kostenrechnung"
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- ETA-at-risk alert deduplication (predictive ETA monitor)
-- ============================================================
-- One row per (ride, driver) once a delay-risk alert has been sent, so the
-- background monitor does not re-alert the dispatcher every tick. Mirrors
-- sent_reminders. Cleared when the ride's pickup time changes.
CREATE TABLE eta_alerts (
    ride_id    UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    driver_id  UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    alerted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, driver_id)
);

-- ============================================================
-- Airport checkpoint push notification deduplication
-- ============================================================
CREATE TABLE sent_checkpoint_notifications (
    ride_id         UUID         NOT NULL REFERENCES rides(id)   ON DELETE CASCADE,
    driver_id       UUID         NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    checkpoint_type VARCHAR(50)  NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, driver_id, checkpoint_type)
);

CREATE INDEX idx_sent_checkpoint_ride ON sent_checkpoint_notifications(ride_id);

-- ============================================================
-- Airport configuration (global, no company_id)
-- ============================================================
-- These tables are intentionally cross-tenant — access is gated by the SuperAdmin role check
-- in the HTTP layer, not by a company_id column. See SuperAdminAirportApi.scala.
CREATE TABLE airports (
    code           VARCHAR(10)       PRIMARY KEY,   -- e.g. "MUC"
    name           VARCHAR(255)      NOT NULL,
    country        VARCHAR(100)      NOT NULL DEFAULT 'DE',
    -- Landing geofence (coarse; used for automatic "Landed" trigger)
    landing_lat    DOUBLE PRECISION  NOT NULL,
    landing_lon    DOUBLE PRECISION  NOT NULL,
    landing_radius INT               NOT NULL,
    is_active      BOOLEAN           NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE TABLE airport_checkpoint_zones (
    id              UUID              PRIMARY KEY DEFAULT uuid_generate_v4(),
    airport_code    VARCHAR(10)       NOT NULL REFERENCES airports(code) ON DELETE CASCADE,
    terminal_code   VARCHAR(20)       NOT NULL,            -- "T1", "T2", "T2-PRIORITY"
    checkpoint_type VARCHAR(30)       NOT NULL,            -- "landed" | "arrivals_hall" | "terminal_exit"
    display_name    VARCHAR(255)      NOT NULL,            -- "T1 Arrivals Hall"
    lat             DOUBLE PRECISION  NOT NULL,
    lon             DOUBLE PRECISION  NOT NULL,
    radius_meters   INT               NOT NULL,
    sort_order      INT               NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_acz_airport_code ON airport_checkpoint_zones(airport_code);
CREATE INDEX idx_acz_terminal     ON airport_checkpoint_zones(airport_code, terminal_code);

-- Seed MUC: values match MucCheckpoints.scala so runtime behaviour is unchanged on day one.
-- The "Landed" checkpoint type is modelled at the airport level (the landing_* columns), not as
-- a row in airport_checkpoint_zones, because it is a single perimeter shared across all terminals.
INSERT INTO airports (code, name, country, landing_lat, landing_lon, landing_radius)
VALUES ('MUC', 'München Franz Josef Strauß', 'DE', 48.3537, 11.7860, 2000);

INSERT INTO airport_checkpoint_zones
    (airport_code, terminal_code, checkpoint_type, display_name, lat, lon, radius_meters, sort_order)
VALUES
    ('MUC', 'T1',          'arrivals_hall', 'T1 Arrivals Hall',  48.3526, 11.7798, 200, 1),
    ('MUC', 'T1',          'terminal_exit', 'T1 Exit',           48.3515, 11.7793, 150, 2),
    ('MUC', 'T2',          'arrivals_hall', 'T2 Arrivals Hall',  48.3549, 11.7853, 200, 1),
    ('MUC', 'T2',          'terminal_exit', 'T2 Exit',           48.3540, 11.7870, 150, 2),
    ('MUC', 'T2-PRIORITY', 'arrivals_hall', 'T2 Arrivals Hall',  48.3549, 11.7853, 200, 1),
    ('MUC', 'T2-PRIORITY', 'terminal_exit', 'T2 Priority Exit',  48.3543, 11.7867, 150, 2);

-- ============================================================
-- Driver schedule visibility
-- ============================================================
CREATE TABLE driver_schedule_visibility (
    driver_id   UUID PRIMARY KEY REFERENCES persons(id),
    company_id  UUID NOT NULL REFERENCES companies(id),
    can_view_other_schedules BOOLEAN NOT NULL DEFAULT false,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_dsv_company_id ON driver_schedule_visibility(company_id);

-- ============================================================
-- Seed accounts available in ALL environments (including production).
-- These are the demo/test accounts used by the app's quick-login buttons.
-- Idempotent: fixed UUIDs + ON CONFLICT DO NOTHING make re-runs safe.
-- Password for all accounts: password123
-- BCrypt hash: $2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S
-- ============================================================

-- Test company
INSERT INTO companies (id, name, email, phone, address)
VALUES ('10101010-1010-1010-1010-101010101010', 'Dispax München', 'info@dispax-muenchen.de', '+49 89 12345678', 'Leopoldstraße 1, 80802 München')
ON CONFLICT (id) DO NOTHING;

-- Tariff for test company
INSERT INTO tariffs (company_id, base_price_amount, base_price_currency, price_per_km_amount, price_per_km_currency, airport_surcharge_amount, airport_surcharge_currency, night_surcharge_amount, night_surcharge_currency)
VALUES ('10101010-1010-1010-1010-101010101010', 5.00, 'EUR', 2.50, 'EUR', 10.00, 'EUR', 5.00, 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Company settings
INSERT INTO company_settings (company_id, commission_rate, working_hours_start, working_hours_end, default_currency)
VALUES ('10101010-1010-1010-1010-101010101010', 15.00, '06:00', '22:00', 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Dispatcher (owner) — also a driver so dispatcher@dispax.de can be assigned to rides
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('11111111-1111-1111-1111-111111111111', 'Max Müller', 'dispatcher@dispax.de', 'dispatcher',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 1111111', 'ACTIVE', ARRAY['dispatcher','driver']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Driver row for the dispatcher-driver so they appear in location/status queries
INSERT INTO drivers (id, status, company_id)
VALUES ('11111111-1111-1111-1111-111111111111', 'Available', '10101010-1010-1010-1010-101010101010')
ON CONFLICT (id) DO NOTHING;

-- Secretary
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('22222222-2222-2222-2222-222222222222', 'Anna Schmidt', 'secretary@dispax.de', 'secretary',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 2222222', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Driver 1
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status)
VALUES ('33333333-3333-3333-3333-333333333333', 'Hans Weber', 'driver1@dispax.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 3333333', 'MÜN-HW-001', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('33333333-3333-3333-3333-333333333333', 'Available', '10101010-1010-1010-1010-101010101010',
        'Marienplatz, München', 48.1374, 11.5755)
ON CONFLICT (id) DO NOTHING;

-- Driver 2
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status)
VALUES ('44444444-4444-4444-4444-444444444444', 'Klaus Fischer', 'driver2@dispax.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 4444444', 'MÜN-KF-002', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('44444444-4444-4444-4444-444444444444', 'Available', '10101010-1010-1010-1010-101010101010',
        'Hauptbahnhof, München', 48.1403, 11.5600)
ON CONFLICT (id) DO NOTHING;

-- Driver 3
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status)
VALUES ('55555555-5555-5555-5555-555555555555', 'Peter Braun', 'driver3@dispax.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 5555555', 'MÜN-PB-003', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('55555555-5555-5555-5555-555555555555', 'Available', '10101010-1010-1010-1010-101010101010',
        'Flughafen München', 48.3537, 11.7750)
ON CONFLICT (id) DO NOTHING;

-- Client 1 (VIP, corporate)
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, is_vip, preferred_driver_id, status)
VALUES ('66666666-6666-6666-6666-666666666666', 'BMW AG - Herr Schneider', 'client1@bmw.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999001', true, '33333333-3333-3333-3333-333333333333', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Client 2
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('77777777-7777-7777-7777-777777777777', 'Siemens - Frau Meier', 'client2@siemens.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999002', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Client 3
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('88888888-8888-8888-8888-888888888888', 'Allianz - Herr Klein', 'client3@allianz.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999003', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Admin
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('99999999-9999-9999-9999-999999999999', 'Admin', 'admin@dispax.de', 'admin',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 9999999', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Client addresses: BMW AG - Herr Schneider
INSERT INTO client_addresses (id, client_id, label, address, latitude, longitude, use_count, aliases)
VALUES
  (gen_random_uuid(), '66666666-6666-6666-6666-666666666666', 'Zuhause', 'Maximilianstraße 10, 80539 München', 48.1396, 11.5817, 20, '{"Home", "Zuhause"}'),
  (gen_random_uuid(), '66666666-6666-6666-6666-666666666666', 'BMW Werk München', 'Petuelring 130, 80788 München', 48.1770, 11.5565, 5, '{}'),
  (gen_random_uuid(), '66666666-6666-6666-6666-666666666666', 'Flughafen München', 'Flughafen München Terminal 2, 85356 München', 48.3537, 11.7750, 8, '{"MUC", "Airport"}')
ON CONFLICT DO NOTHING;

-- Client addresses: Siemens - Frau Meier
INSERT INTO client_addresses (id, client_id, label, address, latitude, longitude, use_count, aliases)
VALUES
  (gen_random_uuid(), '77777777-7777-7777-7777-777777777777', 'Zuhause', 'Leopoldstraße 42, 80802 München', 48.1573, 11.5828, 20, '{"Home", "Zuhause"}'),
  (gen_random_uuid(), '77777777-7777-7777-7777-777777777777', 'Büro Siemens', 'Werner-von-Siemens-Straße 1, 80333 München', 48.1466, 11.5635, 12, '{"Siemens HQ"}'),
  (gen_random_uuid(), '77777777-7777-7777-7777-777777777777', 'Dropoff', 'Flughafen München Terminal 2, 85356 München', 48.3537, 11.7750, 4, '{"MUC"}')
ON CONFLICT DO NOTHING;

-- Client addresses: Allianz - Herr Klein
INSERT INTO client_addresses (id, client_id, label, address, latitude, longitude, use_count, aliases)
VALUES
  (gen_random_uuid(), '88888888-8888-8888-8888-888888888888', 'Zuhause', 'Hohenzollernstraße 25, 80801 München', 48.1654, 11.5780, 20, '{"Home", "Zuhause"}'),
  (gen_random_uuid(), '88888888-8888-8888-8888-888888888888', 'Allianz Arena', 'Allianz Arena, Werner-Heisenberg-Allee 25, 80939 München', 48.2188, 11.6248, 7, '{"Allianz HQ"}'),
  (gen_random_uuid(), '88888888-8888-8888-8888-888888888888', 'Flughafen München', 'Flughafen München Terminal 1, 85356 München', 48.3537, 11.7750, 9, '{"MUC", "Airport"}')
ON CONFLICT DO NOTHING;

-- Driver schedules (today + next 2 days) so dispatchers can assign rides.
-- Round-the-clock 00:00–23:59 window covers any pickup time.
-- Dates are relative (CURRENT_DATE) so the seed never goes stale.
INSERT INTO schedule_days (id, driver_id, company_id, date, start_time, end_time, status)
SELECT
  gen_random_uuid(),
  d.driver_id,
  '10101010-1010-1010-1010-101010101010',
  CURRENT_DATE + offset_days,
  '00:00'::time,
  '23:59'::time,
  'Scheduled'
FROM (VALUES
  ('33333333-3333-3333-3333-333333333333'::uuid),
  ('44444444-4444-4444-4444-444444444444'::uuid),
  ('55555555-5555-5555-5555-555555555555'::uuid)
) AS d(driver_id)
CROSS JOIN (VALUES (0), (1), (2)) AS days(offset_days)
ON CONFLICT (driver_id, date) DO NOTHING;

-- Billing profile for the demo company (Dispax München), rendered into invoice PDFs.
INSERT INTO company_billing_profile
    (company_id, business_type, legal_name, address_line1, address_line2,
     phone, email, tax_number, vat_id,
     bank_name, bank_account_no, bank_code, iban, bic, payment_terms_days, invoice_intro)
VALUES
    ('10101010-1010-1010-1010-101010101010',
     'Mietwagenunternehmen / Transfer<>Service',
     'Dispax München',
     'Leopoldstraße 1',
     '80802 München',
     '+49 89 12345678',
     'info@dispax-muenchen.de',
     '146/116/61550',
     'DE123456789',
     'Deutsche Bank',
     '3939543',
     '70070024',
     'DE24 7007 0024 0393 9543 00',
     'DEUTDEDBMUC',
     7,
     'Ich gestatte mir, die Auftragsfahrtkosten wie folgt in Rechnung zu stellen.')
ON CONFLICT (company_id) DO NOTHING;
