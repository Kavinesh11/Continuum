-- Migration: 005_ledger_views.sql
-- Description: Views over the double-entry ledger for actuarial queries.
-- ADR: docs/adr/0001-ledger-first-financial-model.md
-- Down: DROP VIEW v_reserve_balance; DROP VIEW v_payouts_flat;

CREATE OR REPLACE VIEW v_reserve_balance AS
SELECT
  NOW() AS as_of,
  balance
FROM ledger_accounts
WHERE account_id = 'RESERVE_MAIN';

CREATE OR REPLACE VIEW v_payouts_flat AS
SELECT
  p.payout_id,
  p.worker_id,
  p.claim_id,
  p.policy_id,
  p.amount,
  p.zone_id,
  p.tier,
  p.status,
  p.disbursed_at,
  p.created_at,
  le.entry_id AS ledger_entry_id,
  le.created_at AS ledger_posted_at
FROM payouts p
LEFT JOIN ledger_entries le
  ON le.reference_type = 'payout'
  AND le.reference_id = p.payout_id;
