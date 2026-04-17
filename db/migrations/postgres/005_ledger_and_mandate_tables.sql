-- =============================================================================
-- Migration: 005_ledger_and_mandate_tables.sql
-- Description: Double-entry ledger, UPI mandate lifecycle, and payout tables
-- Requirements: 9.2, 9.3, 9.5, G2, R6
-- =============================================================================

-- =============================================================================
-- ledger_accounts — Chart of accounts for double-entry reserve management
-- Seeded with three required accounts: RESERVE_MAIN, PREMIUM_INCOME, PAYOUT_EXPENSE
-- =============================================================================
CREATE TABLE IF NOT EXISTS ledger_accounts (
    account_id   TEXT PRIMARY KEY,
    account_type TEXT NOT NULL CHECK (account_type IN ('asset', 'liability', 'income', 'expense')),
    balance      NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed required accounts (idempotent)
INSERT INTO ledger_accounts (account_id, account_type, balance)
VALUES
    ('RESERVE_MAIN',   'asset',   0.00),
    ('PREMIUM_INCOME', 'income',  0.00),
    ('PAYOUT_EXPENSE', 'expense', 0.00)
ON CONFLICT (account_id) DO NOTHING;

-- =============================================================================
-- ledger_entries — Immutable double-entry ledger journal
-- Every financial transaction produces exactly one entry with debit + credit
-- =============================================================================
CREATE TABLE IF NOT EXISTS ledger_entries (
    entry_id       BIGSERIAL PRIMARY KEY,
    debit_account  TEXT NOT NULL REFERENCES ledger_accounts(account_id),
    credit_account TEXT NOT NULL REFERENCES ledger_accounts(account_id),
    amount         NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    reference_type TEXT NOT NULL,          -- 'payout', 'premium', 'adjustment'
    reference_id   TEXT NOT NULL,          -- payout_id, debit_id, etc.
    description    TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ledger_no_self_transfer CHECK (debit_account != credit_account)
);

CREATE INDEX IF NOT EXISTS ledger_entries_ref_idx
    ON ledger_entries (reference_type, reference_id);
CREATE INDEX IF NOT EXISTS ledger_entries_debit_idx
    ON ledger_entries (debit_account, created_at DESC);
CREATE INDEX IF NOT EXISTS ledger_entries_credit_idx
    ON ledger_entries (credit_account, created_at DESC);

-- =============================================================================
-- reserve_balance — Legacy single-row reserve balance (backward compat)
-- Used by actuarial_lab stress_scenarios.py
-- =============================================================================
CREATE TABLE IF NOT EXISTS reserve_balance (
    id      INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    balance NUMERIC(15, 2) NOT NULL DEFAULT 0.00
);

INSERT INTO reserve_balance (id, balance) VALUES (1, 0.00)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- mandates — UPI eNACH mandate lifecycle
-- Requirements: G2 — frictionless premium collection
-- =============================================================================
CREATE TABLE IF NOT EXISTS mandates (
    mandate_id        UUID PRIMARY KEY,
    worker_id         UUID NOT NULL REFERENCES workers(worker_id),
    policy_id         UUID NOT NULL,
    upi_id            TEXT NOT NULL,
    max_amount        NUMERIC(10, 2) NOT NULL,
    provider_ref      TEXT,                -- PayU mandate reference
    status            TEXT NOT NULL DEFAULT 'created'
                      CHECK (status IN ('created', 'approved', 'active', 'paused', 'revoked', 'failed')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at       TIMESTAMPTZ,
    revoked_at        TIMESTAMPTZ,
    last_debit_at     TIMESTAMPTZ,
    last_debit_status TEXT CHECK (last_debit_status IN ('success', 'failed') OR last_debit_status IS NULL)
);

CREATE INDEX IF NOT EXISTS mandates_policy_idx ON mandates (policy_id);
CREATE INDEX IF NOT EXISTS mandates_worker_idx ON mandates (worker_id);

-- =============================================================================
-- mandate_debits — Individual debit attempts against mandates
-- =============================================================================
CREATE TABLE IF NOT EXISTS mandate_debits (
    debit_id       UUID PRIMARY KEY,
    mandate_id     UUID NOT NULL REFERENCES mandates(mandate_id),
    policy_id      UUID NOT NULL,
    worker_id      UUID NOT NULL REFERENCES workers(worker_id),
    amount         NUMERIC(10, 2) NOT NULL,
    provider_txn   TEXT,                   -- PayU transaction reference
    status         TEXT NOT NULL CHECK (status IN ('success', 'failed', 'pending')),
    failure_reason TEXT,
    attempted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS mandate_debits_mandate_idx
    ON mandate_debits (mandate_id, attempted_at DESC);

-- =============================================================================
-- payouts — Extend with missing columns if table already exists
-- The initial schema may have a minimal payouts table; ensure all columns exist
-- =============================================================================
CREATE TABLE IF NOT EXISTS payouts (
    payout_id    UUID PRIMARY KEY,
    worker_id    UUID NOT NULL REFERENCES workers(worker_id),
    claim_id     UUID REFERENCES claims(claim_id),
    policy_id    UUID,
    amount       NUMERIC(10, 2) NOT NULL,
    oracle_votes JSONB,
    zone_id      TEXT,
    tier         TEXT,
    payu_txn_ref TEXT,
    status       TEXT NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending', 'disbursed', 'failed', 'held_sim_change')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    disbursed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS payouts_worker_created_idx
    ON payouts (worker_id, created_at DESC);
CREATE INDEX IF NOT EXISTS payouts_claim_idx
    ON payouts (claim_id);
CREATE INDEX IF NOT EXISTS payouts_zone_status_idx
    ON payouts (zone_id, status, created_at DESC);
