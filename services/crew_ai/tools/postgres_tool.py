"""
PostgresClaimHistoryTool — queries PostgreSQL for a worker's claim history.
"""
from __future__ import annotations

import asyncio
import os
from typing import Any

from pydantic import BaseModel, Field


class PostgresClaimHistoryInput(BaseModel):
    worker_id: str = Field(..., description="Worker UUID to look up claim history for")
    days: int = Field(default=90, description="Rolling window in days")


class PostgresClaimHistoryTool:
    """Tool wrapper for PostgreSQL claim history queries."""

    name: str = "postgres_claim_history"
    description: str = (
        "Query PostgreSQL for a worker's claim history within a rolling window. "
        "Returns claim count, statuses, and fraud scores."
    )

    def run(self, worker_id: str, days: int = 90) -> dict[str, Any]:
        async def _query() -> dict[str, Any]:
            import asyncpg  # noqa: PLC0415
            conn = await asyncpg.connect(dsn=os.environ["POSTGRES_URL"])
            try:
                rows = await conn.fetch(
                    """
                    SELECT claim_id, status, fraud_score, submitted_at
                    FROM claims
                    WHERE worker_id = $1
                      AND submitted_at >= NOW() - ($2 || ' days')::INTERVAL
                    ORDER BY submitted_at DESC
                    """,
                    worker_id,
                    str(days),
                )
                claims = [dict(r) for r in rows]
                return {
                    "worker_id": worker_id,
                    "days": days,
                    "claim_count": len(claims),
                    "claims": claims,
                }
            finally:
                await conn.close()

        loop = asyncio.new_event_loop()
        try:
            return loop.run_until_complete(_query())
        except Exception as exc:  # noqa: BLE001
            return {"error": str(exc), "worker_id": worker_id}
        finally:
            loop.close()

    def _run(self, worker_id: str, days: int = 90) -> dict[str, Any]:
        return self.run(worker_id, days)


def make_postgres_claim_history_tool():
    """Return a crewai-compatible PostgresClaimHistoryTool if crewai is available."""
    try:
        from crewai.tools import BaseTool  # noqa: PLC0415

        class _PostgresClaimHistoryTool(BaseTool):
            name: str = "postgres_claim_history"
            description: str = (
                "Query PostgreSQL for a worker's claim history within a rolling window."
            )
            args_schema: type[BaseModel] = PostgresClaimHistoryInput

            def _run(self, worker_id: str, days: int = 90) -> dict[str, Any]:
                return PostgresClaimHistoryTool().run(worker_id, days)

        return _PostgresClaimHistoryTool()
    except ImportError:
        return PostgresClaimHistoryTool()
