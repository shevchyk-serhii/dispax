-- GDPR consent tracking
CREATE TABLE IF NOT EXISTS gdpr_consents (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    consent_type VARCHAR(50) NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45),
    UNIQUE(user_id, consent_type)
);

-- GDPR data export/deletion requests
CREATE TABLE IF NOT EXISTS gdpr_requests (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    request_type VARCHAR(20) NOT NULL, -- 'EXPORT' or 'DELETION'
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, PROCESSING, COMPLETED, REJECTED
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT
);

CREATE INDEX idx_gdpr_consents_user ON gdpr_consents(user_id);
CREATE INDEX idx_gdpr_requests_user ON gdpr_requests(user_id);
