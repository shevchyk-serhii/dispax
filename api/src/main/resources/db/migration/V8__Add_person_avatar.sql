-- V8: Add profile photo columns to persons table.
-- Both columns are nullable: NULL avatar means no photo has been uploaded.
-- Retrieval is always by primary key (PK) so no index is needed on BYTEA.

ALTER TABLE persons
    ADD COLUMN IF NOT EXISTS avatar BYTEA,
    ADD COLUMN IF NOT EXISTS avatar_content_type TEXT;
