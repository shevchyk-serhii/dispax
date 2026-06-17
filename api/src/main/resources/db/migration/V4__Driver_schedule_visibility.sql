CREATE TABLE driver_schedule_visibility (
    driver_id   UUID PRIMARY KEY REFERENCES persons(id),
    company_id  UUID NOT NULL REFERENCES companies(id),
    can_view_other_schedules BOOLEAN NOT NULL DEFAULT false,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_dsv_company_id ON driver_schedule_visibility(company_id);
