# Feature: continuum-ml-pipelines, Property 15: Oracle Voting Threshold, Property 16: TLS Certificate Nullification, Property 17: Benefit of Doubt Protocol

import itertools
import pytest
from datetime import datetime, timedelta, timezone
from hypothesis import given, settings, assume
from hypothesis import strategies as st

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from services.oracle_engine.oracles import OracleVote
from services.oracle_engine.engine import OracleConsensusEngine, AFFIRMATIVE_THRESHOLD

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
