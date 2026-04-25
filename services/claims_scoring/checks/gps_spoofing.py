import logging
import math
import os
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional

import asyncpg
import httpx

logger = logging.getLogger(__name__)


@dataclass
class GpsSpoofingResult:
    spatial_penalty: float
    soak_period_failed: bool
    platform_activity_veto: bool
    static_lock_detected: bool
    flags: list = field(default_factory=list)


async def run_gps_spoofing_checks(
    pool: asyncpg.Pool,
    claim_id: str,
    worker_id: str,
    gps_coordinates: list,
    cell_id_coordinates: Optional[list],
    gps_history: Optional[list],
    event_timestamp: datetime,
    zone_id: str,
) -> GpsSpoofingResult:
    flags = []
    spatial_penalty = 0.0
    soak_period_failed = False
    platform_activity_veto = False
    static_lock_detected = False

    # Check 1: Cell-ID vs GPS divergence (Req 4.3, 4.4)
    if cell_id_coordinates:
        divergence_km = haversine_km(
            gps_coordinates[0], gps_coordinates[1],
            cell_id_coordinates[0], cell_id_coordinates[1],
        )
        if divergence_km > 2.0:
            logger.warning(
                "Cell-ID vs GPS divergence %.2fkm > 2km — LOCATION_MISMATCH claim_id=%s",
                divergence_km, claim_id,
            )
            flags.append("LOCATION_MISMATCH")
            spatial_penalty = 0.3

    # Check 2: 45-minute soak period (Req 4.5, 4.6)
    if gps_history:
        if not await _check_soak_period(gps_history, event_timestamp, zone_id, pool):
            logger.warning("Soak period not met claim_id=%s", claim_id)
            soak_period_failed = True

    # Check 3: Platform API order cross-reference (Req 4.7, 4.8)
    if await _check_platform_orders(claim_id, worker_id, event_timestamp):
        logger.warning("Platform API orders found — PLATFORM_ACTIVITY_VETO claim_id=%s", claim_id)
        platform_activity_veto = True
        flags.append("PLATFORM_ACTIVITY_VETO")

    # Check 4: Static-lock detection (Req 4.9, 4.10)
    if gps_history and _is_static_lock(gps_history):
        logger.warning("Static-lock detected claim_id=%s", claim_id)
        static_lock_detected = True
        flags.append("STATIC_LOCK")

    return GpsSpoofingResult(
        spatial_penalty=spatial_penalty,
        soak_period_failed=soak_period_failed,
        platform_activity_veto=platform_activity_veto,
        static_lock_detected=static_lock_detected,
        flags=flags,
    )


async def _check_soak_period(
    gps_history: list,
    event_timestamp: datetime,
    zone_id: str,
    pool: asyncpg.Pool,
) -> bool:
    soak_start = event_timestamp - timedelta(minutes=45)
    window_points = [p for p in gps_history if soak_start <= p.ts <= event_timestamp]

    if not window_points:
        logger.warning("No GPS history points in 45-minute soak window")
        return False

    earliest = min(p.ts for p in window_points)
    coverage_minutes = (event_timestamp - earliest).total_seconds() / 60

    if coverage_minutes < 45:
        logger.warning("GPS history covers only %.1f minutes (need 45)", coverage_minutes)
        return False

    for point in window_points:
        try:
            in_zone = await pool.fetchval(
                """
                SELECT ST_Contains(z.polygon, ST_SetSRID(ST_Point($1, $2), 4326))
                FROM zones z
                WHERE z.zone_id = $3
                """,
                point.lon, point.lat, zone_id,
            )
        except Exception:
            in_zone = None

        if not in_zone:
            logger.warning("GPS history point outside zone lat=%f lon=%f", point.lat, point.lon)
            return False

    return True


async def _check_platform_orders(claim_id: str, worker_id: str, event_timestamp: datetime) -> bool:
    platform_api_url = os.getenv("PLATFORM_API_URL", "http://localhost:9000")
    event_start = event_timestamp - timedelta(hours=2)
    event_end = event_timestamp + timedelta(hours=2)

    url = (
        f"{platform_api_url}/workers/{worker_id}/orders"
        f"?from={event_start.isoformat()}&to={event_end.isoformat()}"
    )

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url)
        if not resp.is_success:
            logger.warning(
                "Platform API returned %d — skipping veto claim_id=%s", resp.status_code, claim_id,
            )
            return False
        body = resp.json()
        return len(body.get("orders", [])) > 0
    except Exception as e:
        logger.warning("Platform API request failed claim_id=%s error=%s — skipping veto", claim_id, e)
        return False


def _is_static_lock(gps_history: list) -> bool:
    if len(gps_history) < 3:
        return False
    first = gps_history[0]
    return all(
        abs(p.lat - first.lat) < 1e-7 and abs(p.lon - first.lon) < 1e-7
        for p in gps_history
    )


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    EARTH_RADIUS_KM = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.asin(math.sqrt(a))
    return EARTH_RADIUS_KM * c
