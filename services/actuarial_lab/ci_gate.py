"""
CI gate script for actuarial validation.

Runs both backtest and stress tests, then exits with code 1 if any
critical threshold is breached:
  - Rolling 13-week portfolio loss ratio > 100%
  - Any stress scenario fails (reserve depletion < 90 days)

Usage:
  python -m services.actuarial_lab.ci_gate \
      --ts-dsn "postgresql://..." \
      --crdb-dsn "postgresql://..."
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys
from datetime import timezone

import structlog

from .historical_backtest import run_backtest
from .stress_scenarios import run_stress_test

logger = structlog.get_logger(__name__)


async def _run(ts_dsn: str, crdb_dsn: str) -> bool:
    failures: list[str] = []

    backtest = await run_backtest(ts_dsn, crdb_dsn)
    if not backtest.passed:
        failures.append(
            f"Backtest FAILED: rolling 13-week loss ratio breached 100% "
            f"in {sum(1 for w in backtest.rolling_13w_loss_ratios if w['loss_ratio'] > 1.0)} windows"
        )
    if backtest.zones_below_24m:
        logger.warning(
            "zones_below_minimum_history",
            zones=backtest.zones_below_24m,
        )

    stress = await run_stress_test(crdb_dsn)
    for scenario in stress.scenarios:
        if not scenario.passed:
            failures.append(
                f"Stress scenario '{scenario.scenario_name}' FAILED: "
                f"reserve depletion in {scenario.reserve_depletion_days} days "
                f"(minimum {90})"
            )

    if failures:
        for f in failures:
            logger.error("ci_gate_failure", message=f)
        return False

    logger.info(
        "ci_gate_passed",
        portfolio_bcr=backtest.portfolio_bcr,
        portfolio_lr=backtest.portfolio_loss_ratio,
        stress_all_passed=stress.all_passed,
    )
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="Actuarial CI gate")
    parser.add_argument("--ts-dsn", required=True, help="TimescaleDB DSN")
    parser.add_argument("--crdb-dsn", required=True, help="CockroachDB DSN")
    args = parser.parse_args()

    passed = asyncio.run(_run(args.ts_dsn, args.crdb_dsn))
    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
