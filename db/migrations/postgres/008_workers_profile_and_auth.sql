-- =============================================================================
-- Migration: 008_workers_profile_and_auth.sql
-- Description: Add password_hash, full_name, phone, city, emergency_contact
--              columns to workers table. Also make zone_id nullable so
--              registration can proceed without a pre-assigned zone.
-- =============================================================================

-- Auth column (required for /auth/register and /auth/login)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- Profile columns (populated during registration, editable via PUT /workers/:id)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS emergency_contact TEXT;

-- Make zone_id nullable so registration works without a pre-assigned zone
ALTER TABLE workers ALTER COLUMN zone_id DROP NOT NULL;
ALTER TABLE workers ALTER COLUMN zone_id DROP DEFAULT;
