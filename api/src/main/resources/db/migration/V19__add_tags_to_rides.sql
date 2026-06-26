-- Free-form dispatcher tags/labels on a ride (e.g. "Urgent", "Cash", "Regular").
-- Stored as a text[] array so tags can be filtered with the GIN index. A plain
-- ALTER TABLE ADD COLUMN + non-concurrent CREATE INDEX are transactional, so no
-- executeInTransaction=false .conf is needed (unlike enum ALTER TYPE migrations).
-- IF NOT EXISTS keeps the migration idempotent on a reused test container that
-- may already carry the column from an earlier run (matches V11/V14 style).
ALTER TABLE rides ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_rides_tags ON rides USING gin (tags);
