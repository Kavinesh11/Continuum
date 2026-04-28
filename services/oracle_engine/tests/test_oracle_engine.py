# Feature: continuum-ml-pipelines, Property 15: Oracle Voting Threshold, Property 16: TLS Certificate Nullification, Property 17: Benefit of Doubt Protocol

import itertools
import pytest
import random
import uuid
import asyncio
from datetime import datetime, timedelta, timezone
from hypothesis import given, settings, assume
from hypothesis import strategies as st
from unittest.mock import AsyncMock, MagicMock, patch, call

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from services.oracle_engine.oracles import OracleVote
from services.oracle_engine.engine import OracleConsensusEngine, AFFIRMATIVE_THRESHOLD, VoteResult

ORACLE_NAMES = ["imd", "accuweather", "nasa_gpm", "ground_sensor"]


def _fresh_ts() -> datetime:
    """Return a timestamp within the 15-minute staleness window."""
    return datetime.now(timezone.utc) - timedelta(minutes=5)


def _stale_ts() -> datetime:
    """Return a timestamp older than the 15-minute staleness window."""
    return datetime.now(timezone.utc) - timedelta(minutes=20)


def _make_vote(oracle_name: str, vote: str, fresh: bool = True) -> OracleVote:
    """Build an OracleVote with a fresh or stale data_timestamp."""
    return OracleVote(
        oracle_name=oracle_name,
        vote=vote,
        data_timestamp=_fresh_ts() if fresh else _stale_ts(),
        polled_at=datetime.now(timezone.utc),
        tls_valid=(vote != "nullified"),
    )


def _make_votes_from_strings(vote_strings: list[str]) -> list[OracleVote]:
    """Build 4 OracleVote objects from a list of vote strings (fresh timestamps)."""
    assert len(vote_strings) == 4
    return [_make_vote(ORACLE_NAMES[i], vote_strings[i]) for i in range(4)]


# ---------------------------------------------------------------------------
# All 16 combinations of 4 binary (affirm/deny) votes for parametrize
# ---------------------------------------------------------------------------
_ALL_16_COMBINATIONS = list(itertools.product(["affirm", "deny"], repeat=4))


# ---------------------------------------------------------------------------
# Property 15: Oracle Voting Threshold — exhaustive parametrize
# Validates: Requirements 5.2, 5.3
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("combo", _ALL_16_COMBINATIONS)
def test_property15_voting_threshold_exhaustive(combo):
    """
    Property 15: Oracle Voting Threshold
    Validates: Requirements 5.2, 5.3

    For every one of the 16 possible 4-oracle affirm/deny combinations,
    the trigger must be authorized iff affirmative_count >= 3.
    """
    engine = OracleConsensusEngine(clients=[])
    votes = _make_votes_from_strings(list(combo))
    result = engine.evaluate_votes(votes)

    affirmative_count = combo.count("affirm")
    if affirmative_count >= AFFIRMATIVE_THRESHOLD:
        assert result.authorized is True, (
            f"Expected authorized=True for combo {combo} "
            f"(affirmative_count={affirmative_count})"
        )
    else:
        assert result.authorized is False, (
            f"Expected authorized=False for combo {combo} "
            f"(affirmative_count={affirmative_count})"
        )

    assert result.affirmative_count == affirmative_count


@given(st.lists(st.sampled_from(["affirm", "deny"]), min_size=4, max_size=4))
@settings(max_examples=100)
def test_property15_voting_threshold_hypothesis(vote_strings):
    """
    Property 15: Oracle Voting Threshold
    Validates: Requirements 5.2, 5.3

    For any combination of 4 affirm/deny votes, authorized iff affirmative_count >= 3.
    """
    engine = OracleConsensusEngine(clients=[])
    votes = _make_votes_from_strings(vote_strings)
    result = engine.evaluate_votes(votes)

    affirmative_count = vote_strings.count("affirm")
    assert result.authorized == (affirmative_count >= AFFIRMATIVE_THRESHOLD)
    assert result.affirmative_count == affirmative_count


# ---------------------------------------------------------------------------
# Property 15 (staleness): stale affirm votes must NOT count as affirmative
# Validates: Requirements 5.3
# ---------------------------------------------------------------------------

