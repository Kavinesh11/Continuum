"""
Platform outage oracle clients — Downdetector + synthetic ping.

Implements two oracle clients for detecting gig platform service outages
(Swiggy, Zomato) as parametric triggers:

  1. DowndetectorOracleClient — checks Downdetector for complaint spikes
  2. SyntheticPingOracleClient — pings platform API health endpoints
     from multiple geo-distributed vantage points

Both follow the OracleClient protocol used by the consensus engine.
"""
from __future__ import annotations

import asyncio
import os
import time
from dataclasses import dataclass
from datetime import datetime, timezone

import aiohttp
import structlog

from .oracles import OracleVote

logger = structlog.get_logger(__name__)

# Downdetector thresholds
DD_SPIKE_THRESHOLD = int(os.environ.get("DD_SPIKE_THRESHOLD", "500"))
DD_REQUEST_TIMEOUT = int(os.environ.get("DD_REQUEST_TIMEOUT", "10"))

# Synthetic ping configuration
PING_TIMEOUT_SECONDS = int(os.environ.get("PING_TIMEOUT_SECONDS", "10"))
PING_FAILURE_THRESHOLD = int(os.environ.get("PING_FAILURE_THRESHOLD", "2"))  # out of 3

# Platform health endpoints
PLATFORM_HEALTH_ENDPOINTS: dict[str, list[str]] = {
    "swiggy": [
        os.environ.get("SWIGGY_HEALTH_URL", "https://www.swiggy.com/dapi/health"),
    ],
    "zomato": [
        os.environ.get("ZOMATO_HEALTH_URL", "https://www.zomato.com/webroutes/health"),
    ],
}

# Downdetector API configuration
DD_API_BASE = os.environ.get("DD_API_BASE", "https://downdetectorapi.com/v2")
DD_API_KEY = os.environ.get("DD_API_KEY", "")


@dataclass
class DowndetectorReport:
    """Parsed Downdetector complaint data for a platform."""
    platform: str
    current_reports: int
    baseline_reports: int
    is_spike: bool
    fetched_at: datetime


class DowndetectorOracleClient:
    """
    Oracle client that checks Downdetector for complaint spikes on gig platforms.

    A spike is defined as: current_reports >= DD_SPIKE_THRESHOLD (default 500).

    On API error or missing key: abstains (does not affirm or deny).
    """

    def __init__(self) -> None:
        self.oracle_name = "downdetector"
        self._session: aiohttp.ClientSession | None = None

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=DD_REQUEST_TIMEOUT)
            self._session = aiohttp.ClientSession(timeout=timeout)
        return self._session

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        """
        Poll Downdetector for platform outage reports.

        Returns:
            OracleVote with vote='affirm' if spike detected, 'deny' if normal,
            'abstain' on API error.
        """
        if event_type != "platform_outage":
            return OracleVote(
                oracle_name=self.oracle_name,
                vote="abstain",
                raw_payload={"reason": f"event_type '{event_type}' not applicable"},
                data_timestamp=None,
                polled_at=datetime.now(timezone.utc),
                tls_valid=True,
            )

        if not DD_API_KEY:
            logger.warning("downdetector_api_key_not_set", oracle=self.oracle_name)
            return OracleVote(
                oracle_name=self.oracle_name,
                vote="abstain",
                raw_payload={"reason": "DD_API_KEY not configured"},
                data_timestamp=None,
                polled_at=datetime.now(timezone.utc),
                tls_valid=True,
            )

        try:
            reports = await self._fetch_reports()
            any_spike = any(r.is_spike for r in reports)

            vote = "affirm" if any_spike else "deny"
            payload = {
                "platforms": [
                    {
                        "platform": r.platform,
                        "current_reports": r.current_reports,
                        "baseline_reports": r.baseline_reports,
                        "is_spike": r.is_spike,
                    }
                    for r in reports
                ],
                "threshold": DD_SPIKE_THRESHOLD,
            }

            logger.info(
                "downdetector_poll_complete",
                vote=vote,
                platforms=[r.platform for r in reports if r.is_spike],
            )

            return OracleVote(
                oracle_name=self.oracle_name,
                vote=vote,
                raw_payload=payload,
                data_timestamp=datetime.now(timezone.utc),
                polled_at=datetime.now(timezone.utc),
                tls_valid=True,
            )
        except Exception as exc:
            logger.error("downdetector_poll_error", error=str(exc))
            return OracleVote(
                oracle_name=self.oracle_name,
                vote="abstain",
                raw_payload={"error": str(exc)},
                data_timestamp=None,
                polled_at=datetime.now(timezone.utc),
                tls_valid=False,
            )

    async def _fetch_reports(self) -> list[DowndetectorReport]:
        """Fetch current report counts from Downdetector API for all platforms."""
        session = await self._get_session()
        reports = []

        for platform in ["swiggy", "zomato"]:
            url = f"{DD_API_BASE}/companies/{platform}/reports"
            headers = {"Authorization": f"Bearer {DD_API_KEY}"}

            async with session.get(url, headers=headers) as resp:
                if resp.status != 200:
                    logger.warning(
                        "downdetector_api_non_200",
                        platform=platform,
                        status=resp.status,
                    )
                    continue

                data = await resp.json()
                current = data.get("current_reports", 0)
                baseline = data.get("baseline_reports", 0)

                reports.append(DowndetectorReport(
                    platform=platform,
                    current_reports=current,
                    baseline_reports=baseline,
                    is_spike=current >= DD_SPIKE_THRESHOLD,
                    fetched_at=datetime.now(timezone.utc),
                ))

        return reports

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()


