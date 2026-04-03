# Feature: continuum-ml-pipelines
"""
RiskScoreRepository: persists Risk_Score records to PostgreSQL and publishes
premium_updated events to Kafka.

Persistence contract:
  1. INSERT into risk_scores table (asyncpg-style $N parameters).
  2. Only on successful INSERT: publish premium_updated event to Kafka.
  3. If INSERT fails: raise exception, do NOT publish.
  4. If Kafka publish fails: log error, do NOT rollback the DB write
     (at-least-once delivery guarantee).

Requirements: 1.11, 2.6
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Protocol

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Kafka topic
# ---------------------------------------------------------------------------

_PREMIUM_UPDATED_TOPIC = "premium_updated"

# ---------------------------------------------------------------------------
# Protocols (injected for testability)
# ---------------------------------------------------------------------------


class DBPool(Protocol):
    """Minimal asyncpg-compatible connection pool interface."""

    async def execute(self, query: str, *args) -> None: ...


class KafkaProducer(Protocol):
    """Minimal Kafka producer interface."""

    async def send(self, topic: str, value: dict) -> None: ...


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class RiskScoreRecord:
    """All data required to persist a risk score and publish the Kafka event."""

    score_id: str          # UUID string
    worker_id: str         # UUID string
    policy_id: str         # UUID string
    risk_score: float      # [0.0, 1.0]
    feature_vector: list[float]   # 15-dimensional
    final_premium: Decimal
    model_version: str
    computed_at: datetime
    old_premium: Decimal   # used in the Kafka event only


# ---------------------------------------------------------------------------
# Repository
# ---------------------------------------------------------------------------


class RiskScoreRepository:
    """
    Persists a RiskScoreRecord to PostgreSQL and publishes a premium_updated
    Kafka event.

    Args:
        db_pool:       Injected asyncpg pool (or compatible mock).
        kafka_producer: Injected Kafka producer (or compatible mock).
    """

    def __init__(self, db_pool: DBPool, kafka_producer: KafkaProducer) -> None:
        self._db = db_pool
        self._kafka = kafka_producer

    async def save_and_publish(self, record: RiskScoreRecord) -> None:
        """
        Persist the risk score to PostgreSQL, then publish premium_updated.

        Raises:
            Exception: propagated from asyncpg if the INSERT fails.
                       In that case the Kafka event is NOT published.
        """
        await self._insert_risk_score(record)
        await self._publish_premium_updated(record)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _insert_risk_score(self, record: RiskScoreRecord) -> None:
        """INSERT into risk_scores using asyncpg $N parameterized query."""
        query = """
            INSERT INTO risk_scores (
                score_id,
                worker_id,
                policy_id,
                risk_score,
                feature_vector,
                final_premium,
                model_version,
                computed_at
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        """
        await self._db.execute(
            query,
            record.score_id,
            record.worker_id,
            record.policy_id,
            record.risk_score,
            record.feature_vector,
            record.final_premium,
            record.model_version,
            record.computed_at,
        )

    async def _publish_premium_updated(self, record: RiskScoreRecord) -> None:
        """
        Publish premium_updated event to Kafka.

        If the publish fails, the error is logged but NOT re-raised so that
        the already-committed DB write is not rolled back (at-least-once
        delivery: the event can be retried by a reconciliation job).
        """
        event: dict = {
            "worker_id": record.worker_id,
            "policy_id": record.policy_id,
            "old_premium": float(record.old_premium),
            "new_premium": float(record.final_premium),
            "effective_date": record.computed_at.isoformat(),
        }
        try:
            await self._kafka.send(
                topic=_PREMIUM_UPDATED_TOPIC,
                value=event,
            )
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Failed to publish premium_updated event",
                extra={
                    "worker_id": record.worker_id,
                    "policy_id": record.policy_id,
                    "error": str(exc),
                },
                exc_info=True,
            )
