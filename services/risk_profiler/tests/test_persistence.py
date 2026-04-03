# Feature: continuum-ml-pipelines
"""
Unit tests for RiskScoreRepository (persistence.py).

Validates: Requirements 1.11, 2.6
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock, call, patch

import pytest

from services.risk_profiler.persistence import (
    RiskScoreRecord,
    RiskScoreRepository,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_NOW = datetime(2024, 1, 22, 10, 30, 0, tzinfo=timezone.utc)


def _make_record(**overrides) -> RiskScoreRecord:
    defaults = dict(
        score_id="aaaaaaaa-0000-0000-0000-000000000001",
        worker_id="bbbbbbbb-0000-0000-0000-000000000002",
        policy_id="cccccccc-0000-0000-0000-000000000003",
        risk_score=0.42,
        feature_vector=[float(i) for i in range(15)],
        final_premium=Decimal("162.00"),
        model_version="xgb_v2.1.0",
        computed_at=_NOW,
        old_premium=Decimal("149.00"),
    )
    defaults.update(overrides)
    return RiskScoreRecord(**defaults)


def _make_repo(db_execute=None, kafka_send=None):
    db = MagicMock()
    db.execute = db_execute or AsyncMock(return_value=None)
    kafka = MagicMock()
    kafka.send = kafka_send or AsyncMock(return_value=None)
    return RiskScoreRepository(db_pool=db, kafka_producer=kafka), db, kafka


# ---------------------------------------------------------------------------
# Test: successful INSERT then Kafka publish
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_save_and_publish_inserts_then_publishes():
    """Happy path: DB INSERT succeeds, then Kafka event is published."""
    repo, db, kafka = _make_repo()
    record = _make_record()

    await repo.save_and_publish(record)

    db.execute.assert_awaited_once()
    kafka.send.assert_awaited_once()


@pytest.mark.asyncio
async def test_save_and_publish_db_query_contains_all_fields():
    """The INSERT query must reference all 8 required columns."""
    repo, db, kafka = _make_repo()
    record = _make_record()

    await repo.save_and_publish(record)

    query: str = db.execute.call_args[0][0]
    for col in (
        "score_id", "worker_id", "policy_id", "risk_score",
        "feature_vector", "final_premium", "model_version", "computed_at",
    ):
        assert col in query, f"Column '{col}' missing from INSERT query"


@pytest.mark.asyncio
async def test_save_and_publish_db_args_match_record():
    """asyncpg positional args must match the record fields in order."""
    repo, db, kafka = _make_repo()
    record = _make_record()

    await repo.save_and_publish(record)

    args = db.execute.call_args[0][1:]  # skip the query string
    assert args[0] == record.score_id
    assert args[1] == record.worker_id
    assert args[2] == record.policy_id
    assert args[3] == record.risk_score
    assert args[4] == record.feature_vector
    assert args[5] == record.final_premium
    assert args[6] == record.model_version
    assert args[7] == record.computed_at


@pytest.mark.asyncio
async def test_save_and_publish_kafka_event_shape():
    """Kafka event must contain worker_id, policy_id, old_premium, new_premium, effective_date."""
    repo, db, kafka = _make_repo()
    record = _make_record()

    await repo.save_and_publish(record)

    _, kwargs = kafka.send.call_args
    topic = kwargs.get("topic") or kafka.send.call_args[0][0]
    value = kwargs.get("value") or kafka.send.call_args[0][1]

    assert topic == "premium_updated"
    assert value["worker_id"] == record.worker_id
    assert value["policy_id"] == record.policy_id
    assert value["old_premium"] == float(record.old_premium)
    assert value["new_premium"] == float(record.final_premium)
    assert "effective_date" in value


# ---------------------------------------------------------------------------
# Test: DB failure → no Kafka publish
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_db_failure_raises_and_skips_kafka():
    """If INSERT raises, the exception propagates and Kafka is NOT called."""
    db_execute = AsyncMock(side_effect=RuntimeError("DB connection lost"))
    repo, db, kafka = _make_repo(db_execute=db_execute)
    record = _make_record()

    with pytest.raises(RuntimeError, match="DB connection lost"):
        await repo.save_and_publish(record)

    kafka.send.assert_not_awaited()


# ---------------------------------------------------------------------------
# Test: Kafka failure → DB write is NOT rolled back
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_kafka_failure_does_not_raise(caplog):
    """If Kafka publish fails, the error is logged but NOT re-raised."""
    kafka_send = AsyncMock(side_effect=ConnectionError("Kafka broker unreachable"))
    repo, db, kafka = _make_repo(kafka_send=kafka_send)
    record = _make_record()

    import logging
    with caplog.at_level(logging.ERROR, logger="services.risk_profiler.persistence"):
        # Should NOT raise
        await repo.save_and_publish(record)

    # DB write still happened
    db.execute.assert_awaited_once()
    # Error was logged
    assert any("premium_updated" in msg or "Failed" in msg for msg in caplog.messages)


@pytest.mark.asyncio
async def test_kafka_failure_db_write_committed():
    """DB execute is called exactly once even when Kafka fails."""
    kafka_send = AsyncMock(side_effect=OSError("network error"))
    repo, db, kafka = _make_repo(kafka_send=kafka_send)
    record = _make_record()

    await repo.save_and_publish(record)  # must not raise

    db.execute.assert_awaited_once()


# ---------------------------------------------------------------------------
# Test: ordering — INSERT before publish
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_insert_called_before_kafka_publish():
    """DB INSERT must be awaited before the Kafka send is attempted."""
    call_order: list[str] = []

    async def db_execute(query, *args):
        call_order.append("db")

    async def kafka_send(topic, value):
        call_order.append("kafka")

    db = MagicMock()
    db.execute = db_execute
    kafka = MagicMock()
    kafka.send = kafka_send

    repo = RiskScoreRepository(db_pool=db, kafka_producer=kafka)
    await repo.save_and_publish(_make_record())

    assert call_order == ["db", "kafka"], f"Unexpected call order: {call_order}"
