-- FCM tokens were not tied to a company, so findByPersonId could return tokens
-- of a person regardless of tenant context -- a cross-tenant push risk.
-- Add company_id, backfill from the owning person, then enforce NOT NULL.

ALTER TABLE fcm_tokens ADD COLUMN company_id UUID REFERENCES companies(id);

-- Backfill the company from the token's owning person. persons.person_id is a
-- NOT NULL FK, so every token has an owner.
UPDATE fcm_tokens t
SET company_id = p.company_id
FROM persons p
WHERE t.person_id = p.id;

-- persons.company_id is nullable (e.g. cross-tenant SuperAdmin users). A token
-- whose owner has no company cannot be delivered within a tenant context, so it
-- is removed rather than left with a NULL company_id.
DELETE FROM fcm_tokens WHERE company_id IS NULL;

ALTER TABLE fcm_tokens ALTER COLUMN company_id SET NOT NULL;

CREATE INDEX idx_fcm_tokens_company ON fcm_tokens(company_id);
CREATE INDEX idx_fcm_tokens_person_company ON fcm_tokens(person_id, company_id);
