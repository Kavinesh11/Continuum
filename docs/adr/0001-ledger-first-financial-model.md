# ADR 0001: Ledger-First Financial Model

**Status:** Accepted  
**Date:** 2026-04-17  
**Deciders:** Continuum engineering team

## Context

The IRDAI compliance audit recommended creating a `reserve_balance` table. However, `db/migrations/cockroachdb/001_financial_ledger.sql` already contains a single-row `reserve_balance` table, and `004_double_entry_ledger.sql` introduces proper double-entry `ledger_accounts` + `ledger_entries` tables.

The actuarial lab (`historical_backtest.py`, `stress_scenarios.py`) queries a `reserve_balance` table and a `payouts` table. These need to be reconciled with the new double-entry ledger.

## Decision

Port all financial queries to the double-entry ledger as the single source of truth. Create SQL views (`v_reserve_balance`, `v_payouts_flat`) that expose the ledger in the shapes the actuarial code expects, rather than maintaining two competing financial models.

## Consequences

- The `reserve_balance` single-row table in `001_financial_ledger.sql` becomes legacy; new code must not write to it directly.
- All payout and premium transactions must post paired ledger entries (DEBIT one account, CREDIT another).
- The CI gate and stress tests will query views over the ledger, not raw tables.
- Rollback: drop `005_ledger_views.sql` views. The `reserve_balance` table remains as fallback.

## Rollback Procedure

```sql
DROP VIEW IF EXISTS v_reserve_balance;
DROP VIEW IF EXISTS v_payouts_flat;
```

The actuarial lab would need to be reverted to query `reserve_balance` directly.
