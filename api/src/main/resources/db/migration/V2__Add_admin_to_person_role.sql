-- Add 'admin' value to person_role enum
ALTER TYPE person_role ADD VALUE IF NOT EXISTS 'admin';
