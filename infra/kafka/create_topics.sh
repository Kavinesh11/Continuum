#!/usr/bin/env bash
# Feature: continuum-ml-pipelines
# Creates all Kafka topics required by the Continuum platform.
# Requirements: 7.1, 7.2, 7.3

set -euo pipefail

KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092}"
RETENTION_MS=604800000  # 7 days
PARTITIONS=3
REPLICATION_FACTOR="${KAFKA_REPLICATION_FACTOR:-1}"

TOPICS=(
  "worker_onboarding"
  "claim_submitted"
  "claim_decision"
  "payout_authorized"
  "oracle_trigger"
  "premium_updated"
  "fraud_alert"
  "adverse_selection_lock"
)

echo "Using Kafka bootstrap servers: ${KAFKA_BOOTSTRAP_SERVERS}"
echo "Creating ${#TOPICS[@]} topics (RF=${REPLICATION_FACTOR}) with 7-day retention..."
echo ""

for TOPIC in "${TOPICS[@]}"; do
  kafka-topics.sh \
    --bootstrap-server "${KAFKA_BOOTSTRAP_SERVERS}" \
    --create \
    --if-not-exists \
    --topic "${TOPIC}" \
    --partitions "${PARTITIONS}" \
    --replication-factor "${REPLICATION_FACTOR}" \
    --config "retention.ms=${RETENTION_MS}" \
    --config "cleanup.policy=delete"

  echo "✓ Topic created (or already exists): ${TOPIC}"
done

echo ""
echo "All topics ready."
