-- Free-form dispatcher tags/labels on a ride (e.g. "Urgent", "Cash", "Regular").
-- Stored as a text[] array so tags can be filtered with the GIN index. A plain
-- ALTER TABLE ADD COLUMN + non-concurrent CREATE INDEX are transactional, so no
-- executeInTransaction=false .conf is needed (unlike enum ALTER TYPE migrations).
ALTER TABLE rides ADD COLUMN tags text[] NOT NULL DEFAULT '{}';

CREATE INDEX idx_rides_tags ON rides USING gin (tags);
