-- CockroachDB Financial Ledger Schema
-- Target: CockroachDB (distributed SQL, Postgres-compatible)
-- Migration: 001_financial_ledger
-- Description: Creates the core financial ledger tables for the Continuum
--              income protection platform: policies, payouts, premium_versions,
--              and reserve_balance.

-- Policies (ACID, distributed)
CREATE TABLE IF NOT EXISTS policies (
  policy_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id           UUID NOT NULL,
  tier                TEXT NOT NULL,
  coverage_cap        DECIMAL(12,2) NOT NULL,
  weekly_premium      DECIMAL(10,2) NOT NULL,
  effective_date      TIMESTAMPTZ NOT NULL,
  claim_eligible_from TIMESTAMPTZ NOT NULL,
  status              TEXT NOT NULL DEFAULT 'pending',
  billing_cycle_start TIMESTAMPTZ NOT NULL,
  billing_cycle_end   TIMESTAMPTZ NOT NULL,
  cancelled_at        TIMESTAMPTZ,
  INDEX policies_worker_id_idx (worker_id),
  INDEX policies_status_billing_cycle_end_idx (status, billing_cycle_end)
);

-- Payouts (immutable ledger rows)
CREATE TABLE IF NOT EXISTS payouts (
  payout_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  worker_id    UUID NOT NULL,
  claim_id     UUID NOT NULL UNIQUE,
  policy_id    UUID NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  oracle_votes JSONB NOT NULL,
  zone_id      TEXT NOT NULL,
  tier         TEXT NOT NULL,
  payu_txn_ref TEXT,
  status       TEXT NOT NULL DEFAULT 'pending',
  disbursed_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  INDEX payouts_worker_id_created_at_idx (worker_id, created_at DESC)
);

-- Premium versions (audit trail)
CREATE TABLE IF NOT EXISTS premium_versions (
  version_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id        UUID NOT NULL,
  effective_date   TIMESTAMPTZ NOT NULL,
  zone_id          TEXT NOT NULL,
  tier             TEXT NOT NULL,
  risk_score       DOUBLE PRECISION NOT NULL,
  computed_premium DECIMAL(10,2) NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Reserve balance constraint (enforced at application layer + DB check)
-- Single-row table (id = 1) tracking the platform's payout reserve.
CREATE TABLE IF NOT EXISTS reserve_balance (
  id         INT PRIMARY KEY DEFAULT 1,
  balance    DECIMAL(14,2) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (balance >= 0)
);

-- Seed the reserve balance row with an initial balance of 0.
-- ON CONFLICT DO NOTHING ensures idempotency on re-runs.
INSERT INTO reserve_balance (id, balance, updated_at)
VALUES (1, 0.00, NOW())
ON CONFLICT (id) DO NOTHING;
