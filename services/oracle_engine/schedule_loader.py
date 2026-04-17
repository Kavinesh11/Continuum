"""
DB-driven poll schedule loader.

Replaces the hardcoded POLL_ZONES list in main.py with schedules
from the poll_schedules table. Refreshes periodically.
"""
from __future__ import annotations

import os
from dataclasses import dataclass

import asyncpg
import structlog

logger = structlog.get_logger(__name__)

PG_DSN = os.environ.get("PG_DSN", "postgresql://postgres:password@localhost:5432/continuum")
REFRESH_INTERVAL_SECONDS = int(os.environ.get("SCHEDULE_REFRESH_SECONDS", "300"))


@dataclass
class PollSchedule:
    zone_id: str
    event_type: str
    interval_seconds: int
    enabled: bool


async def load_schedules(dsn: str | None = None) -> list[PollSchedule]:
    conn = await asyncpg.connect(dsn or PG_DSN)
    try:
        rows = await conn.fetch(
            "SELECT zone_id, event_type, interval_seconds, enabled "
            "FROM poll_schedules WHERE enabled = TRUE"
        )
        schedules = [
            PollSchedule(
                zone_id=r["zone_id"],
                event_type=r["event_type"],
                interval_seconds=r["interval_seconds"],
                enabled=r["enabled"],
            )
            for r in rows
        ]
        logger.info("schedules_loaded", count=len(schedules))
        return schedules
    except Exception as exc:
        logger.warning("schedule_load_failed", error=str(exc))
        return []
    finally:
        await conn.close()


# Fallback if DB is unreachable — same as original hardcoded default
FALLBACK_SCHEDULES = [
    PollSchedule(
        zone_id=os.environ.get("DEFAULT_ZONE_ID", "MUM_ANDHERI_W"),
        event_type="heavy_rainfall",
        interval_seconds=3600,
        enabled=True,
    ),
]
