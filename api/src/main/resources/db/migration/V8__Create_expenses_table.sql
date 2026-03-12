CREATE TABLE expenses (
    id UUID PRIMARY KEY,
    ride_id UUID REFERENCES rides(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    category VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',
    description TEXT,
    receipt_url TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expenses_ride_id ON expenses(ride_id);
CREATE INDEX idx_expenses_driver_id ON expenses(driver_id);
CREATE INDEX idx_expenses_company_id ON expenses(company_id);
