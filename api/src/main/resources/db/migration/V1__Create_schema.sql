-- Oktopus Taxi Database Schema (consolidated)
-- All tables in final state

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE ride_status AS ENUM ('Requested', 'Assigned', 'InProgress', 'Completed', 'Cancelled');
CREATE TYPE person_role AS ENUM ('driver', 'client', 'secretary', 'dispatcher');
CREATE TYPE driver_status AS ENUM ('Available', 'Busy', 'Offline');
CREATE TYPE schedule_day_status AS ENUM ('Scheduled', 'Active', 'Completed', 'Cancelled');

-- ============================================================
-- Companies
-- ============================================================
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================
-- Persons
-- ============================================================
CREATE TABLE persons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role person_role NOT NULL,
    company_id UUID REFERENCES companies(id),
    password_hash VARCHAR(255),
    license_number VARCHAR(50),
    phone VARCHAR(20),
    is_vip BOOLEAN NOT NULL DEFAULT FALSE,
    preferred_driver_id UUID REFERENCES persons(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_persons_email ON persons(email);
CREATE INDEX idx_persons_company_id ON persons(company_id);
CREATE INDEX idx_persons_role ON persons(role);

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
-- Users (authentication)
-- ============================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('CLIENT', 'DRIVER', 'DISPATCHER', 'SECRETARY', 'ADMIN')),
    password_hash VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    company_id UUID REFERENCES companies(id),
    last_login_at TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);

-- ============================================================
-- Tokens
-- ============================================================
CREATE TABLE tokens (
    token VARCHAR(512) PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_tokens_user_id ON tokens(user_id);

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
-- Rides
-- ============================================================
CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID NOT NULL REFERENCES persons(id),
    creator_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),

    -- Location
    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,

    -- Time
    pickup_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_time TIMESTAMP WITH TIME ZONE,
    request_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,

    -- Status and pricing
    status ride_status NOT NULL DEFAULT 'Requested',
    tariff_id UUID REFERENCES tariffs(company_id),
    estimated_price_amount DECIMAL(10,2),
    estimated_price_currency VARCHAR(3) DEFAULT 'EUR',
    final_price_amount DECIMAL(10,2),
    final_price_currency VARCHAR(3) DEFAULT 'EUR',
    price_amount DECIMAL(10,2),
    price_currency VARCHAR(3),
    estimated_distance_km DOUBLE PRECISION,

    -- Flight information
    flight_number VARCHAR(20),
    flight_time TIMESTAMP WITH TIME ZONE,
    flight_gate VARCHAR(10),
    flight_terminal VARCHAR(10),
    flight_status VARCHAR(50),
    flight_is_arrival BOOLEAN,

    -- JSONB specifics (ride type details, e.g. airport transfer)
    specifics JSONB,

    -- Schedule
    schedule_day_id UUID REFERENCES schedule_days(id),

    -- Additional
    notes TEXT,
    special_requirements TEXT,

    -- Payment
    payment_status VARCHAR(20) DEFAULT 'unpaid',
    payment_method VARCHAR(20),
    paid_at TIMESTAMP,

    -- Cancellation
    cancellation_reason VARCHAR(50),
    cancellation_fee DECIMAL(10,2) DEFAULT 0,
    cancelled_by UUID,

    -- VIP / preferred driver
    is_vip_ride BOOLEAN DEFAULT FALSE,
    preferred_driver_used BOOLEAN DEFAULT FALSE,

    -- Pool
    pool_id UUID REFERENCES ride_pools(id),

    -- Audit
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
-- GDPR
-- ============================================================
CREATE TABLE gdpr_consents (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    consent_type VARCHAR(50) NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45),
    UNIQUE(user_id, consent_type)
);

CREATE TABLE gdpr_requests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    request_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

CREATE INDEX idx_gdpr_consents_user ON gdpr_consents(user_id);
CREATE INDEX idx_gdpr_requests_user ON gdpr_requests(user_id);

-- ============================================================
-- Sessions
-- ============================================================
CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
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
