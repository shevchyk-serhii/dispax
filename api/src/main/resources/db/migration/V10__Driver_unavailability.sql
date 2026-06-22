-- Driver unavailability: manual busy intervals (lunch/vacation/personal).
-- Drivers mark their own unavailability; dispatchers see and respect it when assigning.

CREATE TYPE driver_unavailability_reason AS ENUM ('Lunch', 'Vacation', 'Personal');

CREATE TABLE driver_unavailability (
    id          UUID                         NOT NULL PRIMARY KEY,
    driver_id   UUID                         NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    company_id  UUID                         NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    from_time   TIMESTAMPTZ                  NOT NULL,
    to_time     TIMESTAMPTZ                  NOT NULL,
    reason      driver_unavailability_reason NOT NULL,
    note        TEXT,
    created_at  TIMESTAMPTZ                  NOT NULL DEFAULT now(),

    CONSTRAINT chk_unavailability_time_order CHECK (from_time < to_time)
);

CREATE INDEX idx_unavailability_driver_company
    ON driver_unavailability (driver_id, company_id);

CREATE INDEX idx_unavailability_driver_company_range
    ON driver_unavailability (driver_id, company_id, from_time, to_time);
