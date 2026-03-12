CREATE TABLE company_settings (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    commission_rate DECIMAL(5,2) DEFAULT 15.00,
    working_hours_start TIME DEFAULT '06:00',
    working_hours_end TIME DEFAULT '22:00',
    default_currency VARCHAR(3) DEFAULT 'EUR',
    cancellation_fee_default DECIMAL(10,2) DEFAULT 0,
    no_show_fee DECIMAL(10,2) DEFAULT 0,
    auto_assign_enabled BOOLEAN DEFAULT false,
    updated_at TIMESTAMP DEFAULT NOW()
);
