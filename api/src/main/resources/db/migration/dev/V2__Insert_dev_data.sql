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
-- Password for all test users: password123
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone) VALUES
    ('11111111-1111-1111-1111-111111111111', 'John Client', 'john.client@example.com', 'client', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380501111111'),
    ('22222222-2222-2222-2222-222222222222', 'Jane Driver', 'jane.driver@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380502222222'),
    ('33333333-3333-3333-3333-333333333333', 'Bob Dispatcher', 'bob.dispatcher@example.com', 'dispatcher', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380503333333'),
    ('44444444-4444-4444-4444-444444444444', 'Maria Secretary', 'maria.secretary@example.com', 'secretary', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380504444444');

-- Insert driver profile for Jane Driver
INSERT INTO drivers (id, status, company_id) VALUES 
    ('22222222-2222-2222-2222-222222222222', 'Available', '11111111-1111-1111-1111-111111111111');

-- Insert additional test data for development
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone) VALUES
    ('10101010-1010-1010-1010-101010101010', 'Mike Driver', 'mike@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380505555555'),
    ('11111111-1111-1111-1111-111111111112', 'Sara Driver', 'sara@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380506666666'),
    ('12121212-1212-1212-1212-121212121212', 'Alex Driver', 'alex@example.com', 'driver', '11111111-1111-1111-1111-111111111111', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380507777777');

-- Insert additional drivers
INSERT INTO drivers (id, status, company_id) VALUES 
    ('10101010-1010-1010-1010-101010101010', 'Available', '11111111-1111-1111-1111-111111111111'),
    ('11111111-1111-1111-1111-111111111112', 'Busy', '11111111-1111-1111-1111-111111111111'),
    ('12121212-1212-1212-1212-121212121212', 'Offline', '11111111-1111-1111-1111-111111111111');

-- Insert test users into auth users table
-- Password for all test users: password123 (hash: 75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=)
-- Password test123 (hash: 7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=)
INSERT INTO users (id, email, name, role, password_hash, phone, status) VALUES
    ('11111111-1111-1111-1111-111111111111', 'john.client@example.com', 'John Client', 'CLIENT', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380501111111', 'ACTIVE'),
    ('22222222-2222-2222-2222-222222222222', 'jane.driver@example.com', 'Jane Driver', 'DRIVER', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380502222222', 'ACTIVE'),
    ('33333333-3333-3333-3333-333333333333', 'bob.dispatcher@example.com', 'Bob Dispatcher', 'DISPATCHER', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380503333333', 'ACTIVE'),
    ('44444444-4444-4444-4444-444444444444', 'maria.secretary@example.com', 'Maria Secretary', 'SECRETARY', '75K3eLr+dx6JJFuJ7LwIpEpOFmwGZZkRiB84PURz6U8=', '+380504444444', 'ACTIVE'),
    ('55555555-5555-5555-5555-555555555555', 'john.driver@oktopus.com', 'John Driver', 'DRIVER', '7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=', '+380505555555', 'ACTIVE'),
    ('66666666-6666-6666-6666-666666666666', 'anna.client@example.com', 'Anna Client', 'CLIENT', '7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=', '+380506666666', 'ACTIVE'),
    ('77777777-7777-7777-7777-777777777777', 'maria.secretary@oktopus.com', 'Maria Secretary', 'SECRETARY', '7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=', '+380507777777', 'ACTIVE'),
    ('88888888-8888-8888-8888-888888888888', 'peter.dispatcher@oktopus.com', 'Peter Dispatcher', 'DISPATCHER', '7NcYcNGWMxapfjrDQIyYNa2M8PPBvHA1J8MCZVNPda4=', '+380508888888', 'ACTIVE');

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