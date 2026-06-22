-- Confirmation and rejection tracking columns on the rides table.
-- These are populated by the confirmRide / rejectRide service methods.
ALTER TABLE rides
    ADD COLUMN IF NOT EXISTS confirmed_at      TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS rejection_reason  TEXT,
    ADD COLUMN IF NOT EXISTS rejected_by       UUID REFERENCES persons(id),
    ADD COLUMN IF NOT EXISTS rejected_at       TIMESTAMPTZ;

-- Deduplication table for morning confirmation-request pushes.
-- Mirrors the structure of sent_reminders; cleared on confirm/reject so a
-- re-assigned ride can receive a new request in the next morning window.
CREATE TABLE IF NOT EXISTS sent_confirmation_requests (
    ride_id   UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    person_id UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    sent_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, person_id)
);
