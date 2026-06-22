-- Add preferred_language column to persons table.
-- Stores the user-selected UI language (en, de, uk); NULL means default/system locale.
ALTER TABLE persons ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(5);
