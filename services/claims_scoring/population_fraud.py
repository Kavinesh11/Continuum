import json
import logging
import os
from dataclasses import dataclass
from datetime import datetime

import asyncpg

logger = logging.getLogger(__name__)

CONVERGENCE_FREEZE_THRESHOLD = 50
DEVICE_CLUSTER_THRESHOLD = 5


@dataclass
class PopulationFraudResult:
    convergence_freeze: bool
    device_cluster_flagged: bool
    claim_count_5min: int
    cluster_size: int


async def check_population_fraud(
    pool: asyncpg.Pool,
    zone_id: str,
    policy_id: str,
    worker_id: str,
    device_id: str,
    submitted_at: datetime,
) -> PopulationFraudResult:
    claim_count_5min = await _query_zone_claim_count(pool, zone_id)
    convergence_freeze = claim_count_5min >= CONVERGENCE_FREEZE_THRESHOLD

    if convergence_freeze:
        logger.info("Convergence Freeze triggered zone_id=%s count=%d", zone_id, claim_count_5min)
        await _publish_convergence_freeze_alert(zone_id, claim_count_5min)

    cluster_size = await _query_device_cluster_size(pool, device_id)
    device_cluster_flagged = cluster_size >= DEVICE_CLUSTER_THRESHOLD

    if device_cluster_flagged:
        logger.info("Device proximity cluster flagged device_id=%s size=%d", device_id, cluster_size)

    return PopulationFraudResult(
        convergence_freeze=convergence_freeze,
        device_cluster_flagged=device_cluster_flagged,
        claim_count_5min=claim_count_5min,
        cluster_size=cluster_size,
    )


async def _query_zone_claim_count(pool: asyncpg.Pool, zone_id: str) -> int:
    try:
        count = await pool.fetchval(
            """
            SELECT COUNT(DISTINCT policy_id)
            FROM claims
            WHERE zone_id = $1
              AND submitted_at > NOW() - INTERVAL '5 minutes'
            """,
            zone_id,
        )
        return max(0, int(count or 0))
    except Exception as e:
        logger.error("Failed to query zone claim count zone_id=%s error=%s", zone_id, e)
        return 0


async def _query_device_cluster_size(pool: asyncpg.Pool, device_id: str) -> int:
    if not device_id:
        return 0
    try:
        count = await pool.fetchval(
            """
            SELECT COUNT(DISTINCT
                   CASE WHEN device_id_a = $1 THEN device_id_b
                        ELSE device_id_a
                   END)
            FROM device_proximity_log
            WHERE (device_id_a = $1 OR device_id_b = $1)
              AND recorded_at > NOW() - INTERVAL '7 days'
            """,
            device_id,
        )
        return max(0, int(count or 0))
    except Exception as e:
        logger.error("Failed to query device cluster size device_id=%s error=%s", device_id, e)
        return 0


async def _publish_convergence_freeze_alert(zone_id: str, claim_count: int) -> None:
    try:
        from aiokafka import AIOKafkaProducer
    except ImportError:
        return

    brokers = os.getenv("KAFKA_BROKERS", "localhost:9092")
    payload = json.dumps({
        "alert_type": "convergence_freeze",
        "zone_id": zone_id,
        "claim_count": claim_count,
    }).encode()

    producer = AIOKafkaProducer(bootstrap_servers=brokers)
    try:
        await producer.start()
        await producer.send_and_wait("fraud_alert", value=payload, key=zone_id.encode())
        logger.info("Published convergence_freeze fraud_alert zone_id=%s", zone_id)
    except Exception as e:
        logger.error("Failed to publish convergence_freeze alert: %s", e)
    finally:
        await producer.stop()
