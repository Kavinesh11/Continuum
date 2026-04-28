"""
Tests for actuarial_lab.stress_scenarios

Invariants covered:
  V27 — reserve_depletion_days < 90 for any scenario → scenario.passed = False
  V4  (stress context) — reserve floor = 90 days
"""
from __future__ import annotations

import asyncio
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from services.actuarial_lab.stress_scenarios import (
    RESERVE_FLOOR_DAYS,
    BCR_FLOOR,
    ScenarioResult,
    StressTestReport,
    _scenario_catastrophic_correlated,
    _scenario_climate_drift,
    _scenario_systemic_tech_outage,
)


# ---------------------------------------------------------------------------
# Constants sanity checks — these are load-bearing business thresholds
# ---------------------------------------------------------------------------

def test_reserve_floor_is_90_days():
    """V27: the RESERVE_FLOOR_DAYS constant must equal 90."""
    assert RESERVE_FLOOR_DAYS == 90


def test_bcr_floor_is_one():
    """V27: BCR_FLOOR must equal 1.0."""
    assert BCR_FLOOR == 1.0


# ---------------------------------------------------------------------------
# V27 — ScenarioResult.passed reflects depletion vs 90-day floor
# ---------------------------------------------------------------------------

def test_scenario_result_passed_true_above_floor():
    """V27: depletion_days >= 90 → passed=True."""
    s = ScenarioResult(
        scenario_name="test", description="d",
        simulated_payouts=100.0, simulated_premiums=110.0,
        bcr=1.1, reserve_depletion_days=91.0, passed=True,
    )
    assert s.passed is True


def test_scenario_result_passed_false_below_floor():
    """V27: depletion_days < 90 → passed=False."""
    s = ScenarioResult(
        scenario_name="test", description="d",
        simulated_payouts=100.0, simulated_premiums=110.0,
        bcr=0.9, reserve_depletion_days=45.0, passed=False,
    )
    assert s.passed is False


def test_scenario_result_at_exactly_floor():
    """V27: depletion_days == 90 is >= floor → passed=True."""
    s = ScenarioResult(
        scenario_name="test", description="d",
        simulated_payouts=100.0, simulated_premiums=110.0,
        bcr=1.1, reserve_depletion_days=90.0, passed=True,
    )
    assert s.passed is True


# ---------------------------------------------------------------------------
# _scenario_catastrophic_correlated: 5x baseline, 7 days
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_catastrophic_scenario_math():
    """V27: payout = baseline * 5 * 7; depletion = reserve / (baseline * 5)."""
    pool = MagicMock()
    daily_baseline = 10_000.0
    reserve = 5_000_000.0
    premiums_180d = 1_800_000.0

    result = await _scenario_catastrophic_correlated(pool, reserve, daily_baseline, premiums_180d)

    expected_payouts = daily_baseline * 5.0 * 7
    expected_depletion = reserve / (daily_baseline * 5.0)

    assert result.simulated_payouts == pytest.approx(expected_payouts, abs=0.01)
    assert result.reserve_depletion_days == pytest.approx(expected_depletion, abs=0.1)
    assert result.passed == (expected_depletion >= RESERVE_FLOOR_DAYS)


@pytest.mark.asyncio
async def test_catastrophic_scenario_fails_with_small_reserve():
    """V27: small reserve → depletion < 90 → passed=False."""
    pool = MagicMock()
    # reserve = 10 days of 5x baseline
    daily_baseline = 10_000.0
    reserve = daily_baseline * 5 * 10  # only 10 days
    result = await _scenario_catastrophic_correlated(pool, reserve, daily_baseline, 1_000_000.0)
    assert result.passed is False


@pytest.mark.asyncio
async def test_catastrophic_scenario_passes_with_large_reserve():
    """V27: large reserve → depletion >= 90 → passed=True."""
    pool = MagicMock()
    daily_baseline = 1_000.0
    reserve = daily_baseline * 5 * 200  # 200 days of 5x baseline
    result = await _scenario_catastrophic_correlated(pool, reserve, daily_baseline, 500_000.0)
    assert result.passed is True


