-- Development seed data: test company, users, and drivers.
-- This migration is ONLY applied in non-production environments
-- (FlywayService scans classpath:db/migration-dev only when APP_ENV != production).
-- Password for all accounts: password123
-- BCrypt hash: $2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S

-- Test company
INSERT INTO companies (id, name, email, phone, address)
VALUES ('10101010-1010-1010-1010-101010101010', 'Dispax München', 'info@dispax-muenchen.de', '+49 89 12345678', 'Leopoldstraße 1, 80802 München')
ON CONFLICT (id) DO NOTHING;

-- Tariff for test company
INSERT INTO tariffs (company_id, base_price_amount, base_price_currency, price_per_km_amount, price_per_km_currency, airport_surcharge_amount, airport_surcharge_currency, night_surcharge_amount, night_surcharge_currency)
VALUES ('10101010-1010-1010-1010-101010101010', 5.00, 'EUR', 2.50, 'EUR', 10.00, 'EUR', 5.00, 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Company settings
INSERT INTO company_settings (company_id, commission_rate, working_hours_start, working_hours_end, default_currency)
VALUES ('10101010-1010-1010-1010-101010101010', 15.00, '06:00', '22:00', 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Dispatcher (owner) — also a driver so dispatcher@dispax.de can be assigned to rides
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('11111111-1111-1111-1111-111111111111', 'Max Müller', 'dispatcher@dispax.de', 'dispatcher',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 1111111', 'ACTIVE', ARRAY['dispatcher','driver']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Driver row for the dispatcher-driver so they appear in location/status queries
INSERT INTO drivers (id, status, company_id)
VALUES ('11111111-1111-1111-1111-111111111111', 'Available', '10101010-1010-1010-1010-101010101010')
ON CONFLICT (id) DO NOTHING;

-- Secretary
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('22222222-2222-2222-2222-222222222222', 'Anna Schmidt', 'secretary@dispax.de', 'secretary',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 2222222', 'ACTIVE', ARRAY['secretary']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Driver 1
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status, roles)
VALUES ('33333333-3333-3333-3333-333333333333', 'Hans Weber', 'driver1@dispax.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 3333333', 'MÜN-HW-001', 'ACTIVE', ARRAY['driver']::person_role[])
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('33333333-3333-3333-3333-333333333333', 'Available', '10101010-1010-1010-1010-101010101010',
        'Marienplatz, München', 48.1374, 11.5755)
ON CONFLICT (id) DO NOTHING;

-- Driver 2
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status, roles)
VALUES ('44444444-4444-4444-4444-444444444444', 'Klaus Fischer', 'driver2@dispax.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 4444444', 'MÜN-KF-002', 'ACTIVE', ARRAY['driver']::person_role[])
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('44444444-4444-4444-4444-444444444444', 'Available', '10101010-1010-1010-1010-101010101010',
        'Hauptbahnhof, München', 48.1403, 11.5600)
ON CONFLICT (id) DO NOTHING;

-- Driver 3
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status, roles)
VALUES ('55555555-5555-5555-5555-555555555555', 'Peter Braun', 'driver3@dispax.de', 'driver',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 5555555', 'MÜN-PB-003', 'ACTIVE', ARRAY['driver']::person_role[])
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('55555555-5555-5555-5555-555555555555', 'Available', '10101010-1010-1010-1010-101010101010',
        'Flughafen München', 48.3537, 11.7750)
ON CONFLICT (id) DO NOTHING;

-- Client 1 (VIP, corporate)
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, is_vip, preferred_driver_id, status, roles)
VALUES ('66666666-6666-6666-6666-666666666666', 'BMW AG - Herr Schneider', 'client1@bmw.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999001', true, '33333333-3333-3333-3333-333333333333', 'ACTIVE', ARRAY['client']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Client 2
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('77777777-7777-7777-7777-777777777777', 'Siemens - Frau Meier', 'client2@siemens.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999002', 'ACTIVE', ARRAY['client']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Client 3
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('88888888-8888-8888-8888-888888888888', 'Allianz - Herr Klein', 'client3@allianz.de', 'client',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 9999003', 'ACTIVE', ARRAY['client']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Admin
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('99999999-9999-9999-9999-999999999999', 'Admin', 'admin@dispax.de', 'admin',
        '10101010-1010-1010-1010-101010101010',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 9999999', 'ACTIVE', ARRAY['admin']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- SuperAdmin (platform administrator, no company)
-- UUID: a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0
-- company_id is NULL: SuperAdmin is not scoped to any tenant
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0', 'SuperAdmin', 'superadmin@dispax.de', 'super_admin',
        NULL,
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        NULL, 'ACTIVE', ARRAY['super_admin']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Enrich company 1 with explicit status/plan for SuperAdmin analytics variety
-- ============================================================
UPDATE companies
SET status = 'Active', subscription_plan = 'Enterprise'
WHERE id = '10101010-1010-1010-1010-101010101010';

-- ============================================================
-- Second company: Taxi Schwabing GmbH (for cross-tenant SuperAdmin analytics)
-- ============================================================
INSERT INTO companies (id, name, email, phone, address, status, subscription_plan)
VALUES ('20202020-2020-2020-2020-202020202020', 'Taxi Schwabing GmbH', 'info@taxi-schwabing.de',
        '+49 89 87654321', 'Schwabing Hauptstraße 42, 80802 München', 'Trial', 'Professional')
ON CONFLICT (id) DO NOTHING;

-- Tariff for Taxi Schwabing
INSERT INTO tariffs (company_id, base_price_amount, base_price_currency, price_per_km_amount, price_per_km_currency, airport_surcharge_amount, airport_surcharge_currency, night_surcharge_amount, night_surcharge_currency)
VALUES ('20202020-2020-2020-2020-202020202020', 4.50, 'EUR', 2.20, 'EUR', 8.00, 'EUR', 4.00, 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Company settings for Taxi Schwabing
INSERT INTO company_settings (company_id, commission_rate, working_hours_start, working_hours_end, default_currency)
VALUES ('20202020-2020-2020-2020-202020202020', 12.00, '07:00', '21:00', 'EUR')
ON CONFLICT (company_id) DO NOTHING;

-- Billing profile for Taxi Schwabing (required FK for invoices)
INSERT INTO company_billing_profile (company_id, business_type, legal_name, address_line1, address_line2, phone, email, payment_terms_days)
VALUES ('20202020-2020-2020-2020-202020202020', 'Taxi- und Mietwagenunternehmen', 'Taxi Schwabing GmbH',
        'Schwabing Hauptstraße 42', '80802 München', '+49 89 87654321', 'info@taxi-schwabing.de', 14)
ON CONFLICT (company_id) DO NOTHING;

-- Dispatcher for Taxi Schwabing
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1', 'Thomas Bauer', 'dispatcher@taxi-schwabing.de', 'dispatcher',
        '20202020-2020-2020-2020-202020202020',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 7777777', 'ACTIVE', ARRAY['dispatcher']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- Driver for Taxi Schwabing
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, license_number, status, roles)
VALUES ('c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 'Maria Hoffmann', 'driver1@taxi-schwabing.de', 'driver',
        '20202020-2020-2020-2020-202020202020',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 170 8888888', 'SBG-MH-001', 'ACTIVE', ARRAY['driver']::person_role[])
ON CONFLICT (id) DO NOTHING;

INSERT INTO drivers (id, status, company_id, current_location_address, current_location_lat, current_location_lng)
VALUES ('c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2', 'Available', '20202020-2020-2020-2020-202020202020',
        'Schwabing, München', 48.1573, 11.5828)
ON CONFLICT (id) DO NOTHING;

-- Client for Taxi Schwabing
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, roles)
VALUES ('d3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3', 'Audi AG - Herr Wagner', 'client1@audi-schwabing.de', 'client',
        '20202020-2020-2020-2020-202020202020',
        '$2a$12$Pj3Nulk3iu7yoD99dfpiZexNQnJoy9aU1FXO53pyGYyHyWALgkS9S',
        '+49 89 7777001', 'ACTIVE', ARRAY['client']::person_role[])
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Driver schedules for Taxi Schwabing (so rides can be assigned)
-- ============================================================
INSERT INTO schedule_days (id, driver_id, company_id, date, start_time, end_time, status)
SELECT
  gen_random_uuid(),
  'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2'::uuid,
  '20202020-2020-2020-2020-202020202020'::uuid,
  CURRENT_DATE + offset_days,
  '00:00'::time,
  '23:59'::time,
  'Scheduled'
FROM (VALUES (0), (1), (2)) AS days(offset_days)
ON CONFLICT (driver_id, date) DO NOTHING;

-- ============================================================
-- Rides for company 1 (Dispax München) — varied statuses
-- ============================================================
INSERT INTO rides (id, client_id, creator_id, driver_id, company_id,
                   from_address, from_lat, from_lng, to_address, to_lat, to_lng,
                   pickup_datetime, request_time, start_time, end_time,
                   status, estimated_price_amount, estimated_price_currency,
                   final_price_amount, final_price_currency, payment_status)
VALUES
  -- Completed ride 1: client1 → airport, Hans Weber drove it
  ('e1e1e1e1-e1e1-e1e1-e1e1-e1e1e1e1e1e1',
   '66666666-6666-6666-6666-666666666666',
   '22222222-2222-2222-2222-222222222222',
   '33333333-3333-3333-3333-333333333333',
   '10101010-1010-1010-1010-101010101010',
   'Maximilianstraße 10, 80539 München', 48.1396, 11.5817,
   'Flughafen München Terminal 2, 85356 München', 48.3537, 11.7750,
   NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days 30 minutes',
   NOW() - INTERVAL '3 days', NOW() - INTERVAL '2 days 20 hours',
   'Completed', 62.50, 'EUR', 65.00, 'EUR', 'Paid'),
  -- Completed ride 2: client2, Klaus drove
  ('e2e2e2e2-e2e2-e2e2-e2e2-e2e2e2e2e2e2',
   '77777777-7777-7777-7777-777777777777',
   '77777777-7777-7777-7777-777777777777',
   '44444444-4444-4444-4444-444444444444',
   '10101010-1010-1010-1010-101010101010',
   'Leopoldstraße 42, 80802 München', 48.1573, 11.5828,
   'BMW Werk München, Petuelring 130, 80788 München', 48.1770, 11.5565,
   NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days 1 hour',
   NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '45 minutes',
   'Completed', 28.00, 'EUR', 29.50, 'EUR', 'Paid'),
  -- Completed ride 3: client3
  ('e3e3e3e3-e3e3-e3e3-e3e3-e3e3e3e3e3e3',
   '88888888-8888-8888-8888-888888888888',
   '11111111-1111-1111-1111-111111111111',
   '55555555-5555-5555-5555-555555555555',
   '10101010-1010-1010-1010-101010101010',
   'Hohenzollernstraße 25, 80801 München', 48.1654, 11.5780,
   'Allianz Arena, Werner-Heisenberg-Allee 25, 80939 München', 48.2188, 11.6248,
   NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days 2 hours',
   NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days' + INTERVAL '30 minutes',
   'Completed', 45.00, 'EUR', 47.00, 'EUR', 'Paid'),
  -- InProgress ride (ongoing)
  ('e4e4e4e4-e4e4-e4e4-e4e4-e4e4e4e4e4e4',
   '66666666-6666-6666-6666-666666666666',
   '22222222-2222-2222-2222-222222222222',
   '33333333-3333-3333-3333-333333333333',
   '10101010-1010-1010-1010-101010101010',
   'Marienplatz, München', 48.1374, 11.5755,
   'Hauptbahnhof, München', 48.1403, 11.5600,
   NOW() + INTERVAL '10 minutes', NOW() - INTERVAL '5 minutes',
   NOW() - INTERVAL '2 minutes', NULL,
   'InProgress', 12.00, 'EUR', NULL, 'EUR', 'Unpaid'),
  -- Requested ride (awaiting assignment)
  ('e5e5e5e5-e5e5-e5e5-e5e5-e5e5e5e5e5e5',
   '77777777-7777-7777-7777-777777777777',
   '22222222-2222-2222-2222-222222222222',
   NULL,
   '10101010-1010-1010-1010-101010101010',
   'Leopoldstraße 100, 80802 München', 48.1600, 11.5840,
   'Flughafen München Terminal 1, 85356 München', 48.3537, 11.7750,
   NOW() + INTERVAL '2 hours', NOW() - INTERVAL '10 minutes',
   NULL, NULL,
   'Requested', 58.00, 'EUR', NULL, 'EUR', 'Unpaid'),
  -- Cancelled ride
  ('e6e6e6e6-e6e6-e6e6-e6e6-e6e6e6e6e6e6',
   '88888888-8888-8888-8888-888888888888',
   '88888888-8888-8888-8888-888888888888',
   NULL,
   '10101010-1010-1010-1010-101010101010',
   'Schwabing, München', 48.1638, 11.5790,
   'Innenstadt, München', 48.1374, 11.5755,
   NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day 2 hours',
   NULL, NULL,
   'Cancelled', 22.00, 'EUR', NULL, 'EUR', 'Unpaid')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Rides for company 2 (Taxi Schwabing) — varied statuses
-- ============================================================
INSERT INTO rides (id, client_id, creator_id, driver_id, company_id,
                   from_address, from_lat, from_lng, to_address, to_lat, to_lng,
                   pickup_datetime, request_time, start_time, end_time,
                   status, estimated_price_amount, estimated_price_currency,
                   final_price_amount, final_price_currency, payment_status)
VALUES
  -- Completed ride for company 2
  ('f1f1f1f1-f1f1-f1f1-f1f1-f1f1f1f1f1f1',
   'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3',
   'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1',
   'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2',
   '20202020-2020-2020-2020-202020202020',
   'Audi Büro Schwabing, München', 48.1590, 11.5820,
   'Flughafen München Terminal 2, 85356 München', 48.3537, 11.7750,
   NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days 1 hour',
   NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '50 minutes',
   'Completed', 54.00, 'EUR', 57.50, 'EUR', 'Paid'),
  -- Completed ride 2 for company 2
  ('f2f2f2f2-f2f2-f2f2-f2f2-f2f2f2f2f2f2',
   'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3',
   'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3',
   'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2',
   '20202020-2020-2020-2020-202020202020',
   'Schwabing Hauptstraße 42, 80802 München', 48.1573, 11.5828,
   'Hauptbahnhof, München', 48.1403, 11.5600,
   NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days 30 minutes',
   NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days' + INTERVAL '20 minutes',
   'Completed', 18.00, 'EUR', 19.00, 'EUR', 'Paid'),
  -- Assigned ride for company 2
  ('f3f3f3f3-f3f3-f3f3-f3f3-f3f3f3f3f3f3',
   'd3d3d3d3-d3d3-d3d3-d3d3-d3d3d3d3d3d3',
   'b1b1b1b1-b1b1-b1b1-b1b1-b1b1b1b1b1b1',
   'c2c2c2c2-c2c2-c2c2-c2c2-c2c2c2c2c2c2',
   '20202020-2020-2020-2020-202020202020',
   'Schwabing Markt, München', 48.1622, 11.5807,
   'Marienplatz, München', 48.1374, 11.5755,
   NOW() + INTERVAL '3 hours', NOW() - INTERVAL '15 minutes',
   NULL, NULL,
   'Assigned', 25.00, 'EUR', NULL, 'EUR', 'Unpaid')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Client companies (billing entities) for invoices
-- ============================================================
-- BMW AG as a client company of Dispax München
INSERT INTO client_companies (id, name, email, phone, address, taxi_company_id)
VALUES ('cc010101-cc01-cc01-cc01-cc01cc01cc01', 'BMW AG München', 'billing@bmw-ag.de',
        '+49 89 382-0', 'Petuelring 130, 80788 München', '10101010-1010-1010-1010-101010101010')
ON CONFLICT (id) DO NOTHING;

-- Siemens AG as a client company of Dispax München
INSERT INTO client_companies (id, name, email, phone, address, taxi_company_id)
VALUES ('cc020202-cc02-cc02-cc02-cc02cc02cc02', 'Siemens AG München', 'billing@siemens-ag.de',
        '+49 89 636-0', 'Werner-von-Siemens-Straße 1, 80333 München', '10101010-1010-1010-1010-101010101010')
ON CONFLICT (id) DO NOTHING;

-- Audi AG as a client company of Taxi Schwabing
INSERT INTO client_companies (id, name, email, phone, address, taxi_company_id)
VALUES ('cc030303-cc03-cc03-cc03-cc03cc03cc03', 'Audi AG Schwabing', 'billing@audi-schwabing.de',
        '+49 841 89-0', 'Audi Straße 1, 85045 Ingolstadt', '20202020-2020-2020-2020-202020202020')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- Invoice sequences (required for nextInvoiceNumber)
-- ============================================================
INSERT INTO invoice_sequences (company_id, last_number) VALUES ('10101010-1010-1010-1010-101010101010', 3)
ON CONFLICT (company_id) DO NOTHING;

INSERT INTO invoice_sequences (company_id, last_number) VALUES ('20202020-2020-2020-2020-202020202020', 1)
ON CONFLICT (company_id) DO NOTHING;

-- ============================================================
-- Invoices for Dispax München (company 1) — varied statuses
-- ============================================================
INSERT INTO invoices (id, number, client_company_id, taxi_company_id, status,
                      period_from, period_to, subtotal_amount, tax_rate, tax_amount, total_amount,
                      currency, due_date, sent_at, paid_at, created_at)
VALUES
  -- Paid invoice: BMW AG
  ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1',
   'DEV-2026-0001',
   'cc010101-cc01-cc01-cc01-cc01cc01cc01',
   '10101010-1010-1010-1010-101010101010',
   'paid',
   '2026-05-01', '2026-05-31',
   200.00, 19.00, 38.00, 238.00, 'EUR',
   '2026-06-07',
   '2026-06-01 09:00:00+00',
   '2026-06-05 14:00:00+00',
   '2026-05-31 10:00:00+00'),
  -- Sent invoice: Siemens AG (not yet paid, not overdue)
  ('a2a2a2a2-a2a2-a2a2-a2a2-a2a2a2a2a2a2',
   'DEV-2026-0002',
   'cc020202-cc02-cc02-cc02-cc02cc02cc02',
   '10101010-1010-1010-1010-101010101010',
   'sent',
   '2026-05-01', '2026-05-31',
   120.00, 19.00, 22.80, 142.80, 'EUR',
   '2099-12-31',
   '2026-06-01 10:00:00+00',
   NULL,
   '2026-05-31 11:00:00+00'),
  -- Sent invoice: BMW AG, OVERDUE (due_date in the past)
  ('a3a3a3a3-a3a3-a3a3-a3a3-a3a3a3a3a3a3',
   'DEV-2026-0003',
   'cc010101-cc01-cc01-cc01-cc01cc01cc01',
   '10101010-1010-1010-1010-101010101010',
   'sent',
   '2026-04-01', '2026-04-30',
   95.00, 19.00, 18.05, 113.05, 'EUR',
   '2026-05-15',
   '2026-05-01 08:00:00+00',
   NULL,
   '2026-04-30 09:00:00+00')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Invoice for Taxi Schwabing (company 2) — Paid
-- ============================================================
INSERT INTO invoices (id, number, client_company_id, taxi_company_id, status,
                      period_from, period_to, subtotal_amount, tax_rate, tax_amount, total_amount,
                      currency, due_date, sent_at, paid_at, created_at)
VALUES
  ('b1b1b1b2-b1b1-b1b1-b1b1-b1b1b1b1b1b2',
   'DEV-SBG-0001',
   'cc030303-cc03-cc03-cc03-cc03cc03cc03',
   '20202020-2020-2020-2020-202020202020',
   'paid',
   '2026-05-01', '2026-05-31',
   150.00, 19.00, 28.50, 178.50, 'EUR',
   '2026-06-07',
   '2026-06-01 11:00:00+00',
   '2026-06-04 16:00:00+00',
   '2026-05-31 12:00:00+00')
ON CONFLICT DO NOTHING;
