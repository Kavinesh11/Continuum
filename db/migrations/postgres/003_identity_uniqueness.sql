-- Migration: 003_identity_uniqueness.sql
-- Description: Enforce 1:1 Aadhaar/device binding via UNIQUE constraints
-- Requirements: G5 — identity uniqueness at schema level

-- Add identity columns if not present
ALTER TABLE workers ADD COLUMN IF NOT EXISTS aadhaar_hash TEXT;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS device_fingerprint TEXT;

-- Enforce 1:1 national identity binding — prevents family-member account farming
CREATE UNIQUE INDEX IF NOT EXISTS workers_aadhaar_unique
  ON workers (aadhaar_hash)
  WHERE aadhaar_hash IS NOT NULL;

-- Enforce 1:1 device binding — prevents multi-account-per-device
CREATE UNIQUE INDEX IF NOT EXISTS workers_device_unique
  ON workers (device_fingerprint)
  WHERE device_fingerprint IS NOT NULL;

-- Add consent tracking columns for DPDP Act compliance (medium-controls)
ALTER TABLE workers ADD COLUMN IF NOT EXISTS proximity_consent BOOLEAN DEFAULT FALSE;
ALTER TABLE workers ADD COLUMN IF NOT EXISTS consent_granted_at TIMESTAMPTZ;
