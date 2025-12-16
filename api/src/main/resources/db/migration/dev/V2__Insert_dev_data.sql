-- Development test data
-- This migration is only applied in development/testing environments
-- Production should skip this migration or use different data seeding approach

-- Insert default company
INSERT INTO companies (id, name, email, phone, address) VALUES 
    ('11111111-1111-1111-1111-111111111111', 'Oktopus Taxi', 'info@oktopus.taxi', '+380501234567', 'Kyiv, Ukraine');

-- Insert tariff for the default company
INSERT INTO tariffs (company_id, base_price_amount, price_per_km_amount, airport_surcharge_amount, night_surcharge_amount) VALUES
    ('11111111-1111-1111-1111-111111111111', 5.00, 1.50, 5.00, 2.00);

-- Insert test users with consistent UUIDs for testing
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone) VALUES 
    ('11111111-1111-1111-1111-111111111111', 'John Client', 'john.client@example.com', 'client', '11111111-1111-1111-1111-111111111111', '$2a$10$dummyhash1', '+380501111111'),
    ('22222222-2222-2222-2222-222222222222', 'Jane Driver', 'jane.driver@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '$2a$10$dummyhash2', '+380502222222'),
    ('33333333-3333-3333-3333-333333333333', 'Bob Dispatch', 'bob.dispatch@example.com', 'dispatcher', '11111111-1111-1111-1111-111111111111', '$2a$10$dummyhash3', '+380503333333');

-- Insert driver profile for Jane Driver
INSERT INTO drivers (id, status, company_id) VALUES 
    ('22222222-2222-2222-2222-222222222222', 'Available', '11111111-1111-1111-1111-111111111111');

-- Insert additional test data for development
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone) VALUES 
    ('10101010-1010-1010-1010-101010101010', 'Mike Driver', 'mike@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '$2a$10$dummyhash4', '+380504444444'),
    ('11111111-1111-1111-1111-111111111112', 'Sara Driver', 'sara@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '$2a$10$dummyhash5', '+380505555555'),
    ('12121212-1212-1212-1212-121212121212', 'Alex Driver', 'alex@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '$2a$10$dummyhash6', '+380506666666');

-- Insert additional drivers
INSERT INTO drivers (id, status, company_id) VALUES 
    ('10101010-1010-1010-1010-101010101010', 'Available', '11111111-1111-1111-1111-111111111111'),
    ('11111111-1111-1111-1111-111111111112', 'Busy', '11111111-1111-1111-1111-111111111111'),
    ('12121212-1212-1212-1212-121212121212', 'Offline', '11111111-1111-1111-1111-111111111111');

-- Insert test users into auth users table
INSERT INTO users (id, email, name, role, password_hash, phone, status) VALUES 
    ('11111111-1111-1111-1111-111111111111', 'john.client@example.com', 'John Client', 'CLIENT', '$2a$10$dummyhash1', '+380501111111', 'ACTIVE'),
    ('22222222-2222-2222-2222-222222222222', 'jane.driver@example.com', 'Jane Driver', 'DRIVER', '$2a$10$dummyhash2', '+380502222222', 'ACTIVE'),
    ('33333333-3333-3333-3333-333333333333', 'bob.dispatch@example.com', 'Bob Dispatch', 'DISPATCHER', '$2a$10$dummyhash3', '+380503333333', 'ACTIVE');

-- Sample ride data for testing
INSERT INTO rides (
    id, client_id, creator_id, driver_id, company_id,
    pickup_datetime, scheduled_time, request_time,
    from_address, to_address,
    status, 
    estimated_price_amount, final_price_amount,
    is_airport_transfer
) VALUES 
    ('0000007b-0000-0000-0000-000000000123', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111',
     NOW() + INTERVAL '2 hours', NOW() + INTERVAL '2 hours', NOW(),
     'Kyiv Airport', 'City Center',
     'Assigned',
     25.50, NULL,
     true),
    ('000001c8-0000-0000-0000-000000000456', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', NULL, '11111111-1111-1111-1111-111111111111',
     NOW() + INTERVAL '1 hour', NOW() + INTERVAL '1 hour', NOW(),
     'Independence Square', 'Railway Station',
     'Requested',
     15.00, NULL,
     false);