-- Cross-company personal calendar sharing.
-- A driver/dispatcher (grantor) mints an opaque invite token; a user of another
-- (or the same) company redeems it while logged in, producing a persistent grant
-- that authorizes a PII-free read of the grantor's personal calendar.
-- Depends on V1 (companies, persons).

-- ============================================================
-- Calendar share invites
-- ============================================================
-- The token is high-entropy and non-enumerable (NOT a UUID) — possession plus a
-- valid JWT is what redeems it. grantor_company_id is denormalized (same idea as
-- ride_share_tokens.company_id) so grant creation needs no second tenant lookup.
CREATE TABLE calendar_share_invites (
    id UUID PRIMARY KEY,
    token VARCHAR(64) NOT NULL,
    grantor_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    grantor_company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE
);

CREATE UNIQUE INDEX uq_calendar_share_invites_token ON calendar_share_invites(token);
CREATE INDEX idx_calendar_share_invites_grantor ON calendar_share_invites(grantor_person_id);

-- ============================================================
-- Calendar share grants
-- ============================================================
-- Soft-revoked (revoked_at) so history survives; the partial unique index below
-- still guarantees at most one ACTIVE grant per (grantor, grantee) pair.
CREATE TABLE calendar_share_grants (
    id UUID PRIMARY KEY,
    invite_id UUID REFERENCES calendar_share_invites(id) ON DELETE SET NULL,
    grantor_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    grantor_company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    grantee_person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    grantee_company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_calendar_share_grant_not_self CHECK (grantor_person_id <> grantee_person_id)
);

CREATE UNIQUE INDEX uq_calendar_share_grants_active
    ON calendar_share_grants(grantor_person_id, grantee_person_id)
    WHERE revoked_at IS NULL;
CREATE INDEX idx_calendar_share_grants_grantee ON calendar_share_grants(grantee_person_id);
CREATE INDEX idx_calendar_share_grants_grantor ON calendar_share_grants(grantor_person_id);

-- Busy-slot derivation reads a driver's rides by (driver_id, pickup_datetime);
-- rides so far only had a single-column driver_id index.
CREATE INDEX idx_rides_driver_pickup ON rides(driver_id, pickup_datetime);
