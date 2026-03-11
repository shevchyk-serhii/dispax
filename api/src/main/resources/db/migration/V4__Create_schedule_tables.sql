CREATE TYPE schedule_day_status AS ENUM ('Scheduled', 'Active', 'Completed', 'Cancelled');

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

ALTER TABLE rides ADD COLUMN schedule_day_id UUID REFERENCES schedule_days(id);
CREATE INDEX idx_rides_schedule_day_id ON rides(schedule_day_id);
