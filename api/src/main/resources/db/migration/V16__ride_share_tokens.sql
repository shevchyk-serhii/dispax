-- Guest tracking links: a public, opaque token grants read-only tracking access
-- to exactly one ride (no JWT). The token value is high-entropy random (NOT a UUID),
-- so possession of it is the only authorization. Cross-tenant by design — scoped to a
-- single ride_id; company_id is denormalized so the public/guest read path needs no
-- second tenant lookup. Depends on V4 (rides).
CREATE TABLE ride_share_tokens (
    id UUID PRIMARY KEY,
    token VARCHAR(64) NOT NULL UNIQUE,
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    company_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX idx_ride_share_tokens_token ON ride_share_tokens(token);
CREATE INDEX idx_ride_share_tokens_ride ON ride_share_tokens(ride_id);
