-- Airport configuration schema (global, no company_id).
-- DDL only — reference data is seeded in V9__seed_airport_reference.sql.
-- These tables are intentionally cross-tenant — access is gated by the SuperAdmin role check
-- in the HTTP layer, not by a company_id column. See SuperAdminAirportApi.scala.
-- airport_checkpoint_zones depends on airports — created after within this file.

-- ============================================================
-- Airports
-- ============================================================
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

-- ============================================================
-- Airport checkpoint zones
-- ============================================================
-- Must be created after airports (FK dependency on airports.code).
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
