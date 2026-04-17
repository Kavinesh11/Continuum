# Runbook: Reserve Floor Breach

**Alert:** `ReserveFloorBreach` / `ReserveLow`  
**Threshold:** Reserve balance < ₹100,000

## Triage

1. Check current reserve: `SELECT balance FROM ledger_accounts WHERE account_id = 'RESERVE_MAIN';`
2. Check recent payout volume: `SELECT SUM(amount) FROM payouts WHERE created_at > NOW() - INTERVAL '24 hours';`
3. Check if kill switch is active: `echo $PAYOUT_KILL_SWITCH`

## Immediate Actions

1. **Activate kill switch:** Set `PAYOUT_KILL_SWITCH=true` to halt automated payouts
2. **Notify treasury:** Initiate reserve top-up procedure
3. **Review stress test:** Run `python -m services.actuarial_lab.stress_scenarios` for updated depletion estimate

## Root Cause Analysis

| Cause | Indicator | Fix |
|-------|-----------|-----|
| Premium collection shortfall | `weekly_premiums_collected` metric flat | Check mandate debit failures, BullMQ queue |
| Catastrophic event payout surge | Many payouts in 24h window | Expected; activate kill switch, top up reserve |
| Missing reinsurance offset | No reinsurance credits in ledger | Escalate to reinsurance team |

## Recovery

1. Top up reserve via manual `creditReserve()` call or bank transfer
2. Deactivate kill switch: `PAYOUT_KILL_SWITCH=false`
3. Monitor for 1 hour to ensure stability
