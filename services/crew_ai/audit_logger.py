"""
PostgreSQL audit logger for agent_audit_log table.

Schema:
  log_id      UUID PRIMARY KEY DEFAULT gen_random_uuid()
  claim_id    UUID REFERENCES claims(claim_id)
  agent_name  TEXT NOT NULL
  action      TEXT NOT NULL
  payload     JSONB
  logged_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any

from .models import AuditLogEntry

logger = logging.getLogger(__name__)

_pool = None


async def _get_pool():
    global _pool
    if _pool is None:
        import asyncpg  # noqa: PLC0415
        _pool = await asyncpg.create_pool(
            dsn=os.environ["POSTGRES_URL"],
            min_size=1,
            max_size=5,
        )
    return _pool


async def log_agent_action(
    claim_id: str,
    agent_name: str,
    action: str,
    payload: dict[str, Any] | None = None,
) -> None:
    """Write one row to agent_audit_log. Errors are logged but not re-raised."""
    entry = AuditLogEntry(
        claim_id=claim_id,
        agent_name=agent_name,
        action=action,
        payload=payload or {},
    )
    try:
        pool = await _get_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO agent_audit_log
                    (log_id, claim_id, agent_name, action, payload, logged_at)
                VALUES ($1, $2, $3, $4, $5::jsonb, $6)
                """,
                entry.log_id,
                entry.claim_id,
                entry.agent_name,
                entry.action,
                json.dumps(entry.payload),
                entry.logged_at,
            )
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "audit_log_write_failed claim_id=%s agent=%s action=%s error=%s",
            claim_id,
            agent_name,
            action,
            exc,
        )
