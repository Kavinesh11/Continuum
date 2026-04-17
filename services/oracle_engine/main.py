"""
Oracle Consensus Engine entry point.
Runs an async polling loop with randomized ±8-minute jitter around the base interval.
Schedules are loaded from the poll_schedules DB table (see 005_poll_schedules.sql).
"""
from __future__ import annotations

import asyncio
import os
import random

import structlog
from dotenv import load_dotenv

from .engine import OracleConsensusEngine
from .kafka_publisher import KafkaPublisher
from .metrics import start_metrics_server
from .oracles import FORECAST_ORACLE_CLIENT
from .schedule_loader import load_schedules, FALLBACK_SCHEDULES, REFRESH_INTERVAL_SECONDS

load_dotenv()

logger = structlog.get_logger(__name__)

BASE_INTERVAL_SECONDS = int(os.environ.get("ORACLE_POLL_INTERVAL_SECONDS", "3600"))
JITTER_SECONDS = 480  # ±8 minutes

_cached_schedules: list[dict] = []
_cycles_since_refresh = 0
_REFRESH_EVERY_N_CYCLES = max(1, REFRESH_INTERVAL_SECONDS // max(BASE_INTERVAL_SECONDS, 1))


async def _get_poll_zones() -> list[dict]:
    """Load schedules from DB; refresh every N cycles; fall back to defaults."""
    global _cached_schedules, _cycles_since_refresh

    if not _cached_schedules or _cycles_since_refresh >= _REFRESH_EVERY_N_CYCLES:
        schedules = await load_schedules()
        if schedules:
            _cached_schedules = [
                {"zone_id": s.zone_id, "event_type": s.event_type}
                for s in schedules
            ]
        elif not _cached_schedules:
            _cached_schedules = [
                {"zone_id": s.zone_id, "event_type": s.event_type}
                for s in FALLBACK_SCHEDULES
            ]
        _cycles_since_refresh = 0
    else:
        _cycles_since_refresh += 1

    return _cached_schedules


async def run_poll_cycle(
    engine: OracleConsensusEngine,
    publisher: KafkaPublisher,
    zone_id: str,
    event_type: str,
) -> None:
    """Execute one full oracle poll cycle for a zone/event pair."""
    logger.info("poll_cycle_start", zone_id=zone_id, event_type=event_type)
    result = await engine.run_cycle(zone_id, event_type)

    if result.authorized:
        await publisher.publish_oracle_trigger(result, zone_id, event_type)
        await publisher.publish_payout_authorized(result, zone_id, event_type)
        logger.info(
            "trigger_authorized",
            zone_id=zone_id,
            affirmative=result.affirmative_count,
            payout_cap=result.payout_cap,
            benefit_of_doubt=result.benefit_of_doubt,
        )
    else:
        logger.info(
            "trigger_not_authorized",
            zone_id=zone_id,
            affirmative=result.affirmative_count,
            deny=result.deny_count,
            abstain=result.abstain_count,
            nullified=result.nullified_count,
        )


async def polling_loop() -> None:
    """Main async loop: poll all zones, then sleep with ±8-minute jitter."""
    engine = OracleConsensusEngine()
    publisher = KafkaPublisher()

    metrics_port = int(os.environ.get("ORACLE_METRICS_PORT", "8003"))
    start_metrics_server(metrics_port)

    await publisher.start()
    logger.info(
        "oracle_engine_started",
        base_interval=BASE_INTERVAL_SECONDS,
        jitter=JITTER_SECONDS,
    )

    try:
        while True:
            poll_zones = await _get_poll_zones()
            for zone_cfg in poll_zones:
                try:
                    await run_poll_cycle(
                        engine,
                        publisher,
                        zone_cfg["zone_id"],
                        zone_cfg["event_type"],
                    )
                except Exception as exc:
                    logger.error(
                        "poll_cycle_error",
                        zone_id=zone_cfg["zone_id"],
                        error=str(exc),
                    )

            # Forecast oracle poll — publish enrollment locks for high-risk zones
            for zone_cfg in poll_zones:
                try:
                    forecast_vote = await FORECAST_ORACLE_CLIENT.poll(
                        zone_cfg["zone_id"], zone_cfg["event_type"]
                    )
                    if forecast_vote.vote == "affirm":
                        await publisher.publish_enrollment_lock(
                            zone_cfg["zone_id"], zone_cfg["event_type"], forecast_vote.raw_payload
                        )
                        logger.info(
                            "enrollment_lock_published",
                            zone_id=zone_cfg["zone_id"],
                        )
                except Exception as exc:
                    logger.error(
                        "forecast_poll_error",
                        zone_id=zone_cfg["zone_id"],
                        error=str(exc),
                    )

            jitter = random.uniform(-JITTER_SECONDS, JITTER_SECONDS)
            sleep_seconds = max(60, BASE_INTERVAL_SECONDS + jitter)
            logger.info("next_poll_in_seconds", seconds=round(sleep_seconds, 1))
            await asyncio.sleep(sleep_seconds)
    finally:
        await publisher.stop()


def main() -> None:
    asyncio.run(polling_loop())


if __name__ == "__main__":
    main()
