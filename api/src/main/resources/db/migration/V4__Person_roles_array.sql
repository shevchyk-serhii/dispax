-- V4: Add roles array to persons table to support multiple roles per person
-- (e.g. a dispatcher who also drives). The existing `role` column is kept as
-- the primary role and participates in the invariant: role = ANY(roles).

-- Step 1: add the column with a temporary default so the backfill can run
ALTER TABLE persons
    ADD COLUMN roles person_role[] NOT NULL DEFAULT '{}';

-- Step 2: backfill every existing row — primary role must be in the set
UPDATE persons
SET roles = ARRAY[role];

-- Step 3: install a BEFORE INSERT OR UPDATE trigger that auto-populates roles
-- when the caller omits it (or leaves it empty). This lets existing integration
-- tests that do raw `INSERT INTO persons (..., role, ...)` without a `roles`
-- column continue to work: the trigger fires before NOT NULL / CHECK evaluation
-- and sets roles = ARRAY[role], satisfying both constraints automatically.
-- When roles is already provided and non-empty the trigger is a no-op.
CREATE OR REPLACE FUNCTION persons_default_roles()
    RETURNS TRIGGER
    LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.roles IS NULL OR cardinality(NEW.roles) = 0 THEN
        NEW.roles := ARRAY[NEW.role];
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER persons_default_roles
    BEFORE INSERT OR UPDATE ON persons
    FOR EACH ROW EXECUTE FUNCTION persons_default_roles();

-- Step 4: enforce invariants (BEFORE trigger guarantees roles is non-empty and
-- contains the primary role before these checks are evaluated)
ALTER TABLE persons
    ADD CONSTRAINT persons_role_in_roles CHECK (role = ANY(roles));

ALTER TABLE persons
    ADD CONSTRAINT persons_roles_nonempty CHECK (cardinality(roles) >= 1);

-- Step 5: GIN index for efficient ANY(roles) lookups
CREATE INDEX idx_persons_roles ON persons USING GIN (roles);
