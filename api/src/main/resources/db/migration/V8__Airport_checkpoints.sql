-- 1. Checkpoint column on rides
ALTER TABLE rides
  ADD COLUMN airport_checkpoint VARCHAR(30) DEFAULT NULL;

COMMENT ON COLUMN rides.airport_checkpoint IS
  'Current airport checkpoint for arrival-transfer rides: landed | arrivals_hall | terminal_exit';

-- 2. Dedup table for checkpoint push notifications
CREATE TABLE sent_checkpoint_notifications (
    ride_id         UUID         NOT NULL REFERENCES rides(id)   ON DELETE CASCADE,
    driver_id       UUID         NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    checkpoint_type VARCHAR(50)  NOT NULL,
    sent_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, driver_id, checkpoint_type)
);

CREATE INDEX idx_sent_checkpoint_ride ON sent_checkpoint_notifications(ride_id);