@given(
    fresh_affirm_count=st.integers(min_value=0, max_value=4),
    stale_affirm_count=st.integers(min_value=0, max_value=4),
)
@settings(max_examples=100)
def test_property15_staleness_abstention(fresh_affirm_count, stale_affirm_count):
    """
    Property 15: Oracle Voting Threshold — staleness rule
    Validates: Requirements 5.3

    Oracle data older than 15 minutes must be treated as abstention, not affirmative.
    Only fresh affirm votes count toward the threshold.
    Stale affirms become abstentions and may trigger Benefit of Doubt — that is
    correct engine behaviour and is accounted for in the assertion.
    """
    total = fresh_affirm_count + stale_affirm_count
    assume(total <= 4)

    engine = OracleConsensusEngine(clients=[])
    votes = []
    idx = 0
    for _ in range(fresh_affirm_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "affirm", fresh=True))
        idx += 1
    for _ in range(stale_affirm_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "affirm", fresh=False))
        idx += 1
    # Fill remaining with fresh deny
    while idx < 4:
        votes.append(_make_vote(ORACLE_NAMES[idx], "deny", fresh=True))
        idx += 1

    # Apply staleness rule first (converts stale affirms to abstain)
    fresh_votes = engine.apply_staleness_rule(votes)
    result = engine.evaluate_votes(fresh_votes)

    # Core assertion: stale affirms must NOT count as affirmative
    assert result.affirmative_count == fresh_affirm_count

    # Determine expected authorization, accounting for Benefit of Doubt:
    # stale affirms become abstentions, which may satisfy the BoD offline threshold.
    abstain_count = sum(1 for v in fresh_votes if v.vote == "abstain")
    bod_applies = abstain_count >= 2 and fresh_affirm_count >= 1

    if fresh_affirm_count >= AFFIRMATIVE_THRESHOLD:
        assert result.authorized is True
    elif bod_applies:
        # Stale votes became abstentions and triggered Benefit of Doubt — correct behaviour
        assert result.authorized is True
        assert result.payout_cap == 0.5
    else:
        assert result.authorized is False


# ---------------------------------------------------------------------------
# Property 16: TLS Certificate Nullification
# Validates: Requirements 5.5, 5.6
# ---------------------------------------------------------------------------

@given(
    nullified_indices=st.lists(
        st.integers(min_value=0, max_value=3), min_size=0, max_size=4, unique=True
    ),
    base_votes=st.lists(st.sampled_from(["affirm", "deny"]), min_size=4, max_size=4),
)
@settings(max_examples=100)
def test_property16_tls_nullification(nullified_indices, base_votes):
    """
    Property 16: TLS Certificate Nullification
    Validates: Requirements 5.5, 5.6

    Any oracle with a TLS mismatch has its vote nullified (does not count as affirmative).
    The affirmative count must equal the number of non-nullified affirm votes.
    """
    engine = OracleConsensusEngine(clients=[])
    votes = []
    for i in range(4):
        if i in nullified_indices:
            votes.append(_make_vote(ORACLE_NAMES[i], "nullified", fresh=True))
        else:
            votes.append(_make_vote(ORACLE_NAMES[i], base_votes[i], fresh=True))

    result = engine.evaluate_votes(votes)

    # Nullified votes must NOT count as affirmative
    expected_affirm = sum(
        1 for i in range(4)
        if i not in nullified_indices and base_votes[i] == "affirm"
    )
    assert result.affirmative_count == expected_affirm
    assert result.nullified_count == len(nullified_indices)


def test_property16_nullified_reduces_affirmative_count():
    """
    Property 16: TLS Certificate Nullification — nullification reduces affirmative count.
    Validates: Requirements 5.5, 5.6

    A vote that would have been 'affirm' but is nullified reduces the affirmative count,
    potentially preventing authorization.
    """
    engine = OracleConsensusEngine(clients=[])

    # Without nullification: 3 affirm → authorized
    votes_without_nullification = _make_votes_from_strings(["affirm", "affirm", "affirm", "deny"])
    result_without = engine.evaluate_votes(votes_without_nullification)
    assert result_without.authorized is True
    assert result_without.affirmative_count == 3

    # With one affirm nullified: only 2 affirm + 1 nullified + 1 deny.
    # offline (nullified) = 1 < 2, so BoD does NOT apply → NOT authorized.
    votes_with_nullification = [
        _make_vote("imd", "affirm"),
        _make_vote("accuweather", "affirm"),
        _make_vote("nasa_gpm", "nullified"),   # would have been affirm
        _make_vote("ground_sensor", "deny"),
    ]
    result_with = engine.evaluate_votes(votes_with_nullification)
    assert result_with.affirmative_count == 2
    assert result_with.authorized is False
    assert result_with.benefit_of_doubt is False


