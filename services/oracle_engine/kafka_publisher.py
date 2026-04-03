"""
Async Kafka publisher for oracle trigger and payout authorized events.
"""
from __future__ import annotations

import json
import os
import uuid
from dataclasses import asdict
from datetime import datetime, timezone

import structlog
from aiokafka import AIOKafkaProducer

from .engine import VoteResult
from .oracles import OracleVote

logger = structlog.get_logger(__name__)

ORACLE_TRIGGER_TOPIC = "oracle_trigger"
PAYOUT_AUTHORIZED_TOPIC = "payout_authorized"


def _vote_to_dict(vote: OracleVote) -> dict:
    return {
        "oracle_name": vote.oracle_name,
        "vote": vote.vote,
        "data_timestamp": vote.data_timestamp.isoformat() if vote.data_timestamp else None,
        "polled_at": vote.polled_at.isoformat(),
        "tls_valid": vote.tls_valid,
    }


class KafkaPublisher:
    def __init__(self, bootstrap_servers: str | None = None) -> None:
        self._bootstrap = bootstrap_servers or os.environ.get(
            "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"
        )
        self._producer: AIOKafkaProducer | None = None

    async def start(self) -> None:
        self._producer = AIOKafkaProducer(
            bootstrap_servers=self._bootstrap,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        )
        await self._producer.start()
        logger.info("kafka_producer_started", bootstrap=self._bootstrap)

    async def stop(self) -> None:
        if self._producer:
            await self._producer.stop()
            logger.info("kafka_producer_stopped")

    async def publish_oracle_trigger(
        self,
        result: VoteResult,
        zone_id: str,
        event_type: str,
    ) -> None:
        """Publish oracle_trigger event with full vote breakdown."""
        if self._producer is None:
            raise RuntimeError("KafkaPublisher not started")

        event = {
            "event_id": str(uuid.uuid4()),
            "zone_id": zone_id,
            "event_type": event_type,
            "oracle_votes": [_vote_to_dict(v) for v in result.votes],
            "payout_cap": result.payout_cap,
            "triggered_at": datetime.now(timezone.utc).isoformat(),
            "benefit_of_doubt": result.benefit_of_doubt,
        }
        await self._producer.send_and_wait(ORACLE_TRIGGER_TOPIC, event)
        logger.info(
            "oracle_trigger_published",
            zone_id=zone_id,
            event_type=event_type,
            payout_cap=result.payout_cap,
        )

    async def publish_payout_authorized(
        self,
        result: VoteResult,
        zone_id: str,
        event_type: str,
        payout_amount: float | None = None,
        claim_id: str | None = None,
        worker_id: str | None = None,
    ) -> None:
        """Publish payout_authorized event with full oracle vote breakdown.

        claim_id and worker_id are optional — the Oracle Consensus Engine publishes
        zone-level parametric trigger payouts where individual claim context may not
        yet be available. Downstream BullMQ workers resolve per-worker payouts.
        """
        if self._producer is None:
            raise RuntimeError("KafkaPublisher not started")

        event = {
            "payout_id": str(uuid.uuid4()),
            "claim_id": claim_id,
            "worker_id": worker_id,
            "amount": payout_amount,
            "zone_id": zone_id,
            "oracle_votes": [_vote_to_dict(v) for v in result.votes],
            "authorized_at": datetime.now(timezone.utc).isoformat(),
            "payout_cap": result.payout_cap,
            "benefit_of_doubt": result.benefit_of_doubt,
        }
        await self._producer.send_and_wait(PAYOUT_AUTHORIZED_TOPIC, event)
        logger.info(
            "payout_authorized_published",
            zone_id=zone_id,
            payout_cap=result.payout_cap,
        )
