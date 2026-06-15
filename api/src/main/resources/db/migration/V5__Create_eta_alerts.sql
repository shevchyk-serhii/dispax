-- ============================================================
-- ETA-at-risk alert deduplication (predictive ETA monitor)
-- ============================================================
-- One row per (ride, driver) once a delay-risk alert has been sent, so the
-- background monitor does not re-alert the dispatcher every tick. Mirrors
-- sent_reminders. Cleared when the ride's pickup time changes.
CREATE TABLE eta_alerts (
    ride_id    UUID        NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    driver_id  UUID        NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    alerted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, driver_id)
);
