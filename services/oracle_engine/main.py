"""
Oracle Consensus Engine entry point.
Runs an async polling loop with randomized ±8-minute jitter around the base interval.
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

load_dotenv()

logger = structlog.get_logger(__name__)

BASE_INTERVAL_SECONDS = int(os.environ.get("ORACLE_POLL_INTERVAL_SECONDS", "3600"))
JITTER_SECONDS = 480  # ±8 minutes

# Zone/event configuration — in production these would come from a config service or DB
POLL_ZONES: list[dict] = [
    {"zone_id": os.environ.get("DEFAULT_ZONE_ID", "MUM_ANDHERI_W"), "event_type": "heavy_rainfall"},
]


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
            for zone_cfg in POLL_ZONES:
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
