# Feature: continuum-ml-pipelines
"""
FeatureBuilder: assembles the 15-dimensional feature vector for the Risk Profiler.

Three data sources are queried concurrently via asyncio.gather:
  - TimescaleDB  (historical weather event counts)
  - Weather_API  (current weather conditions)
  - PostgreSQL   (worker profile + GPS activity)

If any source times out (>500 ms), zone-level medians are substituted and
the substitution is recorded via structured logging.
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Protocol

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Timeout budget per source (seconds)
# ---------------------------------------------------------------------------
_SOURCE_TIMEOUT = 0.5  # 500 ms


# ---------------------------------------------------------------------------
# Typed result containers returned by each async client
# ---------------------------------------------------------------------------

@dataclass
class WeatherData:
    rainfall_mm_hr: float
    wind_speed_kmh: float
    temperature_c: float


@dataclass
class TimescaleData:
    weather_event_freq_30d: float
    flood_event_count_30d: float
    cyclone_event_count_30d: float


@dataclass
class PostgresData:
    active_days_last_30: float
    avg_daily_orders: float
    platform_encoded: float   # 0 = swiggy, 1 = zomato
    tier_encoded: float       # 0 = silver, 1 = gold, 2 = platinum
    zone_risk_index: float
    claim_velocity_90d: float


@dataclass
class ZoneMedians:
    """Zone-level median values used as fallback for any unavailable source."""
    rainfall_mm_hr: float = 0.0
    wind_speed_kmh: float = 0.0
    temperature_c: float = 25.0
    weather_event_freq_30d: float = 0.0
    flood_event_count_30d: float = 0.0
    cyclone_event_count_30d: float = 0.0
    active_days_last_30: float = 15.0
    avg_daily_orders: float = 8.0
    zone_risk_index: float = 0.5


# ---------------------------------------------------------------------------
# Client protocols (injected for testability)
# ---------------------------------------------------------------------------

class TimescaleClient(Protocol):
    async def fetch_weather_history(
        self, zone_id: str
    ) -> TimescaleData: ...


class WeatherAPIClient(Protocol):
    async def fetch_current_conditions(
        self, lat: float, lon: float
    ) -> WeatherData: ...


class PostgresClient(Protocol):
    async def fetch_worker_profile(
        self, worker_id: str
    ) -> PostgresData: ...

    async def fetch_zone_medians(
        self, zone_id: str
    ) -> ZoneMedians: ...


# ---------------------------------------------------------------------------
# FeatureBuilder
# ---------------------------------------------------------------------------

class FeatureBuilder:
    """
    Assembles a 15-dimensional feature vector from three data sources in
    parallel.  Any source that exceeds _SOURCE_TIMEOUT seconds is replaced
    with zone-level median values and the substitution is logged.
    """

    def __init__(
        self,
        timescale_client: TimescaleClient,
        weather_client: WeatherAPIClient,
        postgres_client: PostgresClient,
    ) -> None:
        self._ts = timescale_client
        self._wx = weather_client
        self._pg = postgres_client

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def build(
        self,
        worker_id: str,
        zone_id: str,
        lat: float,
        lon: float,
    ) -> list[float]:
        """
        Return a 15-dimensional feature vector.

        Dimensions (0-indexed):
          0  rainfall_mm_hr_current
          1  wind_speed_kmh_current
          2  temperature_c_current
          3  weather_event_freq_30d
          4  flood_event_count_30d
          5  cyclone_event_count_30d
          6  active_days_last_30
          7  avg_daily_orders
          8  platform_encoded
          9  tier_encoded
          10 zone_risk_index
          11 hour_of_day
          12 day_of_week
          13 month
          14 claim_velocity_90d
        """
        # Fetch zone medians first (fast, local DB, not subject to the
        # 500 ms budget — used only as fallback values).
        medians = await self._pg.fetch_zone_medians(zone_id)

        # Run all three source queries concurrently.
        ts_result, wx_result, pg_result = await asyncio.gather(
            self._fetch_timescale(zone_id, medians),
            self._fetch_weather(lat, lon, medians),
            self._fetch_postgres(worker_id, medians),
            return_exceptions=False,
        )

        # System-clock features (no fallback needed).
        now = datetime.now(tz=timezone.utc)

        return [
            wx_result.rainfall_mm_hr,           # 0
            wx_result.wind_speed_kmh,            # 1
            wx_result.temperature_c,             # 2
            ts_result.weather_event_freq_30d,    # 3
            ts_result.flood_event_count_30d,     # 4
            ts_result.cyclone_event_count_30d,   # 5
            pg_result.active_days_last_30,       # 6
            pg_result.avg_daily_orders,          # 7
            pg_result.platform_encoded,          # 8
            pg_result.tier_encoded,              # 9
            pg_result.zone_risk_index,           # 10
            float(now.hour),                     # 11
            float(now.weekday()),                # 12
            float(now.month),                    # 13
            pg_result.claim_velocity_90d,        # 14
        ]

    # ------------------------------------------------------------------
    # Private helpers — each wraps a source call with a timeout + fallback
    # ------------------------------------------------------------------

    async def _fetch_timescale(
        self, zone_id: str, medians: ZoneMedians
    ) -> TimescaleData:
        try:
            return await asyncio.wait_for(
                self._ts.fetch_weather_history(zone_id),
                timeout=_SOURCE_TIMEOUT,
            )
        except (asyncio.TimeoutError, Exception) as exc:
            reason = "timeout" if isinstance(exc, asyncio.TimeoutError) else f"error: {exc}"
            substituted = ["weather_event_freq_30d", "flood_event_count_30d", "cyclone_event_count_30d"]
            logger.warning(
                "Feature substitution",
                extra={
                    "source": "TimescaleDB",
                    "zone_id": zone_id,
                    "features_substituted": substituted,
                    "reason": reason,
                },
            )
            return TimescaleData(
                weather_event_freq_30d=medians.weather_event_freq_30d,
                flood_event_count_30d=medians.flood_event_count_30d,
                cyclone_event_count_30d=medians.cyclone_event_count_30d,
            )

    async def _fetch_weather(
        self, lat: float, lon: float, medians: ZoneMedians
    ) -> WeatherData:
        try:
            return await asyncio.wait_for(
                self._wx.fetch_current_conditions(lat, lon),
                timeout=_SOURCE_TIMEOUT,
            )
        except (asyncio.TimeoutError, Exception) as exc:
            reason = "timeout" if isinstance(exc, asyncio.TimeoutError) else f"error: {exc}"
            substituted = ["rainfall_mm_hr_current", "wind_speed_kmh_current", "temperature_c_current"]
            logger.warning(
                "Feature substitution",
                extra={
                    "source": "Weather_API",
                    "zone_id": f"({lat},{lon})",
                    "features_substituted": substituted,
                    "reason": reason,
                },
            )
            return WeatherData(
                rainfall_mm_hr=medians.rainfall_mm_hr,
                wind_speed_kmh=medians.wind_speed_kmh,
                temperature_c=medians.temperature_c,
            )

    async def _fetch_postgres(
        self, worker_id: str, medians: ZoneMedians
    ) -> PostgresData:
        try:
            return await asyncio.wait_for(
                self._pg.fetch_worker_profile(worker_id),
                timeout=_SOURCE_TIMEOUT,
            )
        except (asyncio.TimeoutError, Exception) as exc:
            reason = "timeout" if isinstance(exc, asyncio.TimeoutError) else f"error: {exc}"
            substituted = [
                "active_days_last_30", "avg_daily_orders", "platform_encoded",
                "tier_encoded", "zone_risk_index", "claim_velocity_90d",
            ]
            logger.warning(
                "Feature substitution",
                extra={
                    "source": "PostgreSQL",
                    "zone_id": worker_id,
                    "features_substituted": substituted,
                    "reason": reason,
                },
            )
            return PostgresData(
                active_days_last_30=medians.active_days_last_30,
                avg_daily_orders=medians.avg_daily_orders,
                platform_encoded=0.0,   # swiggy default
                tier_encoded=0.0,       # silver default
                zone_risk_index=medians.zone_risk_index,
                claim_velocity_90d=0.0,
            )
