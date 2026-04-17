"""
Stress-testing harness for Continuum parametric insurance.

Runs three prescribed stress scenarios against historical data:
  1. Catastrophic correlated event (cyclone cluster)
  2. Systemic technology outage (platform-wide disruption)
  3. Climate drift (sustained frequency increase vs baseline)

Each scenario outputs reserve depletion days, BCR under stress, and a
pass/fail verdict against solvency thresholds.
"""
from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any

import asyncpg
import numpy as np
import structlog

logger = structlog.get_logger(__name__)

RESERVE_FLOOR_DAYS = 90
BCR_FLOOR = 1.0


@dataclass
class ScenarioResult:
    scenario_name: str
    description: str
    simulated_payouts: float
    simulated_premiums: float
    bcr: float
    reserve_depletion_days: float
    passed: bool
    details: dict[str, Any] = field(default_factory=dict)


@dataclass
class StressTestReport:
    run_at: datetime
    reserve_balance: float
    daily_payout_baseline: float
    scenarios: list[ScenarioResult]
    all_passed: bool


async def _get_reserve_balance(crdb_pool: asyncpg.Pool) -> float:
    # Prefer ledger-first view (ADR 0001); fall back to legacy single-row table
    row = await crdb_pool.fetchrow("SELECT balance FROM v_reserve_balance")
    if row:
        return float(row["balance"])
    row = await crdb_pool.fetchrow("SELECT balance FROM reserve_balance WHERE id = 1")
    return float(row["balance"]) if row else 0.0


async def _daily_payout_baseline(crdb_pool: asyncpg.Pool, lookback_days: int = 180) -> float:
    cutoff = datetime.now(timezone.utc) - timedelta(days=lookback_days)
    row = await crdb_pool.fetchrow(
        """SELECT COALESCE(SUM(amount), 0) / GREATEST($1, 1) AS daily_avg
           FROM payouts
           WHERE status = 'disbursed' AND created_at >= $2""",
        lookback_days, cutoff,
    )
    return float(row["daily_avg"]) if row else 0.0


async def _total_premiums(crdb_pool: asyncpg.Pool, lookback_days: int = 180) -> float:
    cutoff = datetime.now(timezone.utc) - timedelta(days=lookback_days)
    row = await crdb_pool.fetchrow(
        """SELECT COALESCE(SUM(computed_premium), 0) AS total
           FROM premium_versions WHERE effective_date >= $1""",
        cutoff,
    )
    return float(row["total"]) if row else 0.0


async def _active_policy_count(crdb_pool: asyncpg.Pool) -> int:
    row = await crdb_pool.fetchrow(
        "SELECT COUNT(*) AS cnt FROM policies WHERE status = 'active'"
    )
    return int(row["cnt"]) if row else 0


async def _scenario_catastrophic_correlated(
    crdb_pool: asyncpg.Pool,
    reserve: float,
    daily_baseline: float,
    premiums_180d: float,
) -> ScenarioResult:
    """
    Simulate a cyclone/flood cluster impacting >1000 simultaneous policies.
    Assumptions:
      - 5x baseline daily payout for 7 consecutive days
      - Premium income continues at normal rate
    """
    shock_days = 7
    multiplier = 5.0
    simulated_payouts = daily_baseline * multiplier * shock_days
    simulated_premiums = premiums_180d / 180 * shock_days
    bcr = simulated_premiums / simulated_payouts if simulated_payouts > 0 else float("inf")
    depletion_days = reserve / (daily_baseline * multiplier) if daily_baseline * multiplier > 0 else float("inf")

    return ScenarioResult(
        scenario_name="catastrophic_correlated",
        description="Cyclone/flood cluster: 5x payout surge for 7 days",
        simulated_payouts=round(simulated_payouts, 2),
        simulated_premiums=round(simulated_premiums, 2),
        bcr=round(bcr, 4),
        reserve_depletion_days=round(depletion_days, 1),
        passed=depletion_days >= RESERVE_FLOOR_DAYS,
        details={"shock_days": shock_days, "multiplier": multiplier},
    )


