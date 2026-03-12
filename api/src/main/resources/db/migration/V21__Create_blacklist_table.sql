-- Client/Driver blacklist for conflict avoidance
CREATE TABLE IF NOT EXISTS blacklist_entries (
    id UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES companies(id),
    client_id UUID NOT NULL REFERENCES persons(id),
    driver_id UUID NOT NULL REFERENCES persons(id),
    reason TEXT,
    created_by UUID NOT NULL REFERENCES persons(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(client_id, driver_id)
);

CREATE INDEX idx_blacklist_company ON blacklist_entries(company_id);
CREATE INDEX idx_blacklist_client ON blacklist_entries(client_id);
CREATE INDEX idx_blacklist_driver ON blacklist_entries(driver_id);

-- Emergency reassignment log
CREATE TABLE IF NOT EXISTS emergency_reassignments (
    id UUID PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES rides(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    original_driver_id UUID NOT NULL REFERENCES persons(id),
    new_driver_id UUID REFERENCES persons(id),
    reason VARCHAR(50) NOT NULL,
    notes TEXT,
    reassigned_by UUID NOT NULL REFERENCES persons(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
);

CREATE INDEX idx_emergency_reassign_ride ON emergency_reassignments(ride_id);
CREATE INDEX idx_emergency_reassign_company ON emergency_reassignments(company_id);

-- Add VIP priority and preferred driver fields (already exist on persons, add to rides for tracking)
ALTER TABLE rides ADD COLUMN IF NOT EXISTS is_vip_ride BOOLEAN DEFAULT FALSE;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS preferred_driver_used BOOLEAN DEFAULT FALSE;
