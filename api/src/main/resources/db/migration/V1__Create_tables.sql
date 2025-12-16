-- Initial Oktopus Taxi Database Schema
-- This migration creates the complete initial schema for the application

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE ride_status AS ENUM ('Requested', 'Assigned', 'InProgress', 'Completed', 'Cancelled');
CREATE TYPE person_role AS ENUM ('driver', 'client', 'secretary', 'dispatcher');
CREATE TYPE driver_status AS ENUM ('Available', 'Busy', 'Offline');

-- Companies table
CREATE TABLE companies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Persons table (users, drivers, clients, dispatchers)
CREATE TABLE persons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role person_role NOT NULL,
    company_id INTEGER REFERENCES companies(id),
    password_hash VARCHAR(255),
    license_number VARCHAR(50),
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Drivers table (extends persons)
CREATE TABLE drivers (
    id INTEGER PRIMARY KEY REFERENCES persons(id),
    current_location_address VARCHAR(500),
    current_location_lat DOUBLE PRECISION,
    current_location_lng DOUBLE PRECISION,
    status driver_status NOT NULL DEFAULT 'Available',
    company_id INTEGER NOT NULL REFERENCES companies(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tariffs table
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rides table (complete schema)
CREATE TABLE rides (
    id BIGSERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES persons(id),
    creator_id INTEGER NOT NULL REFERENCES persons(id),
    driver_id INTEGER REFERENCES persons(id),
    company_id INTEGER NOT NULL REFERENCES companies(id),
    
    -- Location information
    from_address VARCHAR(500) NOT NULL,
    from_lat DOUBLE PRECISION,
    from_lng DOUBLE PRECISION,
    to_address VARCHAR(500) NOT NULL,
    to_lat DOUBLE PRECISION,
    to_lng DOUBLE PRECISION,
    
    -- Time information
    pickup_datetime TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_time TIMESTAMP WITH TIME ZONE,
    request_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    
    -- Status and pricing
    status ride_status NOT NULL DEFAULT 'Requested',
    tariff_id INTEGER REFERENCES tariffs(company_id),
    estimated_price_amount DECIMAL(10,2),
    estimated_price_currency VARCHAR(3) DEFAULT 'EUR',
    final_price_amount DECIMAL(10,2),
    final_price_currency VARCHAR(3) DEFAULT 'EUR',
    price_amount DECIMAL(10,2),
    price_currency VARCHAR(3),
    estimated_distance_km DOUBLE PRECISION,
    
    -- Flight/Airport information
    flight_number VARCHAR(20),
    flight_time TIMESTAMP WITH TIME ZONE,
    flight_gate VARCHAR(10),
    flight_terminal VARCHAR(10),
    flight_status VARCHAR(50),
    flight_is_arrival BOOLEAN,
    airport_code VARCHAR(10),
    is_airport_transfer BOOLEAN DEFAULT FALSE,
    
    -- Additional information
    notes TEXT,
    
    -- Audit fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_rides_client_id ON rides(client_id);
CREATE INDEX idx_rides_driver_id ON rides(driver_id);
CREATE INDEX idx_rides_company_id ON rides(company_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_pickup_datetime ON rides(pickup_datetime);
CREATE INDEX idx_rides_scheduled_time ON rides(scheduled_time);
CREATE INDEX idx_rides_request_time ON rides(request_time);
CREATE INDEX idx_rides_is_airport_transfer ON rides(is_airport_transfer);

CREATE INDEX idx_persons_email ON persons(email);
CREATE INDEX idx_persons_company_id ON persons(company_id);
CREATE INDEX idx_persons_role ON persons(role);

CREATE INDEX idx_drivers_status ON drivers(status);
CREATE INDEX idx_drivers_company_id ON drivers(company_id);

-- Insert default data
INSERT INTO companies (id, name, email, phone, address) VALUES 
    (1, 'Oktopus Taxi', 'info@oktopus.taxi', '+380501234567', 'Kyiv, Ukraine');

INSERT INTO tariffs (company_id, base_price_amount, price_per_km_amount, airport_surcharge_amount, night_surcharge_amount) VALUES
    (1, 5.00, 1.50, 5.00, 2.00);

-- Insert test users
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone) VALUES 
    (1, 'John Client', 'john.client@example.com', 'client', 1, '$2a$10$dummyhash1', '+380501111111'),
    (2, 'Jane Driver', 'jane.driver@example.com', 'driver', 1, '$2a$10$dummyhash2', '+380502222222'),
    (3, 'Bob Dispatch', 'bob.dispatch@example.com', 'dispatcher', 1, '$2a$10$dummyhash3', '+380503333333');

INSERT INTO drivers (id, status, company_id) VALUES 
    (2, 'Available', 1);