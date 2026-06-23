-- Schedule domain: driver work days and manual unavailability intervals.
-- Depends on V1 (companies, persons, driver_unavailability_reason enum).
-- driver_unavailability_reason enum is declared in V1 so no forward dependency exists.

-- ============================================================
-- Schedule days
-- ============================================================
CREATE TABLE schedule_days (
    id UUID PRIMARY KEY,
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    status schedule_day_status NOT NULL DEFAULT 'Scheduled',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_driver_date UNIQUE (driver_id, date)
);

CREATE INDEX idx_schedule_days_driver_id ON schedule_days(driver_id);
CREATE INDEX idx_schedule_days_company_id ON schedule_days(company_id);
CREATE INDEX idx_schedule_days_date ON schedule_days(date);
CREATE INDEX idx_schedule_days_status ON schedule_days(status);
CREATE INDEX idx_schedule_days_company_date ON schedule_days(company_id, date);

-- ============================================================
-- Driver unavailability
-- ============================================================
-- Manual busy intervals (lunch/vacation/personal).
-- Drivers mark their own unavailability; dispatchers see and respect it when assigning.
-- Enum driver_unavailability_reason declared in V1.
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
