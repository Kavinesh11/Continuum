-- Migration: 006_consent_receipts.sql
-- Description: DPDP Act 2023 consent management
-- Down: DROP TABLE IF EXISTS consent_receipts;

CREATE TABLE IF NOT EXISTS consent_receipts (
  receipt_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id        UUID NOT NULL REFERENCES workers(worker_id),
  purpose          TEXT NOT NULL,
  template_version TEXT NOT NULL DEFAULT 'v1',
  granted_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at       TIMESTAMPTZ,
  UNIQUE (worker_id, purpose)
);

CREATE INDEX IF NOT EXISTS consent_receipts_worker_idx
  ON consent_receipts (worker_id, purpose);
