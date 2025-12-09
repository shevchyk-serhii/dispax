CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE ride_status AS ENUM ('Requested', 'Assigned', 'InProgress', 'Completed', 'Cancelled');
CREATE TYPE person_role AS ENUM ('driver', 'client', 'secretary', 'dispatcher');
CREATE TYPE driver_status AS ENUM ('Available', 'Busy', 'Offline');

CREATE TABLE companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE persons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role person_role NOT NULL,
    company_id INTEGER REFERENCES companies(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE drivers (
    id INTEGER PRIMARY KEY REFERENCES persons(id),
    current_location_address VARCHAR(500),
    current_location_lat DOUBLE PRECISION,
    current_location_lng DOUBLE PRECISION,
    status driver_status NOT NULL DEFAULT 'Available',
    company_id INTEGER NOT NULL REFERENCES companies(id)
);

CREATE TABLE tariffs (
    company_id INTEGER PRIMARY KEY REFERENCES companies(id),
    base_price_amount DECIMAL(10,2) NOT NULL,
    base_price_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    price_per_km_amount DECIMAL(10,2) NOT NULL,
    price_per_km_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    airport_surcharge_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    airport_surcharge_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    night_surcharge_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    night_surcharge_currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE rides (
    id BIGSERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES persons(id),
    creator_id INTEGER NOT NULL REFERENCES persons(id),
    driver_id INTEGER REFERENCES persons(id),
    company_id INTEGER NOT NULL REFERENCES companies(id),
    pickup_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,
    status ride_status NOT NULL DEFAULT 'Requested',
    price_amount DECIMAL(10,2),
    price_currency VARCHAR(3),
    estimated_distance_km DOUBLE PRECISION,
    flight_number VARCHAR(20),
    flight_time TIMESTAMP WITH TIME ZONE,
    flight_gate VARCHAR(10),
    flight_terminal VARCHAR(10),
    flight_status VARCHAR(50),
    flight_is_arrival BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rides_client_id ON rides(client_id);
CREATE INDEX idx_rides_driver_id ON rides(driver_id);
CREATE INDEX idx_rides_company_id ON rides(company_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_pickup_datetime ON rides(pickup_datetime);
CREATE INDEX idx_persons_email ON persons(email);
CREATE INDEX idx_persons_company_id ON persons(company_id);
CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_company_id ON drivers(company_id);

INSERT INTO companies (id, name) VALUES 
    (1, 'Default Taxi Company');

INSERT INTO tariffs (company_id, base_price_amount, price_per_km_amount, airport_surcharge_amount, night_surcharge_amount) VALUES
    (1, 5.00, 1.50, 5.00, 2.00);