-- Development seed data: test company, users, and drivers
-- Password for all accounts: password123
-- BCrypt hash: $2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S

-- Test company
INSERT INTO companies (id, name, email, phone, address)
VALUES ('10101010-1010-1010-1010-101010101010', 'Oktopus München', 'info@oktopus-muenchen.de', '+49 89 12345678', 'Leopoldstraße 1, 80802 München')
ON CONFLICT (id) DO NOTHING;

-- Tariff for test company
INSERT INTO tariffs (company_id, base_price_amount, base_price_currency, price_per_km_amount, price_per_km_currency, airport_surcharge_amount, night_surcharge_amount)
VALUES ('10101010-1010-1010-1010-101010101010', 5.00, 'EUR', 2.50, 'EUR', 10.00, 5.00)
ON CONFLICT (company_id) DO NOTHING;

-- Company settings
INSERT INTO company_settings (company_id, commission_rate, working_hours_start, working_hours_end, default_currency)
VALUES ('10101010-1010-1010-1010-101010101010', 15.00, '06:00', '22:00', 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Dispatcher (owner)
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('11111111-1111-1111-1111-111111111111', 'Max Müller', 'dispatcher@oktopus.de', 'dispatcher',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 1111111', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Secretary
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('22222222-2222-2222-2222-222222222222', 'Anna Schmidt', 'secretary@oktopus.de', 'secretary',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 2222222', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Driver 1
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status)
VALUES ('33333333-3333-3333-3333-333333333333', 'Hans Weber', 'driver1@oktopus.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 3333333', 'MÜN-HW-001', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('33333333-3333-3333-3333-333333333333', 'Available', '10101010-1010-1010-1010-101010101010',
        'Marienplatz, München', 48.1374, 11.5755)
ON CONFLICT (id) DO NOTHING;

-- Driver 2
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status)
VALUES ('44444444-4444-4444-4444-444444444444', 'Klaus Fischer', 'driver2@oktopus.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 4444444', 'MÜN-KF-002', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('44444444-4444-4444-4444-444444444444', 'Available', '10101010-1010-1010-1010-101010101010',
        'Hauptbahnhof, München', 48.1403, 11.5600)
ON CONFLICT (id) DO NOTHING;

-- Driver 3
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status)
VALUES ('55555555-5555-5555-5555-555555555555', 'Peter Braun', 'driver3@oktopus.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 5555555', 'MÜN-PB-003', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('55555555-5555-5555-5555-555555555555', 'Available', '10101010-1010-1010-1010-101010101010',
        'Flughafen München', 48.3537, 11.7750)
ON CONFLICT (id) DO NOTHING;

-- Client 1 (VIP, corporate)
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, is_vip, preferred_driver_id, status)
VALUES ('66666666-6666-6666-6666-666666666666', 'BMW AG - Herr Schneider', 'client1@bmw.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999001', true, '33333333-3333-3333-3333-333333333333', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Client 2
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('77777777-7777-7777-7777-777777777777', 'Siemens - Frau Meier', 'client2@siemens.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999002', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Client 3
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('88888888-8888-8888-8888-888888888888', 'Allianz - Herr Klein', 'client3@allianz.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999003', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;

-- Admin
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status)
VALUES ('99999999-9999-9999-9999-999999999999', 'Admin', 'admin@oktopus.de', 'admin',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 9999999', 'ACTIVE')
ON CONFLICT (id) DO NOTHING;
