-- Seed MUC airport reference data.
-- DDL lives in V8__airport_schema.sql.
-- Values match MucCheckpoints.scala so runtime behaviour is unchanged on day one.
-- The "Landed" checkpoint type is modelled at the airport level (the landing_* columns), not as
-- a row in airport_checkpoint_zones, because it is a single perimeter shared across all terminals.
-- Idempotent: ON CONFLICT DO NOTHING on both tables.

INSERT INTO airports (code, name, country, landing_lat, landing_lon, landing_radius)
VALUES ('MUC', 'München Franz Josef Strauß', 'DE', 48.3537, 11.7860, 2000)
ON CONFLICT (code) DO NOTHING;

INSERT INTO airport_checkpoint_zones
    (airport_code, terminal_code, checkpoint_type, display_name, lat, lon, radius_meters, sort_order)
VALUES
    ('MUC', 'T1',          'arrivals_hall', 'T1 Arrivals Hall',  48.3526, 11.7798, 200, 1),
    ('MUC', 'T1',          'terminal_exit', 'T1 Exit',           48.3515, 11.7793, 150, 2),
    ('MUC', 'T2',          'arrivals_hall', 'T2 Arrivals Hall',  48.3549, 11.7853, 200, 1),
    ('MUC', 'T2',          'terminal_exit', 'T2 Exit',           48.3540, 11.7870, 150, 2),
    ('MUC', 'T2-PRIORITY', 'arrivals_hall', 'T2 Arrivals Hall',  48.3549, 11.7853, 200, 1),
    ('MUC', 'T2-PRIORITY', 'terminal_exit', 'T2 Priority Exit',  48.3543, 11.7867, 150, 2)
ON CONFLICT DO NOTHING;
