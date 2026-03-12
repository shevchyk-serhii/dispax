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
