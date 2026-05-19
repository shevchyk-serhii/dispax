ALTER TABLE client_addresses ADD COLUMN aliases TEXT[] NOT NULL DEFAULT '{}';
