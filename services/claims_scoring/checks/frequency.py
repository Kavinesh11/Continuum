import logging
from dataclasses import dataclass

import asyncpg

logger = logging.getLogger(__name__)


@dataclass
class FrequencyResult:
    score: float
    velocity_cap_exceeded: bool
    claims_90d: int


async def check_frequency(pool: asyncpg.Pool, worker_id: str) -> FrequencyResult:
    try:
        return await _run_frequency_query(pool, worker_id)
    except Exception as e:
        logger.error(
            "PostgreSQL frequency query failed worker_id=%s error=%s — using score 0.5",
            worker_id, e,
        )
        return FrequencyResult(score=0.5, velocity_cap_exceeded=False, claims_90d=0)


async def _run_frequency_query(pool: asyncpg.Pool, worker_id: str) -> FrequencyResult:
    count = await pool.fetchval(
        """
        SELECT COUNT(*)
        FROM claims
        WHERE worker_id = $1
          AND status IN ('auto_approved', 'approved')
          AND submitted_at > NOW() - INTERVAL '90 days'
        """,
        str(worker_id),
    )
    claims_90d = int(count or 0)
    velocity_cap_exceeded = claims_90d > 3
    score = 0.0 if velocity_cap_exceeded else 1.0

    logger.info(
        "Frequency check worker_id=%s claims_90d=%d velocity_cap_exceeded=%s",
        worker_id, claims_90d, velocity_cap_exceeded,
    )

    return FrequencyResult(score=score, velocity_cap_exceeded=velocity_cap_exceeded, claims_90d=claims_90d)
