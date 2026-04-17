# Runbook: Kill Switch Activation

## When to Activate

- Reserve floor breach (< ₹100,000)
- Data breach confirmed (DPDP Act response)
- Payment gateway catastrophic failure
- Regulatory directive to halt operations
- Suspected fraud pattern affecting > 10 workers

## How to Activate

### Global Kill Switch
```bash
# Set env var (immediate effect on next consumer message)
export PAYOUT_KILL_SWITCH=true
# Or restart with env:
docker compose up -d --force-recreate kafka-consumer
```

### Per-Zone Kill Switch
```sql
INSERT INTO zone_kill_switches (zone_id, active, reason, activated_by)
VALUES ('MUM_ANDHERI_W', TRUE, 'Suspected fraud cluster', 'admin@continuum')
ON CONFLICT (zone_id) DO UPDATE SET active = TRUE, reason = EXCLUDED.reason, activated_at = NOW();
```

### Portfolio Daily Cap
```sql
UPDATE portfolio_caps SET max_amount = 100000 WHERE cap_id = 'daily_disbursement';
```

## How to Deactivate

```bash
export PAYOUT_KILL_SWITCH=false
```

```sql
UPDATE zone_kill_switches SET active = FALSE WHERE zone_id = 'MUM_ANDHERI_W';
```

## Monitoring

- Dropped events are logged as `[payout-handler] KILL_SWITCH active`
- Kafka messages are NOT lost — they remain unconsumed until the switch is deactivated
- After deactivation, accumulated events will process (expect a burst)
