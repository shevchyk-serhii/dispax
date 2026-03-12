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
