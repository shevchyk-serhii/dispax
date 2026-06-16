-- Add company lifecycle status and subscription plan to the companies table.
-- These fields are used by the SuperAdmin platform management endpoints.

CREATE TYPE company_status AS ENUM ('Active', 'Suspended', 'Trial', 'Inactive');
CREATE TYPE subscription_plan AS ENUM ('Free', 'Starter', 'Professional', 'Enterprise');

ALTER TABLE companies
  ADD COLUMN IF NOT EXISTS status company_status NOT NULL DEFAULT 'Active';

ALTER TABLE companies
  ADD COLUMN IF NOT EXISTS subscription_plan subscription_plan NOT NULL DEFAULT 'Free';
