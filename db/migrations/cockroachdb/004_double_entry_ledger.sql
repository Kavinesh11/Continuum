-- Migration: 004_double_entry_ledger.sql
-- Description: Replace single-row reserve_balance with double-entry ledger
-- Requirements: R6 — eliminate overdraw race on concurrent payouts

-- Ledger accounts: each account has a type and a running balance
CREATE TABLE IF NOT EXISTS ledger_accounts (
  account_id   TEXT PRIMARY KEY,
  account_type TEXT NOT NULL CHECK (account_type IN ('reserve', 'premium_income', 'payout_expense', 'reinsurance')),
  balance      DECIMAL(14,2) NOT NULL DEFAULT 0,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed core accounts
INSERT INTO ledger_accounts (account_id, account_type, balance) VALUES
  ('RESERVE_MAIN', 'reserve', 0.00),
  ('PREMIUM_INCOME', 'premium_income', 0.00),
  ('PAYOUT_EXPENSE', 'payout_expense', 0.00),
  ('REINSURANCE_FUND', 'reinsurance', 0.00)
ON CONFLICT (account_id) DO NOTHING;

-- Immutable ledger entries — every financial movement is a double-entry
CREATE TABLE IF NOT EXISTS ledger_entries (
  entry_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debit_account TEXT NOT NULL REFERENCES ledger_accounts(account_id),
  credit_account TEXT NOT NULL REFERENCES ledger_accounts(account_id),
  amount        DECIMAL(14,2) NOT NULL CHECK (amount > 0),
  reference_type TEXT NOT NULL,
  reference_id  UUID NOT NULL,
  description   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  INDEX ledger_entries_debit_idx (debit_account, created_at DESC),
  INDEX ledger_entries_credit_idx (credit_account, created_at DESC),
  INDEX ledger_entries_ref_idx (reference_type, reference_id)
);
