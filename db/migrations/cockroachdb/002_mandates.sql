-- Migration: 002_mandates.sql
-- Description: UPI eNACH mandate table for recurring premium collection
-- Requirements: G2 — frictionless premium collection

CREATE TABLE IF NOT EXISTS mandates (
  mandate_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id          UUID NOT NULL,
  policy_id          UUID NOT NULL REFERENCES policies(policy_id),
  provider           TEXT NOT NULL DEFAULT 'payu_enach',
  upi_id             TEXT NOT NULL,
  max_amount         DECIMAL(10,2) NOT NULL,
  frequency          TEXT NOT NULL DEFAULT 'weekly',
  provider_ref       TEXT,
  status             TEXT NOT NULL DEFAULT 'created'
                     CHECK (status IN ('created','approved','active','paused','revoked','failed')),
  approved_at        TIMESTAMPTZ,
  revoked_at         TIMESTAMPTZ,
  last_debit_at      TIMESTAMPTZ,
  last_debit_status  TEXT CHECK (last_debit_status IN ('success','failed','pending')),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  INDEX mandates_worker_idx (worker_id),
  INDEX mandates_policy_idx (policy_id),
  INDEX mandates_status_idx (status)
);

-- Debit history for audit trail
CREATE TABLE IF NOT EXISTS mandate_debits (
  debit_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mandate_id     UUID NOT NULL REFERENCES mandates(mandate_id),
  policy_id      UUID NOT NULL,
  worker_id      UUID NOT NULL,
  amount         DECIMAL(10,2) NOT NULL,
  provider_txn   TEXT,
  status         TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','success','failed')),
  attempted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  settled_at     TIMESTAMPTZ,
  failure_reason TEXT,
  INDEX debits_mandate_idx (mandate_id, attempted_at DESC),
  INDEX debits_worker_idx (worker_id, attempted_at DESC)
);
