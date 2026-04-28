"""
Tests for actuarial_lab.ci_gate._run()

Invariants covered:
  V24 — CI gate fails when any rolling 13-week loss ratio > 1.0
  V25 — CI gate fails when portfolio_bcr < 1.05
  V26 — CI gate logs warning when zone Brier score > 0.2
  V27 — stress scenario with reserve_depletion_days < 90 causes CI gate fail
"""
from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch

import pytest

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from services.actuarial_lab.historical_backtest import (
    PortfolioBacktestResult,
    ZoneBacktestResult,
)
from services.actuarial_lab.stress_scenarios import ScenarioResult, StressTestReport
from services.actuarial_lab.ci_gate import _run


# ---------------------------------------------------------------------------
# Helpers — build stub dataclasses with exact field shapes
# ---------------------------------------------------------------------------

_NOW = datetime.now(timezone.utc)


def _zone(
    zone_id="Z1",
    loss_ratio=0.8,
    brier_score=0.1,
    premiums=10_000.0,
    payouts=8_000.0,
):
    return ZoneBacktestResult(
        zone_id=zone_id,
        months_available=24,
        total_premiums_collected=premiums,
        total_payouts_issued=payouts,
        loss_ratio=loss_ratio,
        trigger_count_expected=10.0,
        trigger_count_realised=8,
        brier_score=brier_score,
    )


def _portfolio(
    zone_results=None,
    portfolio_lr=0.8,
    portfolio_bcr=1.25,
    rolling=None,
    passed=True,
):
    if zone_results is None:
        zone_results = [_zone()]
    if rolling is None:
        rolling = [{"window_start": _NOW.isoformat(), "window_end": _NOW.isoformat(),
                    "loss_ratio": 0.8, "premiums": 10000.0, "payouts": 8000.0}]
    return PortfolioBacktestResult(
        start_date=_NOW,
        end_date=_NOW,
        zone_results=zone_results,
        portfolio_loss_ratio=portfolio_lr,
        portfolio_bcr=portfolio_bcr,
        zones_below_24m=[],
        rolling_13w_loss_ratios=rolling,
        passed=passed,
    )


def _scenario(name="cat", depletion_days=120.0, passed=True):
    return ScenarioResult(
        scenario_name=name,
        description="test scenario",
        simulated_payouts=100_000.0,
        simulated_premiums=110_000.0,
        bcr=1.1,
        reserve_depletion_days=depletion_days,
        passed=passed,
    )


def _stress_report(scenarios=None):
    if scenarios is None:
        scenarios = [_scenario()]
    return StressTestReport(
        run_at=_NOW,
        reserve_balance=5_000_000.0,
        daily_payout_baseline=10_000.0,
        scenarios=scenarios,
        all_passed=all(s.passed for s in scenarios),
    )


# ---------------------------------------------------------------------------
# T2a — all-pass scenario returns True
# ---------------------------------------------------------------------------

def test_ci_gate_all_pass():
    """V24, V25, V27: all thresholds met → _run returns True."""
    backtest = _portfolio(portfolio_bcr=1.25, passed=True)
    stress = _stress_report([_scenario(depletion_days=120.0, passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is True


# ---------------------------------------------------------------------------
# V24 — rolling 13-week loss ratio > 1.0 → gate fails
# ---------------------------------------------------------------------------

def test_ci_gate_fails_when_rolling_loss_ratio_breached():
    """V24: any rolling window with loss_ratio > 1.0 → _run returns False."""
    rolling_breached = [
        {"loss_ratio": 0.9, "premiums": 100.0, "payouts": 90.0,
         "window_start": _NOW.isoformat(), "window_end": _NOW.isoformat()},
        {"loss_ratio": 1.05, "premiums": 100.0, "payouts": 105.0,
         "window_start": _NOW.isoformat(), "window_end": _NOW.isoformat()},  # breached
    ]
    backtest = _portfolio(rolling=rolling_breached, passed=False)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is False


def test_ci_gate_fails_when_portfolio_passed_false():
    """V24: backtest.passed=False propagates to CI gate failure."""
    backtest = _portfolio(passed=False)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is False


# ---------------------------------------------------------------------------
# V25 — portfolio_bcr < 1.05 → gate fails
# ---------------------------------------------------------------------------

def test_ci_gate_fails_when_bcr_below_floor():
    """V25: portfolio_bcr < 1.05 → _run returns False."""
    backtest = _portfolio(portfolio_bcr=1.0, passed=True)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is False


def test_ci_gate_passes_when_bcr_exactly_at_floor():
    """V25: portfolio_bcr == 1.05 is at floor — gate passes (not < floor)."""
    backtest = _portfolio(portfolio_bcr=1.05, passed=True)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is True


def test_ci_gate_skips_bcr_check_when_inf():
    """V25: portfolio_bcr == inf (no payouts) is explicitly not penalised."""
    backtest = _portfolio(portfolio_bcr=float("inf"), passed=True)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is True


# ---------------------------------------------------------------------------
# V26 — Brier score > 0.2 is a warning, not a hard failure
# ---------------------------------------------------------------------------

def test_ci_gate_fails_when_brier_score_exceeds_ceiling():
    """V26: Brier > 0.2 appended to failures → CI gate returns False (hard failure)."""
    zone_high_brier = _zone(brier_score=0.35)
    backtest = _portfolio(zone_results=[zone_high_brier], portfolio_bcr=1.25, passed=True)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is False


def test_ci_gate_passes_when_brier_score_at_ceiling():
    """V26: Brier exactly == 0.2 is not > ceiling → gate passes."""
    zone_at_ceiling = _zone(brier_score=0.2)
    backtest = _portfolio(zone_results=[zone_at_ceiling], portfolio_bcr=1.25, passed=True)
    stress = _stress_report([_scenario(passed=True)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is True


# ---------------------------------------------------------------------------
# V27 — stress depletion_days < 90 → gate fails
# ---------------------------------------------------------------------------

def test_ci_gate_fails_when_stress_scenario_fails():
    """V27: any scenario with reserve_depletion_days < 90 → _run returns False."""
    backtest = _portfolio(portfolio_bcr=1.25, passed=True)
    stress = _stress_report([
        _scenario("cat", depletion_days=120.0, passed=True),
        _scenario("tech_outage", depletion_days=45.0, passed=False),  # under 90 days
    ])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is False


def test_ci_gate_passes_when_all_stress_scenarios_above_90_days():
    """V27: all depletion_days >= 90 → gate passes."""
    backtest = _portfolio(portfolio_bcr=1.25, passed=True)
    stress = _stress_report([
        _scenario("cat", depletion_days=91.0, passed=True),
        _scenario("drift", depletion_days=200.0, passed=True),
    ])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is True


def test_ci_gate_multiple_failures_all_reported():
    """V24+V25+V27: multiple violations all cause gate to fail."""
    rolling_breached = [{"loss_ratio": 1.2, "premiums": 100.0, "payouts": 120.0,
                          "window_start": _NOW.isoformat(), "window_end": _NOW.isoformat()}]
    backtest = _portfolio(portfolio_bcr=0.9, rolling=rolling_breached, passed=False)
    stress = _stress_report([_scenario("cat", depletion_days=30.0, passed=False)])

    with patch("services.actuarial_lab.ci_gate.run_backtest", new=AsyncMock(return_value=backtest)), \
         patch("services.actuarial_lab.ci_gate.run_stress_test", new=AsyncMock(return_value=stress)):
        result = asyncio.run(_run("ts-dsn", "crdb-dsn"))

    assert result is False
