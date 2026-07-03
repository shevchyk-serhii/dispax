-- Relax the one-shift-per-driver-per-day rule.
--
-- Cancelling a shift is a soft-delete (the row stays with status = 'Cancelled'),
-- but the status-agnostic UNIQUE (driver_id, date) constraint still counted that
-- row, so re-creating a shift on such a day always failed with 409 while the UI
-- (which hides cancelled shifts) showed the day as empty. The application-level
-- overlap check (validateNoShiftOverlap) already treats cancelled shifts as
-- freeing their slot and allows back-to-back shifts on the same day.
--
-- Replace the constraint with an exclusion constraint that enforces the same
-- rule as the application layer: no two non-cancelled shifts of one driver may
-- overlap in time. Ranges are half-open ([start, end)), so back-to-back shifts
-- touching at a boundary are allowed.

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE schedule_days DROP CONSTRAINT uq_driver_date;

ALTER TABLE schedule_days ADD CONSTRAINT excl_schedule_days_shift_overlap
    EXCLUDE USING gist (
        driver_id WITH =,
        tsrange((date + start_time), (date + end_time)) WITH &&
    ) WHERE (status <> 'Cancelled');