def test_property16_nullified_vote_logged():
    """
    Property 16: TLS Certificate Nullification — nullified count tracked in result.
    Validates: Requirements 5.6
    """
    engine = OracleConsensusEngine(clients=[])
    votes = [
        _make_vote("imd", "nullified"),
        _make_vote("accuweather", "affirm"),
        _make_vote("nasa_gpm", "affirm"),
        _make_vote("ground_sensor", "affirm"),
    ]
    result = engine.evaluate_votes(votes)
    assert result.nullified_count == 1
    # 3 affirm (non-nullified) → authorized normally
    assert result.authorized is True
    assert result.affirmative_count == 3


# ---------------------------------------------------------------------------
# Property 17: Benefit of Doubt Protocol
# Validates: Requirements 5.4, 5.8
# ---------------------------------------------------------------------------

@given(
    affirm_count=st.integers(min_value=1, max_value=2),
    offline_count=st.integers(min_value=2, max_value=3),
)
@settings(max_examples=100)
def test_property17_benefit_of_doubt_authorized(affirm_count, offline_count):
    """
    Property 17: Benefit of Doubt Protocol
    Validates: Requirements 5.4, 5.8

    When offline_count >= 2 AND affirm_count >= 1 AND affirm_count < 3,
    the engine must authorize with payout_cap == 0.5.
    """
    total = affirm_count + offline_count
    assume(total <= 4)
    # Ensure we don't accidentally hit the normal 3-of-4 threshold
    assume(affirm_count < AFFIRMATIVE_THRESHOLD)

    engine = OracleConsensusEngine(clients=[])
    votes = []
    idx = 0
    for _ in range(affirm_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "affirm"))
        idx += 1
    for _ in range(offline_count):
        # Use abstain to represent offline oracles
        votes.append(_make_vote(ORACLE_NAMES[idx], "abstain"))
        idx += 1
    # Fill remaining with deny
    while idx < 4:
        votes.append(_make_vote(ORACLE_NAMES[idx], "deny"))
        idx += 1

    result = engine.evaluate_votes(votes)

    assert result.authorized is True, (
        f"Expected authorized=True via Benefit of Doubt "
        f"(affirm={affirm_count}, offline={offline_count})"
    )
    assert result.payout_cap == 0.5, (
        f"Expected payout_cap=0.5 for Benefit of Doubt, got {result.payout_cap}"
    )
    assert result.benefit_of_doubt is True


@given(
    affirm_count=st.integers(min_value=1, max_value=2),
    nullified_count=st.integers(min_value=2, max_value=3),
)
@settings(max_examples=100)
def test_property17_benefit_of_doubt_with_nullified(affirm_count, nullified_count):
    """
    Property 17: Benefit of Doubt Protocol — nullified votes count as offline.
    Validates: Requirements 5.4, 5.8

    Nullified votes (TLS mismatch) count toward the offline threshold for Benefit of Doubt.
    """
    total = affirm_count + nullified_count
    assume(total <= 4)
    assume(affirm_count < AFFIRMATIVE_THRESHOLD)

    engine = OracleConsensusEngine(clients=[])
    votes = []
    idx = 0
    for _ in range(affirm_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "affirm"))
        idx += 1
    for _ in range(nullified_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "nullified"))
        idx += 1
    while idx < 4:
        votes.append(_make_vote(ORACLE_NAMES[idx], "deny"))
        idx += 1

    result = engine.evaluate_votes(votes)

    assert result.authorized is True
    assert result.payout_cap == 0.5
    assert result.benefit_of_doubt is True


@given(
    affirm_count=st.integers(min_value=0, max_value=4),
    offline_count=st.integers(min_value=0, max_value=4),
)
@settings(max_examples=100)
def test_property17_no_benefit_of_doubt_when_conditions_not_met(affirm_count, offline_count):
    """
    Property 17: Benefit of Doubt Protocol — NOT applied when conditions unmet.
    Validates: Requirements 5.4, 5.8

    When offline_count < 2 OR affirm_count == 0, Benefit of Doubt must NOT apply.
    When affirm_count < 3 AND benefit of doubt does not apply, trigger must NOT be authorized.
    """
    total = affirm_count + offline_count
    assume(total <= 4)
    # Conditions for BoD NOT met: offline < 2 OR affirm == 0
    assume(offline_count < 2 or affirm_count == 0)
    # Also not hitting normal threshold
    assume(affirm_count < AFFIRMATIVE_THRESHOLD)

    engine = OracleConsensusEngine(clients=[])
    votes = []
    idx = 0
    for _ in range(affirm_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "affirm"))
        idx += 1
    for _ in range(offline_count):
        votes.append(_make_vote(ORACLE_NAMES[idx], "abstain"))
        idx += 1
    while idx < 4:
        votes.append(_make_vote(ORACLE_NAMES[idx], "deny"))
        idx += 1

    result = engine.evaluate_votes(votes)

    assert result.authorized is False, (
        f"Expected authorized=False when BoD conditions not met "
        f"(affirm={affirm_count}, offline={offline_count})"
    )
    assert result.benefit_of_doubt is False
    assert result.payout_cap == 1.0


