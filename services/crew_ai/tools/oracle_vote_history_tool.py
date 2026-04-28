"""
OracleVoteHistoryTool — queries PostgreSQL for oracle vote history and weather events.

Sources:
  - payouts.oracle_votes  (JSONB) — per-zone authorized trigger vote breakdowns
  - weather_events        — TimescaleDB corroborating sensor data
"""
from __future__ import annotations

import asyncio
import json
import os
from typing import Any

from pydantic import BaseModel, Field


class OracleVoteHistoryInput(BaseModel):
    zone_id: str = Field(..., description="Zone identifier to look up oracle history for")
    event_type: str = Field(..., description="Event type (e.g. heavy_rainfall, platform_outage)")
    hours: int = Field(default=48, description="Lookback window in hours")


class OracleVoteHistoryTool:
    """Queries PostgreSQL for oracle vote history and corroborating weather events."""

    name: str = "oracle_vote_history"
    description: str = (
        "Look up oracle consensus vote history and corroborating weather/sensor data "
        "for a given zone_id and event_type. Returns recent authorized trigger records "
        "with per-oracle vote breakdowns, and weather event readings for corroboration. "
        "If no authorized triggers are found for the zone/event in the time window, "
        "that indicates no parametric trigger was authorized — a strong fraud signal."
    )

    def run(self, zone_id: str, event_type: str, hours: int = 48) -> dict[str, Any]:
        async def _query() -> dict[str, Any]:
            import asyncpg  # noqa: PLC0415

            conn = await asyncpg.connect(dsn=os.environ["POSTGRES_URL"])
            try:
                # Oracle vote history from payouts (authorized triggers only)
                payout_rows = await conn.fetch(
                    """
                    SELECT payout_id, claim_id, oracle_votes, zone_id, created_at,
                           payout_cap, status
                    FROM payouts
                    WHERE zone_id = $1
                      AND created_at >= NOW() - ($2 || ' hours')::INTERVAL
                    ORDER BY created_at DESC
                    LIMIT 10
                    """,
                    zone_id,
                    str(hours),
                )

                # Corroborating weather/sensor events
                weather_rows = await conn.fetch(
                    """
                    SELECT zone_id, event_type, rainfall_mm, wind_kmh, recorded_at
                    FROM weather_events
                    WHERE zone_id = $1
                      AND event_type = $2
                      AND recorded_at >= NOW() - ($3 || ' hours')::INTERVAL
                    ORDER BY recorded_at DESC
                    LIMIT 20
                    """,
                    zone_id,
                    event_type,
                    str(hours),
                )

                authorized_triggers = []
                for row in payout_rows:
                    authorized_triggers.append({
                        "payout_id": str(row["payout_id"]),
                        "claim_id": str(row["claim_id"]) if row["claim_id"] else None,
                        "oracle_votes": json.loads(row["oracle_votes"]) if row["oracle_votes"] else [],
                        "zone_id": row["zone_id"],
                        "created_at": row["created_at"].isoformat(),
                        "payout_cap": float(row["payout_cap"]) if row["payout_cap"] else None,
                        "status": row["status"],
                    })

                weather_events = [
                    {
                        "zone_id": row["zone_id"],
                        "event_type": row["event_type"],
                        "rainfall_mm": row["rainfall_mm"],
                        "wind_kmh": row["wind_kmh"],
                        "recorded_at": row["recorded_at"].isoformat(),
                    }
                    for row in weather_rows
                ]

                return {
                    "zone_id": zone_id,
                    "event_type": event_type,
                    "lookback_hours": hours,
                    "authorized_trigger_count": len(authorized_triggers),
                    "authorized_triggers": authorized_triggers,
                    "weather_corroboration_count": len(weather_events),
                    "weather_events": weather_events,
                }
            finally:
                await conn.close()

        loop = asyncio.new_event_loop()
        try:
            return loop.run_until_complete(_query())
        except Exception as exc:  # noqa: BLE001
            return {"error": str(exc), "zone_id": zone_id, "event_type": event_type}
        finally:
            loop.close()

    def _run(self, zone_id: str, event_type: str, hours: int = 48) -> dict[str, Any]:
        return self.run(zone_id, event_type, hours)


def make_oracle_vote_history_tool():
    """Return a crewai-compatible OracleVoteHistoryTool if crewai is available."""
    try:
        from crewai.tools import BaseTool  # noqa: PLC0415

        class _OracleVoteHistoryTool(BaseTool):
            name: str = "oracle_vote_history"
            description: str = (
                "Look up oracle consensus vote history and corroborating weather/sensor data "
                "for a given zone_id and event_type. If no authorized triggers are found, "
                "that indicates no parametric trigger was authorized — a strong fraud signal."
            )
            args_schema: type[BaseModel] = OracleVoteHistoryInput

            def _run(self, zone_id: str, event_type: str, hours: int = 48) -> str:
                return json.dumps(OracleVoteHistoryTool().run(zone_id, event_type, hours))

        return _OracleVoteHistoryTool()
    except ImportError:
        return OracleVoteHistoryTool()
