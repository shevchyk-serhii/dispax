-- Platform miscellaneous: audit log, geofences, blacklist, client addresses.
-- Depends on V1 (companies, persons).
-- Note: geofence_alerts depends on geofences — created after within this file.

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

-- ============================================================
-- Geofence alerts
-- ============================================================
-- Must be created after geofences (FK dependency).
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
