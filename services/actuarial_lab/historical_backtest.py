"""
Historical backtesting engine for Continuum parametric insurance.

Replays stored oracle trigger events against issued payouts to produce
zone-level and portfolio-level loss ratios, calibration metrics (Brier
score, reliability curve data), and expected-vs-realised frequency tables.

Requires:
  - PostgreSQL / TimescaleDB with weather_events hypertable
  - CockroachDB with payouts + policies tables
  - asyncpg for async DB access
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

MINIMUM_BACKTEST_MONTHS = 24


@dataclass
class ZoneBacktestResult:
    zone_id: str
    months_available: int
    total_premiums_collected: float
    total_payouts_issued: float
    loss_ratio: float
    trigger_count_expected: float
    trigger_count_realised: int
    brier_score: float
    calibration_buckets: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class PortfolioBacktestResult:
    start_date: datetime
    end_date: datetime
    zone_results: list[ZoneBacktestResult]
    portfolio_loss_ratio: float
    portfolio_bcr: float
    zones_below_24m: list[str]
    rolling_13w_loss_ratios: list[dict[str, Any]]
    passed: bool


def _brier_score(predicted_probs: list[float], outcomes: list[int]) -> float:
    if not predicted_probs:
        return 0.0
    n = len(predicted_probs)
    return float(np.mean([(p - o) ** 2 for p, o in zip(predicted_probs, outcomes)]))


def _calibration_buckets(
    predicted_probs: list[float], outcomes: list[int], n_bins: int = 10
) -> list[dict[str, Any]]:
    if not predicted_probs:
        return []
    bins = np.linspace(0.0, 1.0, n_bins + 1)
    buckets = []
    for i in range(n_bins):
        lo, hi = float(bins[i]), float(bins[i + 1])
        mask = [(lo <= p < hi) for p in predicted_probs]
        bucket_preds = [p for p, m in zip(predicted_probs, mask) if m]
        bucket_outcomes = [o for o, m in zip(outcomes, mask) if m]
        if bucket_preds:
            buckets.append({
                "bin_lo": round(lo, 2),
                "bin_hi": round(hi, 2),
                "count": len(bucket_preds),
                "mean_predicted": round(float(np.mean(bucket_preds)), 4),
                "mean_observed": round(float(np.mean(bucket_outcomes)), 4),
            })
    return buckets


async def _fetch_zones(ts_pool: asyncpg.Pool) -> list[str]:
    rows = await ts_pool.fetch("SELECT DISTINCT zone_id FROM weather_events")
    return [r["zone_id"] for r in rows]


async def _zone_event_history(
    ts_pool: asyncpg.Pool, zone_id: str, start: datetime, end: datetime
) -> list[dict[str, Any]]:
    """Weekly event counts + mean severity per zone."""
    rows = await ts_pool.fetch(
        """
        SELECT date_trunc('week', recorded_at) AS week,
               COUNT(*)                         AS event_count,
               AVG(rainfall_mm)                 AS avg_rainfall_mm,
               AVG(wind_kmh)                    AS avg_wind_kmh
        FROM   weather_events
        WHERE  zone_id = $1 AND recorded_at BETWEEN $2 AND $3
        GROUP  BY 1 ORDER BY 1
        """,
        zone_id, start, end,
    )
    return [dict(r) for r in rows]


async def _zone_premium_totals(
    crdb_pool: asyncpg.Pool, zone_id: str, start: datetime, end: datetime
) -> float:
    row = await crdb_pool.fetchrow(
        """
        SELECT COALESCE(SUM(pv.computed_premium), 0) AS total
        FROM   premium_versions pv
        WHERE  pv.zone_id = $1 AND pv.effective_date BETWEEN $2 AND $3
        """,
        zone_id, start, end,
    )
    return float(row["total"]) if row else 0.0


async def _zone_payout_totals(
    crdb_pool: asyncpg.Pool, zone_id: str, start: datetime, end: datetime
) -> tuple[float, int]:
    row = await crdb_pool.fetchrow(
        """
        SELECT COALESCE(SUM(amount), 0) AS total_paid,
               COUNT(*)                  AS payout_count
        FROM   payouts
        WHERE  zone_id = $1 AND status = 'disbursed'
               AND created_at BETWEEN $2 AND $3
        """,
        zone_id, start, end,
    )
    if row:
        return float(row["total_paid"]), int(row["payout_count"])
    return 0.0, 0


async def _rolling_13w_loss_ratios(
    crdb_pool: asyncpg.Pool, start: datetime, end: datetime
) -> list[dict[str, Any]]:
    """Portfolio-level 13-week rolling loss ratio windows."""
    results = []
    window = timedelta(weeks=13)
    cursor = start
    while cursor + window <= end:
        w_start = cursor
        w_end = cursor + window
        prem = await crdb_pool.fetchrow(
            """SELECT COALESCE(SUM(computed_premium), 0) AS total
               FROM premium_versions
               WHERE effective_date BETWEEN $1 AND $2""",
            w_start, w_end,
        )
        pay = await crdb_pool.fetchrow(
            """SELECT COALESCE(SUM(amount), 0) AS total
               FROM payouts
               WHERE status = 'disbursed' AND created_at BETWEEN $1 AND $2""",
            w_start, w_end,
        )
        prem_val = float(prem["total"]) if prem else 0.0
        pay_val = float(pay["total"]) if pay else 0.0
        lr = pay_val / prem_val if prem_val > 0 else 0.0
        results.append({
            "window_start": w_start.isoformat(),
            "window_end": w_end.isoformat(),
            "premiums": round(prem_val, 2),
            "payouts": round(pay_val, 2),
            "loss_ratio": round(lr, 4),
        })
        cursor += timedelta(weeks=1)
    return results


async def run_backtest(
    ts_dsn: str,
    crdb_dsn: str,
    lookback_months: int = MINIMUM_BACKTEST_MONTHS,
) -> PortfolioBacktestResult:
    """
    Execute a full historical backtest across all zones.

    Args:
        ts_dsn:  TimescaleDB connection string (weather_events)
        crdb_dsn: CockroachDB connection string (payouts, policies, premium_versions)
        lookback_months: how many months of history to replay

    Returns:
        PortfolioBacktestResult with per-zone and portfolio-level metrics.
    """
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=lookback_months * 30)

    ts_pool = await asyncpg.create_pool(ts_dsn, min_size=1, max_size=4)
    crdb_pool = await asyncpg.create_pool(crdb_dsn, min_size=1, max_size=4)

    try:
        zones = await _fetch_zones(ts_pool)
        zone_results: list[ZoneBacktestResult] = []
        zones_below_24m: list[str] = []

        for zone_id in zones:
            events = await _zone_event_history(ts_pool, zone_id, start, end)
            months_available = len(events)  # weekly buckets ≈ months/4 approx
            total_weeks = max(len(events), 1)
            months_approx = total_weeks * 7 / 30

            premiums = await _zone_premium_totals(crdb_pool, zone_id, start, end)
            payouts_total, payout_count = await _zone_payout_totals(crdb_pool, zone_id, start, end)

            loss_ratio = payouts_total / premiums if premiums > 0 else 0.0

            weekly_trigger_probs = [
                min(1.0, e.get("event_count", 0) / max(total_weeks, 1))
                for e in events
            ]
            weekly_outcomes = [1 if e.get("event_count", 0) > 0 else 0 for e in events]

            brier = _brier_score(weekly_trigger_probs, weekly_outcomes)
            cal_buckets = _calibration_buckets(weekly_trigger_probs, weekly_outcomes)

            expected_triggers = sum(weekly_trigger_probs)

            if months_approx < MINIMUM_BACKTEST_MONTHS:
                zones_below_24m.append(zone_id)

            zone_results.append(ZoneBacktestResult(
                zone_id=zone_id,
                months_available=int(months_approx),
                total_premiums_collected=round(premiums, 2),
                total_payouts_issued=round(payouts_total, 2),
                loss_ratio=round(loss_ratio, 4),
                trigger_count_expected=round(expected_triggers, 2),
                trigger_count_realised=payout_count,
                brier_score=round(brier, 6),
                calibration_buckets=cal_buckets,
            ))

        total_prem = sum(z.total_premiums_collected for z in zone_results)
        total_pay = sum(z.total_payouts_issued for z in zone_results)
        portfolio_lr = total_pay / total_prem if total_prem > 0 else 0.0
        portfolio_bcr = total_prem / total_pay if total_pay > 0 else float("inf")

        rolling = await _rolling_13w_loss_ratios(crdb_pool, start, end)
        breached = any(w["loss_ratio"] > 1.0 for w in rolling)

        result = PortfolioBacktestResult(
            start_date=start,
            end_date=end,
            zone_results=zone_results,
            portfolio_loss_ratio=round(portfolio_lr, 4),
            portfolio_bcr=round(portfolio_bcr, 4),
            zones_below_24m=zones_below_24m,
            rolling_13w_loss_ratios=rolling,
            passed=not breached,
        )

        logger.info(
            "backtest_complete",
            portfolio_lr=result.portfolio_loss_ratio,
            portfolio_bcr=result.portfolio_bcr,
            zones=len(zone_results),
            zones_below_24m=len(zones_below_24m),
            passed=result.passed,
        )
        return result

    finally:
        await ts_pool.close()
        await crdb_pool.close()