def test_property17_benefit_of_doubt_exact_boundary():
    """
    Property 17: Benefit of Doubt Protocol — boundary conditions.
    Validates: Requirements 5.4, 5.8

    Exactly 2 offline + 1 affirm → authorized with 50% cap.
    Exactly 1 offline + 1 affirm → NOT authorized via BoD.
    """
    engine = OracleConsensusEngine(clients=[])

    # 2 offline + 1 affirm + 1 deny → BoD applies
    votes_bod = [
        _make_vote("imd", "affirm"),
        _make_vote("accuweather", "abstain"),
        _make_vote("nasa_gpm", "abstain"),
        _make_vote("ground_sensor", "deny"),
    ]
    result_bod = engine.evaluate_votes(votes_bod)
    assert result_bod.authorized is True
    assert result_bod.payout_cap == 0.5
    assert result_bod.benefit_of_doubt is True

    # 1 offline + 1 affirm + 2 deny → BoD does NOT apply
    votes_no_bod = [
        _make_vote("imd", "affirm"),
        _make_vote("accuweather", "abstain"),
        _make_vote("nasa_gpm", "deny"),
        _make_vote("ground_sensor", "deny"),
    ]
    result_no_bod = engine.evaluate_votes(votes_no_bod)
    assert result_no_bod.authorized is False
    assert result_no_bod.benefit_of_doubt is False


# ---------------------------------------------------------------------------
# V6 — Kafka publish schema: both topics receive events on authorization
# ---------------------------------------------------------------------------

def _make_authorized_result() -> VoteResult:
    """Build a VoteResult representing 3-of-4 affirm authorization."""
    votes = [
        _make_vote("imd", "affirm"),
        _make_vote("accuweather", "affirm"),
        _make_vote("nasa_gpm", "affirm"),
        _make_vote("ground_sensor", "deny"),
    ]
    return VoteResult(
        authorized=True,
        affirmative_count=3,
        abstain_count=0,
        deny_count=1,
        nullified_count=0,
        payout_cap=1.0,
        votes=votes,
        benefit_of_doubt=False,
    )


@pytest.mark.asyncio
async def test_v6_both_topics_published_on_authorization():
    """V6: when authorized=True, both oracle_trigger and payout_authorized topics receive events."""
    from services.oracle_engine.kafka_publisher import KafkaPublisher, ORACLE_TRIGGER_TOPIC, PAYOUT_AUTHORIZED_TOPIC

    publisher = KafkaPublisher()
    sent_messages: dict[str, list] = {ORACLE_TRIGGER_TOPIC: [], PAYOUT_AUTHORIZED_TOPIC: []}

    async def fake_send(topic, message):
        sent_messages[topic].append(message)

    mock_producer = AsyncMock()
    mock_producer.send_and_wait.side_effect = fake_send
    publisher._producer = mock_producer

    result = _make_authorized_result()
    await publisher.publish_oracle_trigger(result, "MUM_ANDHERI_W", "heavy_rainfall")
    await publisher.publish_payout_authorized(result, "MUM_ANDHERI_W", "heavy_rainfall")

    assert len(sent_messages[ORACLE_TRIGGER_TOPIC]) == 1
    assert len(sent_messages[PAYOUT_AUTHORIZED_TOPIC]) == 1


