-- Companies table
CREATE TABLE companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Persons table (users with different roles)
CREATE TABLE persons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('client', 'driver', 'secretary', 'dispatcher')),
    company_id BIGINT REFERENCES companies(id),
    phone VARCHAR(50),
    license_number VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Rides table
CREATE TABLE rides (
    id SERIAL PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES persons(id),
    creator_id BIGINT NOT NULL REFERENCES persons(id),
    driver_id BIGINT REFERENCES persons(id),
    company_id BIGINT NOT NULL REFERENCES companies(id),
    pickup_date_time TIMESTAMP NOT NULL,
    pickup_address VARCHAR(500) NOT NULL,
    pickup_latitude DECIMAL(10,8),
    pickup_longitude DECIMAL(11,8),
    destination_address VARCHAR(500) NOT NULL,
    destination_latitude DECIMAL(10,8),
    destination_longitude DECIMAL(11,8),
    status VARCHAR(20) NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'assigned', 'inProgress', 'completed', 'cancelled')),
    price DECIMAL(10,2),
    is_airport_transfer BOOLEAN DEFAULT FALSE,
    flight_number VARCHAR(20),
    is_arrival BOOLEAN,
    gate VARCHAR(10),
    terminal VARCHAR(50),
    flight_status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Schedules table for driver schedules
CREATE TABLE schedules (
    id SERIAL PRIMARY KEY,
    driver_id BIGINT NOT NULL REFERENCES persons(id),
    date DATE NOT NULL,
    is_available BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(driver_id, date)
);

-- Current locations table for real-time tracking
CREATE TABLE current_locations (
    entity_type VARCHAR(10) NOT NULL CHECK (entity_type IN ('driver', 'client')),
    entity_id BIGINT NOT NULL,
    latitude DECIMAL(10,8) NOT NULL,
    longitude DECIMAL(11,8) NOT NULL,
    accuracy FLOAT,
    speed FLOAT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (entity_type, entity_id)
);

-- Create indexes for performance
CREATE INDEX idx_persons_role ON persons(role);
CREATE INDEX idx_persons_company ON persons(company_id);
CREATE INDEX idx_persons_email ON persons(email);

CREATE INDEX idx_rides_client ON rides(client_id);
CREATE INDEX idx_rides_driver ON rides(driver_id);
CREATE INDEX idx_rides_company ON rides(company_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_pickup_time ON rides(pickup_date_time);

CREATE INDEX idx_schedules_driver ON schedules(driver_id);
CREATE INDEX idx_schedules_date ON schedules(date);

CREATE INDEX idx_locations_updated ON current_locations(updated_at);

-- Insert default company for testing
INSERT INTO companies (id, name) VALUES (1, 'Oktopus Taxi Munich') ON CONFLICT DO NOTHING;