async def _scenario_systemic_tech_outage(
    crdb_pool: asyncpg.Pool,
    reserve: float,
    daily_baseline: float,
    premiums_180d: float,
) -> ScenarioResult:
    """
    Simulate a platform-wide Swiggy + Zomato outage lasting 12 hours.
    Assumptions:
      - Every active policy triggers a half-day payout
      - Average payout per policy = daily_baseline / active_policies * 0.5
    """
    active = await _active_policy_count(crdb_pool)
    avg_per_policy = (daily_baseline / max(active, 1)) if active > 0 else 0.0
    simulated_payouts = active * avg_per_policy * 3.0  # conservative 3x for concentrated event
    simulated_premiums = premiums_180d / 180
    bcr = simulated_premiums / simulated_payouts if simulated_payouts > 0 else float("inf")
    depletion_days = reserve / simulated_payouts if simulated_payouts > 0 else float("inf")

    return ScenarioResult(
        scenario_name="systemic_tech_outage",
        description="Platform-wide 12h outage affecting all active policies",
        simulated_payouts=round(simulated_payouts, 2),
        simulated_premiums=round(simulated_premiums, 2),
        bcr=round(bcr, 4),
        reserve_depletion_days=round(depletion_days, 1),
        passed=depletion_days >= RESERVE_FLOOR_DAYS,
        details={"active_policies": active},
    )


async def _scenario_climate_drift(
    crdb_pool: asyncpg.Pool,
    reserve: float,
    daily_baseline: float,
    premiums_180d: float,
) -> ScenarioResult:
    """
    Simulate multi-season increase in severe-event frequency.
    Assumptions:
      - Trigger frequency increases by 50% (1.5x) sustained over 90 days
      - Then by 100% (2.0x) for the following 90 days
    """
    phase_1_days = 90
    phase_2_days = 90
    simulated_payouts = (
        daily_baseline * 1.5 * phase_1_days
        + daily_baseline * 2.0 * phase_2_days
    )
    total_days = phase_1_days + phase_2_days
    simulated_premiums = premiums_180d  # same 180-day window
    bcr = simulated_premiums / simulated_payouts if simulated_payouts > 0 else float("inf")
    avg_daily_stress = simulated_payouts / total_days
    depletion_days = reserve / avg_daily_stress if avg_daily_stress > 0 else float("inf")

    return ScenarioResult(
        scenario_name="climate_drift",
        description="1.5x frequency for 90d then 2.0x for 90d vs training baseline",
        simulated_payouts=round(simulated_payouts, 2),
        simulated_premiums=round(simulated_premiums, 2),
        bcr=round(bcr, 4),
        reserve_depletion_days=round(depletion_days, 1),
        passed=depletion_days >= RESERVE_FLOOR_DAYS,
        details={"phase_1_multiplier": 1.5, "phase_2_multiplier": 2.0},
    )


async def run_stress_test(crdb_dsn: str) -> StressTestReport:
    """
    Execute all three stress scenarios against the live reserve and
    historical payout baseline.

    Returns a StressTestReport with per-scenario and aggregate pass/fail.
    """
    pool = await asyncpg.create_pool(crdb_dsn, min_size=1, max_size=4)

    try:
        reserve = await _get_reserve_balance(pool)
        daily_baseline = await _daily_payout_baseline(pool)
        premiums_180d = await _total_premiums(pool)

        scenarios = await asyncio.gather(
            _scenario_catastrophic_correlated(pool, reserve, daily_baseline, premiums_180d),
            _scenario_systemic_tech_outage(pool, reserve, daily_baseline, premiums_180d),
            _scenario_climate_drift(pool, reserve, daily_baseline, premiums_180d),
        )
        scenario_list = list(scenarios)
        all_passed = all(s.passed for s in scenario_list)

        report = StressTestReport(
            run_at=datetime.now(timezone.utc),
            reserve_balance=round(reserve, 2),
            daily_payout_baseline=round(daily_baseline, 2),
            scenarios=scenario_list,
            all_passed=all_passed,
        )

        logger.info(
            "stress_test_complete",
            reserve=report.reserve_balance,
            daily_baseline=report.daily_payout_baseline,
            all_passed=all_passed,
            results={s.scenario_name: s.passed for s in scenario_list},
        )
        return report

    finally:
        await pool.close()