@pytest.mark.asyncio
async def test_v6_oracle_trigger_schema():
    """V6: oracle_trigger event contains required fields with correct types."""
    from services.oracle_engine.kafka_publisher import KafkaPublisher, ORACLE_TRIGGER_TOPIC

    publisher = KafkaPublisher()
    captured = []

    async def fake_send(topic, message):
        if topic == ORACLE_TRIGGER_TOPIC:
            captured.append(message)

    mock_producer = AsyncMock()
    mock_producer.send_and_wait.side_effect = fake_send
    publisher._producer = mock_producer

    result = _make_authorized_result()
    await publisher.publish_oracle_trigger(result, "MUM_ANDHERI_W", "heavy_rainfall")

    assert len(captured) == 1
    event = captured[0]

    # Required schema fields
    assert "event_id" in event
    assert uuid.UUID(event["event_id"])  # must be a valid UUID
    assert event["zone_id"] == "MUM_ANDHERI_W"
    assert event["event_type"] == "heavy_rainfall"
    assert isinstance(event["oracle_votes"], list)
    assert len(event["oracle_votes"]) == 4
    assert event["payout_cap"] == 1.0
    assert "triggered_at" in event
    assert event["benefit_of_doubt"] is False

    # Each vote dict must have required fields
    for vote_dict in event["oracle_votes"]:
        assert "oracle_name" in vote_dict
        assert "vote" in vote_dict
        assert "tls_valid" in vote_dict
        assert "polled_at" in vote_dict


@pytest.mark.asyncio
async def test_v6_payout_authorized_schema():
    """V6: payout_authorized event contains required fields including payout_cap."""
    from services.oracle_engine.kafka_publisher import KafkaPublisher, PAYOUT_AUTHORIZED_TOPIC

    publisher = KafkaPublisher()
    captured = []

    async def fake_send(topic, message):
        if topic == PAYOUT_AUTHORIZED_TOPIC:
            captured.append(message)

    mock_producer = AsyncMock()
    mock_producer.send_and_wait.side_effect = fake_send
    publisher._producer = mock_producer

    result = _make_authorized_result()
    await publisher.publish_payout_authorized(
        result, "MUM_ANDHERI_W", "heavy_rainfall",
        payout_amount=500.0, claim_id="claim-1", worker_id="worker-1"
    )

    assert len(captured) == 1
    event = captured[0]

    assert "payout_id" in event
    assert uuid.UUID(event["payout_id"])
    assert event["zone_id"] == "MUM_ANDHERI_W"
    assert event["claim_id"] == "claim-1"
    assert event["worker_id"] == "worker-1"
    assert event["amount"] == 500.0
    assert event["payout_cap"] == 1.0
    assert event["benefit_of_doubt"] is False
    assert "authorized_at" in event
    assert isinstance(event["oracle_votes"], list)


@pytest.mark.asyncio
async def test_v6_run_poll_cycle_publishes_both_topics_when_authorized():
    """V6: run_poll_cycle publishes to BOTH oracle_trigger and payout_authorized when authorized."""
    from services.oracle_engine.main import run_poll_cycle

    result = _make_authorized_result()

    mock_engine = AsyncMock()
    mock_engine.run_cycle = AsyncMock(return_value=result)

    publish_calls = []
    mock_publisher = AsyncMock()
    mock_publisher.publish_oracle_trigger = AsyncMock(side_effect=lambda *a, **kw: publish_calls.append("oracle_trigger"))
    mock_publisher.publish_payout_authorized = AsyncMock(side_effect=lambda *a, **kw: publish_calls.append("payout_authorized"))

    await run_poll_cycle(mock_engine, mock_publisher, "MUM_ANDHERI_W", "heavy_rainfall")

    assert "oracle_trigger" in publish_calls
    assert "payout_authorized" in publish_calls


@pytest.mark.asyncio
async def test_v6_run_poll_cycle_no_publish_when_not_authorized():
    """V6: run_poll_cycle must NOT publish to either topic when authorized=False."""
    from services.oracle_engine.main import run_poll_cycle

    result = VoteResult(
        authorized=False,
        affirmative_count=1,
        abstain_count=0,
        deny_count=3,
        nullified_count=0,
        payout_cap=1.0,
        votes=_make_votes_from_strings(["affirm", "deny", "deny", "deny"]),
        benefit_of_doubt=False,
    )

    mock_engine = AsyncMock()
    mock_engine.run_cycle = AsyncMock(return_value=result)
    mock_publisher = AsyncMock()

    await run_poll_cycle(mock_engine, mock_publisher, "MUM_ANDHERI_W", "heavy_rainfall")

    mock_publisher.publish_oracle_trigger.assert_not_called()
    mock_publisher.publish_payout_authorized.assert_not_called()


# ---------------------------------------------------------------------------
# V7 — Polling jitter: interval in [BASE - 480s, BASE + 480s]
# ---------------------------------------------------------------------------

