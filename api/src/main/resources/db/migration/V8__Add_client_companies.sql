-- Add client_secretary to person_role enum
ALTER TYPE person_role ADD VALUE IF NOT EXISTS 'client_secretary';

-- Create client_companies table
CREATE TABLE client_companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    taxi_company_id UUID NOT NULL REFERENCES companies(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_client_companies_taxi_company ON client_companies(taxi_company_id);

-- Add client_company_id to persons
ALTER TABLE persons
    ADD COLUMN client_company_id UUID REFERENCES client_companies(id);

CREATE INDEX idx_persons_client_company ON persons(client_company_id);
