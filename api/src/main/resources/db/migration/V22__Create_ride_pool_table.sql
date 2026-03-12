-- Ride pooling / sharing
CREATE TABLE IF NOT EXISTS ride_pools (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL,
    name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'OPEN',  -- OPEN, FULL, IN_PROGRESS, COMPLETED, CANCELLED
    driver_id UUID,
    max_passengers INT NOT NULL DEFAULT 4,
    current_passengers INT NOT NULL DEFAULT 0,
    route_direction VARCHAR(200),
    scheduled_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by UUID NOT NULL
);

CREATE TABLE IF NOT EXISTS ride_pool_members (
    id UUID PRIMARY KEY,
    pool_id UUID NOT NULL REFERENCES ride_pools(id),
    ride_id UUID NOT NULL,
    client_id UUID NOT NULL,
    pickup_order INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING, CONFIRMED, PICKED_UP, DROPPED_OFF, CANCELLED
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ride_pools_company ON ride_pools(company_id);
CREATE INDEX idx_ride_pools_status ON ride_pools(status);
CREATE INDEX idx_ride_pool_members_pool ON ride_pool_members(pool_id);
CREATE INDEX idx_ride_pool_members_ride ON ride_pool_members(ride_id);

-- Notification preferences
CREATE TABLE IF NOT EXISTS notification_preferences (
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

-- Add pool_id to rides table
ALTER TABLE rides ADD COLUMN IF NOT EXISTS pool_id UUID REFERENCES ride_pools(id);