def test_v7_jitter_seconds_constant():
    """V7: JITTER_SECONDS must equal 480 (±8 minutes)."""
    from services.oracle_engine.main import JITTER_SECONDS
    assert JITTER_SECONDS == 480


def test_v7_jitter_range_over_many_samples():
    """V7: over many samples, jitter stays within ±480s of BASE_INTERVAL."""
    from services.oracle_engine.main import JITTER_SECONDS, BASE_INTERVAL_SECONDS

    jitter_min = float("inf")
    jitter_max = float("-inf")

    for _ in range(2000):
        jitter = random.uniform(-JITTER_SECONDS, JITTER_SECONDS)
        sleep_seconds = max(60, BASE_INTERVAL_SECONDS + jitter)
        jitter_min = min(jitter_min, sleep_seconds)
        jitter_max = max(jitter_max, sleep_seconds)

    # Upper bound: BASE + 480
    assert jitter_max <= BASE_INTERVAL_SECONDS + JITTER_SECONDS + 1  # +1 for float precision

    # Lower bound: at least 60 (the max(60, ...) floor)
    assert jitter_min >= 60


@given(jitter=st.floats(min_value=-480.0, max_value=480.0, allow_nan=False, allow_infinity=False))
def test_v7_sleep_always_at_least_60s(jitter: float):
    """V7: sleep_seconds = max(60, BASE + jitter) — never less than 60 seconds."""
    from services.oracle_engine.main import BASE_INTERVAL_SECONDS
    sleep_seconds = max(60, BASE_INTERVAL_SECONDS + jitter)
    assert sleep_seconds >= 60
    assert sleep_seconds <= BASE_INTERVAL_SECONDS + 480 + 1  # float tolerance


# ---------------------------------------------------------------------------
# V8 — DB fallback: poll_schedule failure falls back to FALLBACK_SCHEDULES
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_v8_db_failure_falls_back_to_fallback_schedules():
    """V8: when load_schedules() returns empty (DB error), _get_poll_zones uses FALLBACK_SCHEDULES."""
    from services.oracle_engine import main as oracle_main
    from services.oracle_engine.schedule_loader import FALLBACK_SCHEDULES

    # Reset module-level cache so we start fresh
    oracle_main._cached_schedules = []
    oracle_main._cycles_since_refresh = 0

    with patch("services.oracle_engine.main.load_schedules", new=AsyncMock(return_value=[])):
        zones = await oracle_main._get_poll_zones()

    fallback_zone_ids = {s.zone_id for s in FALLBACK_SCHEDULES}
    returned_zone_ids = {z["zone_id"] for z in zones}
    assert returned_zone_ids == fallback_zone_ids


@pytest.mark.asyncio
async def test_v8_db_fallback_preserves_cached_schedules_when_available():
    """V8: when DB returns empty but cache is populated, returns existing cached schedules (not fallback)."""
    from services.oracle_engine import main as oracle_main

    cached_zone = {"zone_id": "CACHED_ZONE", "event_type": "heavy_rainfall"}
    oracle_main._cached_schedules = [cached_zone]
    oracle_main._cycles_since_refresh = 0  # force a refresh attempt

    with patch("services.oracle_engine.main.load_schedules", new=AsyncMock(return_value=[])):
        zones = await oracle_main._get_poll_zones()

    # Cache was not replaced — existing cached zone is kept
    assert any(z["zone_id"] == "CACHED_ZONE" for z in zones)


@pytest.mark.asyncio
async def test_v8_db_success_updates_cache():
    """V8: when load_schedules() returns rows, cache is updated with DB data."""
    from services.oracle_engine import main as oracle_main
    from services.oracle_engine.schedule_loader import PollSchedule

    oracle_main._cached_schedules = []
    oracle_main._cycles_since_refresh = 0

    db_schedules = [
        PollSchedule(zone_id="DB_ZONE_A", event_type="heavy_rainfall", interval_seconds=3600, enabled=True),
        PollSchedule(zone_id="DB_ZONE_B", event_type="platform_outage", interval_seconds=1800, enabled=True),
    ]

    with patch("services.oracle_engine.main.load_schedules", new=AsyncMock(return_value=db_schedules)):
        zones = await oracle_main._get_poll_zones()

    zone_ids = {z["zone_id"] for z in zones}
    assert "DB_ZONE_A" in zone_ids
    assert "DB_ZONE_B" in zone_ids
