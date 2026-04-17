# Reinsurance Arrangement — Skeleton

**Status:** EXTERNAL BLOCKER — requires reinsurer negotiation  
**Acceptance Checklist:**
- [ ] Reinsurer identified and term sheet signed
- [ ] Treaty wording reviewed by legal
- [ ] IRDAI reinsurance cession approval obtained
- [ ] Ledger integration tested (credit `REINSURANCE_RECOVERY` on qualifying payouts)
- [ ] Premium cession automated via scheduled ledger entries

## 1. Proposed Structure

### Excess of Loss (XoL)

| Layer | Retention | Limit | Estimated Rate |
|-------|-----------|-------|----------------|
| Layer 1 | ₹500,000 | ₹2,000,000 | TBD |
| Layer 2 | ₹2,000,000 | ₹5,000,000 | TBD |

**Rationale:** XoL protects against catastrophic correlated events (city-wide cyclone, prolonged monsoon) where simultaneous payouts across all zones would deplete reserves.

### Proportional Quota Share (Alternative)

| Parameter | Value |
|-----------|-------|
| Cession ratio | 20-30% |
| Commission | Negotiable |
| Sliding scale | Based on loss ratio brackets |

**Rationale:** Quota share reduces volatility and provides steady capital relief during sandbox phase when loss history is limited.

## 2. Trigger Events for Reinsurance Recovery

| Event Type | Threshold for Recovery |
|-----------|----------------------|
| Heavy rainfall | > 100mm/6h across ≥ 3 zones simultaneously |
| Cyclone | Any cyclone trigger in Mumbai |
| Compound event | 2+ trigger types within 24h window |
| Portfolio loss | Single-day payouts > ₹500,000 |

## 3. Ledger Integration

When a reinsurance recovery is confirmed:

```sql
-- Debit the reinsurer receivable account
INSERT INTO ledger_entries (entry_id, account_id, amount, direction, reference_type, reference_id)
VALUES (gen_random_uuid(), 'REINSURANCE_RECEIVABLE', recovery_amount, 'debit', 'reinsurance_claim', claim_ref);

-- Credit the reserve main account
INSERT INTO ledger_entries (entry_id, account_id, amount, direction, reference_type, reference_id)
VALUES (gen_random_uuid(), 'RESERVE_MAIN', recovery_amount, 'credit', 'reinsurance_claim', claim_ref);
```

### Cession Premium (Quarterly)

```sql
-- Debit reserve for reinsurance premium cession
INSERT INTO ledger_entries (entry_id, account_id, amount, direction, reference_type, reference_id)
VALUES (gen_random_uuid(), 'RESERVE_MAIN', cession_amount, 'debit', 'reinsurance_cession', period_ref);

-- Credit reinsurance expense account
INSERT INTO ledger_entries (entry_id, account_id, amount, direction, reference_type, reference_id)
VALUES (gen_random_uuid(), 'REINSURANCE_EXPENSE', cession_amount, 'credit', 'reinsurance_cession', period_ref);
```

## 4. Reporting to Reinsurer

| Report | Frequency | Contents |
|--------|-----------|---------|
| Bordereau | Monthly | All trigger events, payouts, zone data |
| Loss development | Quarterly | Cumulative loss ratios by zone and event type |
| Reserve certificate | Annually | Appointed actuary attestation |

## 5. Candidate Reinsurers

| Reinsurer | Notes |
|-----------|-------|
| GIC Re | Indian government reinsurer; mandatory 5% cession |
| Munich Re | Parametric insurance expertise, climate risk |
| Swiss Re | Climate analytics division, parametric products |
| ICICI Lombard Re | Indian market presence |

## 6. Implementation Steps

1. **Stub phase (current):** `REINSURANCE_RECEIVABLE` and `REINSURANCE_EXPENSE` accounts exist in ledger but with zero balances
2. **Term sheet phase:** Negotiate treaty terms, get IRDAI approval
3. **Integration phase:** Automate cession calculation, bordereau generation, recovery posting
4. **Production phase:** Quarterly reconciliation, annual renewal negotiation
