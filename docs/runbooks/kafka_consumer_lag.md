# Runbook: Kafka Consumer Lag

**Alert:** `KafkaConsumerLagBurnRate1h`  
**SLO:** Consumer lag p95 < 60s over 7d

## Triage

1. Check `continuum_kafka_consumer_lag_seconds` by topic
2. Check consumer group status: `kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group continuum-consumer-payout_authorized`
3. Check consumer pod logs for errors

## Common Causes

| Symptom | Cause | Fix |
|---------|-------|-----|
| All topics lagging | Consumer pod crashed | Restart `kafka-consumer` container |
| Single topic lagging | Handler error causing retries | Check DLQ depth, fix handler bug |
| Lag growing steadily | Producer throughput > consumer capacity | Scale consumer instances |

## Remediation

- If DLQ is growing: inspect dead-letter messages, fix root cause, replay from DLQ
- If consumer is crashed: restart; Kafka offset tracking ensures no message loss
- Emergency: increase consumer instances via `docker compose up --scale kafka-consumer=3`
