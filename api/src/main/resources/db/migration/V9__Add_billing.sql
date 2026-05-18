-- Invoice sequence counter per taxi company
CREATE TABLE invoice_sequences (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    last_number INTEGER NOT NULL DEFAULT 0
);

-- Client company invoices
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    number VARCHAR(50) NOT NULL,
    client_company_id UUID NOT NULL REFERENCES client_companies(id),
    taxi_company_id UUID NOT NULL REFERENCES companies(id),
    status VARCHAR(20) NOT NULL DEFAULT 'draft',
    period_from DATE NOT NULL,
    period_to DATE NOT NULL,
    subtotal_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(3) NOT NULL DEFAULT 'EUR',
    notes TEXT,
    due_date DATE,
    sent_at TIMESTAMP WITH TIME ZONE,
    paid_at TIMESTAMP WITH TIME ZONE,
    pdf_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (number, taxi_company_id)
);

CREATE INDEX idx_invoices_taxi_company ON invoices(taxi_company_id);
CREATE INDEX idx_invoices_client_company ON invoices(client_company_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_period ON invoices(period_from, period_to);

-- Line items — one per ride (or manual)
CREATE TABLE invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    ride_id UUID REFERENCES rides(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity DECIMAL(10,2) NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_ride ON invoice_items(ride_id);

-- Track which invoice a ride is billed on
ALTER TABLE rides ADD COLUMN invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL;
CREATE INDEX idx_rides_invoice_id ON rides(invoice_id);
