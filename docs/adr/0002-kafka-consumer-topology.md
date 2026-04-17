# ADR 0002: Kafka Consumer Topology

**Status:** Accepted  
**Date:** 2026-04-17  
**Deciders:** Continuum engineering team

## Context

The oracle engine publishes events (`payout_authorized`, `enrollment_lock`, `fraud_alert`) to Kafka, but no consumer exists in the core backend. The existing `services/core_backend/src/services/kafka.js` is producer-only. This leaves the trigger-to-payout pipeline broken at the Kafka boundary.

## Decision

Implement a single `KafkaConsumer` dispatcher class in `services/core_backend/src/services/kafkaConsumer.js` with:

- **One consumer group per topic** for independent scaling and offset management.
- **Handler registry pattern:** `register(topic, schema, handler)` so adding a new topic is one file.
- **Idempotency:** Each event carries an `event_id`; processed IDs are stored in a `consumed_events` table. Duplicate messages are silently dropped.
- **JSON Schema validation:** Shared contract schemas in `contracts/oracle_events/` are validated before handler dispatch.
- **DLQ:** Failed messages after retries are forwarded to `<topic>.dlq`.
- **Prometheus metrics:** `kafka_messages_total{topic, status}`, `continuum_kafka_consumer_lag_seconds{topic}`.

Deployed as a separate process `kafkaConsumerMain.js` alongside the existing BullMQ worker process.

## Consequences

- Two long-running Node.js processes in the backend: the Express API server and the Kafka consumer + BullMQ worker.
- Schema changes in oracle_engine must update the shared contract schemas.
- Idempotency table grows; a periodic cleanup job should prune entries older than 7 days.

## Rollback Procedure

Stop the `kafka-consumer` container. Events accumulate in Kafka topics (retained per broker config) and can be replayed once the consumer is restored.
