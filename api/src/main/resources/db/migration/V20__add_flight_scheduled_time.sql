-- Flight delay needs both the scheduled and the live/estimated arrival time.
-- `flight_time` already holds the latest known (estimated, else scheduled) instant; this adds the
-- separately-tracked scheduled time so the card can show the delay = flight_time - flight_scheduled_time.
-- The background flight monitor (FlightStatusMonitor) populates both columns from the airport board,
-- which reports them distinctly. NULL when no flight data has been fetched yet.
ALTER TABLE rides ADD COLUMN IF NOT EXISTS flight_scheduled_time TIMESTAMP WITH TIME ZONE;
