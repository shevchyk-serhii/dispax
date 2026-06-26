-- Onboarding: users created by a dispatcher/admin get a temporary password and must change it on first login.
-- The flag is set on creation and cleared by changePassword. Existing rows default to FALSE (no forced change).
ALTER TABLE persons
    ADD COLUMN must_change_password BOOLEAN NOT NULL DEFAULT FALSE;