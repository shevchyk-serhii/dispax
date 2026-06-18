-- V7: Add preferred_language column to client_companies table.
-- Nullable (no DEFAULT) — existing rows get NULL, which maps to None in Scala
-- and triggers the config default (EMAIL_DEFAULT_LANG, default "de").
-- Zero-downtime: ADD COLUMN IF NOT EXISTS is safe on live tables.

ALTER TABLE client_companies
  ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(5);
