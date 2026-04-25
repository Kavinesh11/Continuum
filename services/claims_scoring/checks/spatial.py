import logging
from dataclasses import dataclass
from typing import Optional

import asyncpg

logger = logging.getLogger(__name__)


@dataclass
class SpatialResult:
    score: float
    zone_mismatch: bool
    adjacency_grace: bool
    adjacent_zone_id: Optional[str]


async def check_spatial(pool: asyncpg.Pool, zone_id: str, lat: float, lon: float) -> SpatialResult:
    try:
        return await _run_spatial_query(pool, zone_id, lat, lon)
    except Exception as e:
        logger.error(
            "PostGIS spatial query failed zone_id=%s lat=%f lon=%f error=%s — using score 0.5",
            zone_id, lat, lon, e,
        )
        return SpatialResult(score=0.5, zone_mismatch=False, adjacency_grace=False, adjacent_zone_id=None)


async def _run_spatial_query(pool: asyncpg.Pool, zone_id: str, lat: float, lon: float) -> SpatialResult:
    row = await pool.fetchrow(
        """
        SELECT
            ST_Contains(z.polygon, ST_SetSRID(ST_Point($1, $2), 4326)) AS within_zone,
            ST_DWithin(
                z.polygon::geography,
                ST_SetSRID(ST_Point($1, $2), 4326)::geography,
                2000
            ) AS within_buffer
        FROM zones z
        WHERE z.zone_id = $3
        """,
        lon, lat, zone_id,
    )

    if row is None:
        logger.error("Zone not found in PostGIS zone_id=%s — treating as mismatch", zone_id)
        return SpatialResult(score=0.0, zone_mismatch=True, adjacency_grace=False, adjacent_zone_id=None)

    within_zone = row["within_zone"] or False
    within_buffer = row["within_buffer"] or False

    if within_zone:
        logger.info("GPS within zone polygon zone_id=%s lat=%f lon=%f", zone_id, lat, lon)
        return SpatialResult(score=1.0, zone_mismatch=False, adjacency_grace=False, adjacent_zone_id=None)
    elif within_buffer:
        logger.info("GPS within 2km buffer zone_id=%s lat=%f lon=%f", zone_id, lat, lon)
        return SpatialResult(score=0.7, zone_mismatch=False, adjacency_grace=False, adjacent_zone_id=None)
    else:
        adj_zone = await _check_adjacency(pool, zone_id, lat, lon)
        if adj_zone:
            logger.info("GPS in adjacent zone zone_id=%s adjacent=%s", zone_id, adj_zone)
            return SpatialResult(score=0.5, zone_mismatch=False, adjacency_grace=True, adjacent_zone_id=adj_zone)
        else:
            logger.info("GPS outside zone — mismatch zone_id=%s lat=%f lon=%f", zone_id, lat, lon)
            return SpatialResult(score=0.0, zone_mismatch=True, adjacency_grace=False, adjacent_zone_id=None)


async def _check_adjacency(pool: asyncpg.Pool, zone_id: str, lat: float, lon: float) -> Optional[str]:
    row = await pool.fetchrow(
        """
        SELECT neighbor.zone_id
        FROM zones neighbor
        JOIN zones claimed ON claimed.zone_id = $3
        WHERE ST_Touches(claimed.polygon, neighbor.polygon)
          AND neighbor.zone_id != $3
          AND ST_Contains(neighbor.polygon, ST_SetSRID(ST_Point($1, $2), 4326))
        LIMIT 1
        """,
        lon, lat, zone_id,
    )
    return row["zone_id"] if row else None
