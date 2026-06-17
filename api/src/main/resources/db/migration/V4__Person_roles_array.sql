-- V4: Add roles array to persons table to support multiple roles per person
-- (e.g. a dispatcher who also drives). The existing `role` column is kept as
-- the primary role and participates in the invariant: role = ANY(roles).

-- Step 1: add the column with a temporary default so the backfill can run
ALTER TABLE persons
    ADD COLUMN roles person_role[] NOT NULL DEFAULT '{}';

-- Step 2: backfill every existing row — primary role must be in the set
UPDATE persons
SET roles = ARRAY[role];

-- Step 3: remove the default so future INSERTs must supply roles explicitly
ALTER TABLE persons
    ALTER COLUMN roles DROP DEFAULT;

-- Step 4: enforce invariants
ALTER TABLE persons
    ADD CONSTRAINT persons_role_in_roles CHECK (role = ANY(roles));

ALTER TABLE persons
    ADD CONSTRAINT persons_roles_nonempty CHECK (cardinality(roles) >= 1);

-- Step 5: GIN index for efficient ANY(roles) lookups
CREATE INDEX idx_persons_roles ON persons USING GIN (roles);
