-- Merge users table into persons table
-- After this migration, persons is the single source of truth for all user/person data

-- Step 1: Add new columns to persons (from users table)
ALTER TABLE persons ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED'));
ALTER TABLE persons ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;

-- Step 2: Backfill password_hash and status from users for matched emails
UPDATE persons p
SET password_hash = u.password_hash,
    status = u.status,
    last_login_at = u.last_login_at
FROM users u
WHERE LOWER(p.email) = LOWER(u.email);

-- Set placeholder hash for persons without a matching user (cannot login until password reset)
UPDATE persons
SET password_hash = '$2a$12$PLACEHOLDER_NEEDS_RESET_000000000000000000000000000'
WHERE password_hash IS NULL;

-- Make password_hash NOT NULL
ALTER TABLE persons ALTER COLUMN password_hash SET NOT NULL;

-- Step 3: Create persons for users that have no matching person
INSERT INTO persons (id, name, email, role, company_id, password_hash, phone, status, last_login_at)
SELECT
    u.id,
    u.name,
    u.email,
    LOWER(u.role)::person_role,
    u.company_id,
    u.password_hash,
    u.phone,
    u.status,
    u.last_login_at
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM persons p WHERE LOWER(p.email) = LOWER(u.email)
);

-- Step 4: Create ID mapping for FK migration (users with matching persons but different IDs)
CREATE TEMPORARY TABLE user_to_person_id_map AS
SELECT u.id AS user_id, p.id AS person_id
FROM users u
JOIN persons p ON LOWER(u.email) = LOWER(p.email)
WHERE u.id != p.id;

-- Step 5: Migrate FK references from users(id) to persons(id)

-- tokens
ALTER TABLE tokens DROP CONSTRAINT IF EXISTS tokens_user_id_fkey;
UPDATE tokens t
SET user_id = m.person_id
FROM user_to_person_id_map m
WHERE t.user_id = m.user_id;
ALTER TABLE tokens ADD CONSTRAINT tokens_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES persons(id) ON DELETE CASCADE;

-- sessions
ALTER TABLE sessions DROP CONSTRAINT IF EXISTS sessions_user_id_fkey;
UPDATE sessions s
SET user_id = m.person_id
FROM user_to_person_id_map m
WHERE s.user_id = m.user_id;
ALTER TABLE sessions ADD CONSTRAINT sessions_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES persons(id);

-- gdpr_consents
ALTER TABLE gdpr_consents DROP CONSTRAINT IF EXISTS gdpr_consents_user_id_fkey;
ALTER TABLE gdpr_consents DROP CONSTRAINT IF EXISTS gdpr_consents_user_id_consent_type_key;
UPDATE gdpr_consents gc
SET user_id = m.person_id
FROM user_to_person_id_map m
WHERE gc.user_id = m.user_id;
ALTER TABLE gdpr_consents ADD CONSTRAINT gdpr_consents_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES persons(id);
ALTER TABLE gdpr_consents ADD CONSTRAINT gdpr_consents_user_id_consent_type_key
    UNIQUE (user_id, consent_type);

-- gdpr_requests
ALTER TABLE gdpr_requests DROP CONSTRAINT IF EXISTS gdpr_requests_user_id_fkey;
UPDATE gdpr_requests gr
SET user_id = m.person_id
FROM user_to_person_id_map m
WHERE gr.user_id = m.user_id;
ALTER TABLE gdpr_requests ADD CONSTRAINT gdpr_requests_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES persons(id);

-- Step 6: Add index for new column
CREATE INDEX IF NOT EXISTS idx_persons_status ON persons(status);

-- Step 7: Drop the users table
DROP TABLE users CASCADE;
