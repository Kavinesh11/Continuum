"""
Tests for actuarial_lab.historical_backtest pure functions.

Invariants covered:
  V28 — _brier_score([], []) == 0.0 (empty list guard)
"""
from __future__ import annotations

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from services.actuarial_lab.historical_backtest import (
    _brier_score,
    _calibration_buckets,
)


# ---------------------------------------------------------------------------
# V28 — _brier_score
# ---------------------------------------------------------------------------

def test_brier_score_empty_inputs_returns_zero():
    """V28: _brier_score([], []) must return 0.0."""
    assert _brier_score([], []) == pytest.approx(0.0)


def test_brier_score_perfect_prediction_is_zero():
    # Perfect forecast: predicted=1.0 when outcome=1, predicted=0.0 when outcome=0
    probs = [1.0, 0.0, 1.0, 0.0]
    outcomes = [1, 0, 1, 0]
    assert _brier_score(probs, outcomes) == pytest.approx(0.0)


def test_brier_score_worst_prediction():
    # Worst forecast: predicted=1.0 when outcome=0 (and vice versa)
    probs = [1.0, 1.0]
    outcomes = [0, 0]
    assert _brier_score(probs, outcomes) == pytest.approx(1.0)


def test_brier_score_uniform_half_probability():
    # Always predict 0.5, outcomes mix → Brier = 0.25
    probs = [0.5, 0.5, 0.5, 0.5]
    outcomes = [1, 0, 1, 0]
    assert _brier_score(probs, outcomes) == pytest.approx(0.25)


def test_brier_score_single_element():
    assert _brier_score([1.0], [1]) == pytest.approx(0.0)
    assert _brier_score([0.0], [0]) == pytest.approx(0.0)
    assert _brier_score([1.0], [0]) == pytest.approx(1.0)


@given(
    probs=st.lists(st.floats(min_value=0.0, max_value=1.0, allow_nan=False), min_size=1, max_size=50),
    outcomes=st.lists(st.integers(min_value=0, max_value=1), min_size=1, max_size=50),
)
@settings(max_examples=200)
def test_brier_score_always_in_zero_one(probs, outcomes):
    """V28: Brier score always in [0.0, 1.0] for valid inputs."""
    if len(probs) != len(outcomes):
        probs = probs[:min(len(probs), len(outcomes))]
        outcomes = outcomes[:len(probs)]
    if not probs:
        return
    score = _brier_score(probs, outcomes)
    assert 0.0 <= score <= 1.0


def test_brier_score_symmetry():
    # Symmetric error: overestimate vs underestimate by same amount → same score
    assert _brier_score([0.8], [0]) == pytest.approx(_brier_score([0.2], [1]))


# ---------------------------------------------------------------------------
# _calibration_buckets
# ---------------------------------------------------------------------------

def test_calibration_buckets_empty_inputs():
    """V28 (guard): empty inputs → empty list."""
    assert _calibration_buckets([], []) == []


def test_calibration_buckets_returns_list_of_dicts():
    probs = [0.1, 0.3, 0.5, 0.7, 0.9]
    outcomes = [0, 0, 1, 1, 1]
    result = _calibration_buckets(probs, outcomes)
    assert isinstance(result, list)
    for bucket in result:
        assert "bin_lo" in bucket
        assert "bin_hi" in bucket
        assert "count" in bucket
        assert "mean_predicted" in bucket
        assert "mean_observed" in bucket


def test_calibration_buckets_counts_match_input():
    probs = [0.05, 0.15, 0.85, 0.95]
    outcomes = [0, 0, 1, 1]
    result = _calibration_buckets(probs, outcomes)
    total_count = sum(b["count"] for b in result)
    assert total_count == len(probs)


def test_calibration_buckets_mean_predicted_in_range():
    probs = [0.1, 0.2, 0.8, 0.9]
    outcomes = [0, 1, 0, 1]
    result = _calibration_buckets(probs, outcomes)
    for bucket in result:
        assert 0.0 <= bucket["mean_predicted"] <= 1.0
        assert 0.0 <= bucket["mean_observed"] <= 1.0


def test_calibration_buckets_bin_edges_non_overlapping():
    probs = [i / 100 for i in range(100)]
    outcomes = [i % 2 for i in range(100)]
    result = _calibration_buckets(probs, outcomes, n_bins=10)
    for i in range(len(result) - 1):
        assert result[i]["bin_hi"] <= result[i + 1]["bin_lo"] + 1e-9