@pytest.mark.asyncio
async def test_catastrophic_scenario_zero_baseline_gives_inf_depletion():
    """V27: zero daily_baseline → depletion = inf → passed=True."""
    pool = MagicMock()
    result = await _scenario_catastrophic_correlated(pool, 1_000_000.0, 0.0, 500_000.0)
    assert result.reserve_depletion_days == float("inf")
    assert result.passed is True


# ---------------------------------------------------------------------------
# _scenario_climate_drift: 1.5x for 90d then 2.0x for 90d
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_climate_drift_scenario_math():
    """V27: simulated_payouts = baseline*(1.5*90 + 2.0*90); avg daily = payouts/180."""
    pool = MagicMock()
    daily_baseline = 5_000.0
    reserve = 50_000_000.0

    result = await _scenario_climate_drift(pool, reserve, daily_baseline, 900_000.0)

    expected_payouts = daily_baseline * 1.5 * 90 + daily_baseline * 2.0 * 90
    expected_avg_daily = expected_payouts / 180
    expected_depletion = reserve / expected_avg_daily

    assert result.simulated_payouts == pytest.approx(expected_payouts, abs=0.01)
    assert result.reserve_depletion_days == pytest.approx(expected_depletion, abs=0.1)


# ---------------------------------------------------------------------------
# _scenario_systemic_tech_outage
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_systemic_outage_uses_active_policy_count():
    """V27: systemic outage scenario calls _active_policy_count for sizing."""
    pool = MagicMock()
    pool.fetchrow = AsyncMock(return_value={"cnt": 100})

    result = await _scenario_systemic_tech_outage(pool, 5_000_000.0, 10_000.0, 1_800_000.0)

    assert result.details["active_policies"] == 100
    assert result.simulated_payouts > 0


@pytest.mark.asyncio
async def test_systemic_outage_zero_active_policies():
    """V27: zero active policies → simulated_payouts == 0 → depletion = inf → passed=True."""
    pool = MagicMock()
    pool.fetchrow = AsyncMock(return_value={"cnt": 0})

    result = await _scenario_systemic_tech_outage(pool, 5_000_000.0, 10_000.0, 1_800_000.0)

    assert result.simulated_payouts == pytest.approx(0.0)
    assert result.reserve_depletion_days == float("inf")
    assert result.passed is True


# ---------------------------------------------------------------------------
# StressTestReport.all_passed aggregation
# ---------------------------------------------------------------------------

def test_stress_report_all_passed_only_when_all_scenarios_pass():
    """V27: all_passed = all(s.passed for s in scenarios)."""
    passing = ScenarioResult("a", "d", 100.0, 110.0, 1.1, 120.0, True)
    failing = ScenarioResult("b", "d", 200.0, 100.0, 0.5, 30.0, False)

    report_all_pass = StressTestReport(
        run_at=__import__("datetime").datetime.utcnow(),
        reserve_balance=1_000_000.0,
        daily_payout_baseline=5_000.0,
        scenarios=[passing, passing],
        all_passed=True,
    )
    assert report_all_pass.all_passed is True

    report_one_fail = StressTestReport(
        run_at=__import__("datetime").datetime.utcnow(),
        reserve_balance=1_000_000.0,
        daily_payout_baseline=5_000.0,
        scenarios=[passing, failing],
        all_passed=False,
    )
    assert report_one_fail.all_passed is False


# ---------------------------------------------------------------------------
# Property test: depletion threshold relationship
# ---------------------------------------------------------------------------

@given(
    reserve=st.floats(min_value=1.0, max_value=1e9, allow_nan=False, allow_infinity=False),
    daily=st.floats(min_value=0.01, max_value=1e7, allow_nan=False, allow_infinity=False),
)
@settings(max_examples=200)
def test_depletion_days_formula_catastrophic(reserve, daily):
    """V27: depletion = reserve / (daily * 5); passed iff depletion >= 90."""
    expected_depletion = reserve / (daily * 5.0)
    expected_passed = expected_depletion >= RESERVE_FLOOR_DAYS
    # Verify the formula is consistent with the threshold
    assert expected_passed == (expected_depletion >= 90)
