"""
Kafka consumer for `claim_decision` topic.

Listens for messages with status == "FRAUD_QUEUE" and triggers
process_fraud_queue_claim within 60 seconds of receipt.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os

from aiokafka import AIOKafkaConsumer

from .crew_ai_orchestrator import (
    FRAUD_QUEUE_ASSIGNMENT_TIMEOUT_S,
    process_fraud_queue_claim,
)

logger = logging.getLogger(__name__)

TOPIC = "claim_decision"
GROUP_ID = "crew_ai_orchestrator"


async def _handle_message(message_value: dict) -> None:
    """Dispatch a FRAUD_QUEUE claim to the orchestrator."""
    claim_id = message_value.get("claim_id")
    if not claim_id:
        logger.warning("Received claim_decision message without claim_id: %s", message_value)
        return

    logger.info("claim_id=%s dispatching to fraud_signal_aggregation", claim_id)
    try:
        report = await process_fraud_queue_claim(claim_id, message_value)
        logger.info(
            "claim_id=%s analysis complete confidence=%.3f recommendation=%s",
            claim_id,
            report.confidence,
            report.recommendation,
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("claim_id=%s orchestration failed: %s", claim_id, exc)


async def run_consumer() -> None:
    """Start the Kafka consumer loop. Runs indefinitely."""
    bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    consumer = AIOKafkaConsumer(
        TOPIC,
        bootstrap_servers=bootstrap_servers,
        group_id=GROUP_ID,
        value_deserializer=lambda b: json.loads(b.decode("utf-8")),
        auto_offset_reset="latest",
    )
    await consumer.start()
    logger.info("Kafka consumer started on topic=%s group=%s", TOPIC, GROUP_ID)

    try:
        async for msg in consumer:
            value = msg.value
            if not isinstance(value, dict):
                continue
            if value.get("status") != "FRAUD_QUEUE":
                continue

            # Enforce 60-second assignment SLA: schedule as a task immediately
            asyncio.create_task(
                asyncio.wait_for(
                    _handle_message(value),
                    timeout=FRAUD_QUEUE_ASSIGNMENT_TIMEOUT_S,
                )
            )
    finally:
        await consumer.stop()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(run_consumer())
