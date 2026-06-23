-- Driver infrastructure: driver profiles, tariffs, and schedule visibility.
-- Depends on V1 (companies, persons).

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
-- Driver schedule visibility
-- ============================================================
CREATE TABLE driver_schedule_visibility (
    driver_id   UUID PRIMARY KEY REFERENCES persons(id),
    company_id  UUID NOT NULL REFERENCES companies(id),
    can_view_other_schedules BOOLEAN NOT NULL DEFAULT false,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_dsv_company_id ON driver_schedule_visibility(company_id);
