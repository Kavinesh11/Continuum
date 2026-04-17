# Runbook: Payout Latency SLA Breach

**Alert:** `PayoutLatencyBurnRate1h` / `PayoutSLABreach`  
**SLA:** Trigger-to-UPI-credit < 2 hours (7200s) at p95

## Triage

1. Check Grafana "Payout Latency SLO" panel for trend
2. Query: `SELECT payout_id, created_at, disbursed_at, EXTRACT(EPOCH FROM (disbursed_at - created_at)) AS latency_s FROM payouts WHERE disbursed_at IS NOT NULL ORDER BY latency_s DESC LIMIT 10;`
3. Check Kafka consumer lag: `continuum_kafka_consumer_lag_seconds` gauge

## Common Causes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Consumer lag high | Kafka consumer crash/restart | Check consumer pod logs, restart if needed |
| Payout stuck in `pending` | BullMQ worker backed up | Scale worker replicas, check Redis memory |
| PayU timeout | PayU API degraded | Check PayU status page, consider kill-switch |
| Ledger lock contention | High concurrent payout volume | Monitor `pg_locks`, consider sharding |

## Escalation

If p95 > 4 hours, activate `PAYOUT_KILL_SWITCH=true` and escalate to on-call.