class SyntheticPingOracleClient:
    """
    Oracle client that pings platform API health endpoints from multiple
    vantage points to detect service unavailability.

    Methodology:
      - Pings each platform's health endpoint(s)
      - If >= PING_FAILURE_THRESHOLD endpoints are unreachable → affirm
      - Each ping has a timeout of PING_TIMEOUT_SECONDS

    On complete failure to reach any vantage point: abstains.
    """

    def __init__(self) -> None:
        self.oracle_name = "synthetic_ping"
        self._session: aiohttp.ClientSession | None = None

    async def _get_session(self) -> aiohttp.ClientSession:
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=PING_TIMEOUT_SECONDS)
            self._session = aiohttp.ClientSession(timeout=timeout)
        return self._session

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        """
        Ping platform health endpoints and vote based on reachability.

        Returns:
            OracleVote with vote='affirm' if outage detected, 'deny' if healthy,
            'abstain' on error.
        """
        if event_type != "platform_outage":
            return OracleVote(
                oracle_name=self.oracle_name,
                vote="abstain",
                raw_payload={"reason": f"event_type '{event_type}' not applicable"},
                data_timestamp=None,
                polled_at=datetime.now(timezone.utc),
                tls_valid=True,
            )

        try:
            results = await self._ping_all_platforms()
            total_endpoints = sum(len(v) for v in results.values())
            failed_endpoints = sum(
                1 for v in results.values() for r in v if not r["healthy"]
            )

            outage_detected = failed_endpoints >= PING_FAILURE_THRESHOLD
            vote = "affirm" if outage_detected else "deny"

            payload = {
                "results": results,
                "total_endpoints": total_endpoints,
                "failed_endpoints": failed_endpoints,
                "threshold": PING_FAILURE_THRESHOLD,
            }

            logger.info(
                "synthetic_ping_complete",
                vote=vote,
                failed=failed_endpoints,
                total=total_endpoints,
            )

            return OracleVote(
                oracle_name=self.oracle_name,
                vote=vote,
                raw_payload=payload,
                data_timestamp=datetime.now(timezone.utc),
                polled_at=datetime.now(timezone.utc),
                tls_valid=True,
            )
        except Exception as exc:
            logger.error("synthetic_ping_error", error=str(exc))
            return OracleVote(
                oracle_name=self.oracle_name,
                vote="abstain",
                raw_payload={"error": str(exc)},
                data_timestamp=None,
                polled_at=datetime.now(timezone.utc),
                tls_valid=False,
            )

    async def _ping_all_platforms(self) -> dict:
        """Ping all platform health endpoints concurrently."""
        session = await self._get_session()
        results: dict[str, list[dict]] = {}

        async def _ping_endpoint(platform: str, url: str) -> dict:
            start = time.monotonic()
            try:
                async with session.get(url) as resp:
                    latency_ms = (time.monotonic() - start) * 1000
                    healthy = resp.status < 500
                    return {
                        "url": url,
                        "status": resp.status,
                        "latency_ms": round(latency_ms, 1),
                        "healthy": healthy,
                    }
            except (aiohttp.ClientError, asyncio.TimeoutError) as exc:
                latency_ms = (time.monotonic() - start) * 1000
                return {
                    "url": url,
                    "status": None,
                    "latency_ms": round(latency_ms, 1),
                    "healthy": False,
                    "error": str(exc),
                }

        tasks = []
        for platform, urls in PLATFORM_HEALTH_ENDPOINTS.items():
            results[platform] = []
            for url in urls:
                tasks.append((platform, _ping_endpoint(platform, url)))

        ping_results = await asyncio.gather(
            *[task for _, task in tasks], return_exceptions=True
        )

        idx = 0
        for platform, _ in tasks:
            result = ping_results[idx]
            if isinstance(result, Exception):
                results[platform].append({
                    "url": "unknown",
                    "status": None,
                    "healthy": False,
                    "error": str(result),
                })
            else:
                results[platform].append(result)
            idx += 1

        return results

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()


# Module-level singleton instances
DOWNDETECTOR_ORACLE_CLIENT = DowndetectorOracleClient()
SYNTHETIC_PING_ORACLE_CLIENT = SyntheticPingOracleClient()
