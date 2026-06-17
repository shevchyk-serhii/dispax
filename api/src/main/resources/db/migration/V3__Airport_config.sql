-- V3: Airport configuration tables (global, no company_id)
-- These tables are intentionally cross-tenant — access is gated by the SuperAdmin role check
-- in the HTTP layer, not by a company_id column. See SuperAdminAirportApi.scala.

CREATE TABLE airports (
    code           VARCHAR(10)       PRIMARY KEY,   -- e.g. "MUC"
    name           VARCHAR(255)      NOT NULL,
    country        VARCHAR(100)      NOT NULL DEFAULT 'DE',
    -- Landing geofence (coarse; used for automatic "Landed" trigger)
    landing_lat    DOUBLE PRECISION  NOT NULL,
    landing_lon    DOUBLE PRECISION  NOT NULL,
    landing_radius INT               NOT NULL,
    is_active      BOOLEAN           NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE TABLE airport_checkpoint_zones (
    id              UUID              PRIMARY KEY DEFAULT uuid_generate_v4(),
    airport_code    VARCHAR(10)       NOT NULL REFERENCES airports(code) ON DELETE CASCADE,
    terminal_code   VARCHAR(20)       NOT NULL,            -- "T1", "T2", "T2-PRIORITY"
    checkpoint_type VARCHAR(30)       NOT NULL,            -- "landed" | "arrivals_hall" | "terminal_exit"
    display_name    VARCHAR(255)      NOT NULL,            -- "T1 Arrivals Hall"
    lat             DOUBLE PRECISION  NOT NULL,
    lon             DOUBLE PRECISION  NOT NULL,
    radius_meters   INT               NOT NULL,
    sort_order      INT               NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_acz_airport_code ON airport_checkpoint_zones(airport_code);
CREATE INDEX idx_acz_terminal     ON airport_checkpoint_zones(airport_code, terminal_code);

-- Seed MUC: values match MucCheckpoints.scala so runtime behaviour is unchanged on day one.
-- The "Landed" checkpoint type is modelled at the airport level (the landing_* columns), not as
-- a row in airport_checkpoint_zones, because it is a single perimeter shared across all terminals.
INSERT INTO airports (code, name, country, landing_lat, landing_lon, landing_radius)
VALUES ('MUC', 'München Franz Josef Strauß', 'DE', 48.3537, 11.7860, 2000);

INSERT INTO airport_checkpoint_zones
    (airport_code, terminal_code, checkpoint_type, display_name, lat, lon, radius_meters, sort_order)
VALUES
    ('MUC', 'T1',          'arrivals_hall', 'T1 Arrivals Hall',  48.3526, 11.7798, 200, 1),
    ('MUC', 'T1',          'terminal_exit', 'T1 Exit',           48.3515, 11.7793, 150, 2),
    ('MUC', 'T2',          'arrivals_hall', 'T2 Arrivals Hall',  48.3549, 11.7853, 200, 1),
    ('MUC', 'T2',          'terminal_exit', 'T2 Exit',           48.3540, 11.7870, 150, 2),
    ('MUC', 'T2-PRIORITY', 'arrivals_hall', 'T2 Arrivals Hall',  48.3549, 11.7853, 200, 1),
    ('MUC', 'T2-PRIORITY', 'terminal_exit', 'T2 Priority Exit',  48.3543, 11.7867, 150, 2);
