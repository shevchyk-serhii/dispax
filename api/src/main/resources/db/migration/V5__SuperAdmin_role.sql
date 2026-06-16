-- Add super_admin to the person_role PostgreSQL enum.
-- IF NOT EXISTS makes this idempotent on re-runs.
-- Note: ALTER TYPE ADD VALUE is not transactional in PostgreSQL;
-- Flyway executes it bare (outside a transaction), which is the correct approach.
ALTER TYPE person_role ADD VALUE IF NOT EXISTS 'super_admin';
