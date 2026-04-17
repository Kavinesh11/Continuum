"""
Oracle polling clients with certificate pinning.
Each client polls its respective API and returns an OracleVote.
"""
from __future__ import annotations

import hashlib
import os
import ssl
import socket
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Literal

import httpx
import structlog

logger = structlog.get_logger(__name__)

VoteType = Literal["affirm", "deny", "abstain", "nullified"]


@dataclass
class OracleVote:
    oracle_name: str
    vote: VoteType
    data_timestamp: datetime | None
    polled_at: datetime
    tls_valid: bool
    raw_payload: dict[str, Any] = field(default_factory=dict)


def _get_pinned_fingerprints(env_var: str) -> list[str]:
    """Return expected SHA-256 fingerprints (current + rotation slot) from env vars.

    Supports dual-pin rotation: checks both ENV_VAR and ENV_VAR_NEXT.
    Returns empty list if neither is set (pinning disabled).
    """
    fps = []
    current = os.environ.get(env_var)
    if current:
        fps.append(current.lower())
    next_fp = os.environ.get(f"{env_var}_NEXT")
    if next_fp:
        fps.append(next_fp.lower())
    return fps


def _build_ssl_context() -> ssl.SSLContext:
    """Build a strict SSL context (verify certs, no self-signed)."""
    ctx = ssl.create_default_context()
    return ctx


def _verify_fingerprint(cert_der: bytes, expected_fps: list[str]) -> bool:
    """Return True if cert fingerprint matches any expected pin, or if no pins are configured."""
    if not expected_fps:
        return True
    actual_fp = hashlib.sha256(cert_der).hexdigest().lower()
    return actual_fp in expected_fps


async def _poll_with_pinning(
    url: str,
    fingerprint_env: str,
    oracle_name: str,
    timeout: float = 10.0,
) -> tuple[dict[str, Any] | None, bool]:
    """
    Perform an HTTPS GET with certificate pinning.

    Returns (response_json, tls_valid).
    On TLS mismatch: logs anomaly, returns (None, False).
    On timeout/connection error: returns (None, True) — tls_valid is irrelevant but True to distinguish.
    """
    expected_fps = _get_pinned_fingerprints(fingerprint_env)
    ssl_ctx = _build_ssl_context()

    try:
        async with httpx.AsyncClient(verify=ssl_ctx, timeout=timeout) as client:
            response = await client.get(url)
            response.raise_for_status()

            # Verify fingerprint via the underlying socket if pins are configured
            if expected_fps:
                # httpx exposes the SSL object via the transport stream
                try:
                    raw_stream = response.stream  # type: ignore[attr-defined]
                    ssl_obj = getattr(raw_stream, "_stream", None)
                    if ssl_obj is not None:
                        cert_der = ssl_obj.getpeercert(binary_form=True)
                        if cert_der and not _verify_fingerprint(cert_der, expected_fps):
                            logger.warning(
                                "tls_fingerprint_mismatch",
                                oracle=oracle_name,
                                expected=expected_fps,
                            )
                            return None, False
                except Exception:
                    # If we can't extract the cert, treat as mismatch when pinning is required
                    logger.warning(
                        "tls_cert_extraction_failed",
                        oracle=oracle_name,
                    )
                    return None, False

            return response.json(), True

    except ssl.SSLCertVerificationError as exc:
        logger.warning(
            "tls_cert_verification_error",
            oracle=oracle_name,
            error=str(exc),
        )
        return None, False
    except (httpx.ConnectError, httpx.TimeoutException, httpx.HTTPStatusError) as exc:
        logger.info(
            "oracle_request_failed",
            oracle=oracle_name,
            error=str(exc),
        )
        return None, True  # network failure, not TLS mismatch


class OracleClient:
    """Base class for oracle polling clients."""

    name: str = "base"
    base_url_env: str = ""
    fingerprint_env: str = ""
    threshold_key: str = ""  # key in response JSON to check for affirmative condition

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        raise NotImplementedError

    def _build_url(self, zone_id: str, event_type: str) -> str:
        base = os.environ.get(self.base_url_env, "")
        return f"{base}?zone_id={zone_id}&event_type={event_type}"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        """Override in subclasses to implement threshold logic."""
        return bool(payload.get("affirmative", False))

    def _extract_data_timestamp(self, payload: dict[str, Any]) -> datetime | None:
        ts_str = payload.get("data_timestamp") or payload.get("timestamp")
        if ts_str is None:
            return None
        try:
            return datetime.fromisoformat(str(ts_str).replace("Z", "+00:00"))
        except ValueError:
            return None


class IMDOracleClient(OracleClient):
    """India Meteorological Department Primary API."""

    name = "imd"
    base_url_env = "IMD_API_BASE_URL"
    fingerprint_env = "IMD_CERT_FINGERPRINT"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        rainfall = payload.get("rainfall_mm_hr", 0.0)
        threshold = float(os.environ.get("IMD_RAINFALL_THRESHOLD_MM_HR", "10.0"))
        return float(rainfall) >= threshold

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        polled_at = datetime.now(timezone.utc)
        url = self._build_url(zone_id, event_type)
        payload, tls_valid = await _poll_with_pinning(url, self.fingerprint_env, self.name)

        if not tls_valid:
            logger.warning("oracle_vote_nullified", oracle=self.name, reason="tls_mismatch")
            return OracleVote(
                oracle_name=self.name,
                vote="nullified",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=False,
            )
        if payload is None:
            return OracleVote(
                oracle_name=self.name,
                vote="abstain",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=True,
            )

        data_ts = self._extract_data_timestamp(payload)
        vote: VoteType = "affirm" if self._is_affirmative(payload) else "deny"
        return OracleVote(
            oracle_name=self.name,
            vote=vote,
            data_timestamp=data_ts,
            polled_at=polled_at,
            tls_valid=True,
            raw_payload=payload,
        )


class AccuWeatherOracleClient(OracleClient):
    """AccuWeather commercial feed."""

    name = "accuweather"
    base_url_env = "ACCUWEATHER_API_BASE_URL"
    fingerprint_env = "ACCUWEATHER_CERT_FINGERPRINT"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        precip_probability = payload.get("precipitation_probability", 0)
        threshold = float(os.environ.get("ACCUWEATHER_PRECIP_THRESHOLD", "70.0"))
        return float(precip_probability) >= threshold

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        polled_at = datetime.now(timezone.utc)
        url = self._build_url(zone_id, event_type)
        payload, tls_valid = await _poll_with_pinning(url, self.fingerprint_env, self.name)

        if not tls_valid:
            logger.warning("oracle_vote_nullified", oracle=self.name, reason="tls_mismatch")
            return OracleVote(
                oracle_name=self.name,
                vote="nullified",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=False,
            )
        if payload is None:
            return OracleVote(
                oracle_name=self.name,
                vote="abstain",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=True,
            )

        data_ts = self._extract_data_timestamp(payload)
        vote: VoteType = "affirm" if self._is_affirmative(payload) else "deny"
        return OracleVote(
            oracle_name=self.name,
            vote=vote,
            data_timestamp=data_ts,
            polled_at=polled_at,
            tls_valid=True,
            raw_payload=payload,
        )


class NASAGPMOracleClient(OracleClient):
    """NASA GPM satellite precipitation API."""

    name = "nasa_gpm"
    base_url_env = "NASA_GPM_API_BASE_URL"
    fingerprint_env = "NASA_GPM_CERT_FINGERPRINT"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        precip_rate = payload.get("precipitation_rate_mm_hr", 0.0)
        threshold = float(os.environ.get("NASA_GPM_PRECIP_THRESHOLD_MM_HR", "5.0"))
        return float(precip_rate) >= threshold

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        polled_at = datetime.now(timezone.utc)
        url = self._build_url(zone_id, event_type)
        payload, tls_valid = await _poll_with_pinning(url, self.fingerprint_env, self.name)

        if not tls_valid:
            logger.warning("oracle_vote_nullified", oracle=self.name, reason="tls_mismatch")
            return OracleVote(
                oracle_name=self.name,
                vote="nullified",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=False,
            )
        if payload is None:
            return OracleVote(
                oracle_name=self.name,
                vote="abstain",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=True,
            )

        data_ts = self._extract_data_timestamp(payload)
        vote: VoteType = "affirm" if self._is_affirmative(payload) else "deny"
        return OracleVote(
            oracle_name=self.name,
            vote=vote,
            data_timestamp=data_ts,
            polled_at=polled_at,
            tls_valid=True,
            raw_payload=payload,
        )


class GroundSensorOracleClient(OracleClient):
    """Ground-level sensor aggregation."""

    name = "ground_sensor"
    base_url_env = "GROUND_SENSOR_API_BASE_URL"
    fingerprint_env = "GROUND_SENSOR_CERT_FINGERPRINT"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        sensor_alert = payload.get("alert_active", False)
        return bool(sensor_alert)

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        polled_at = datetime.now(timezone.utc)
        url = self._build_url(zone_id, event_type)
        payload, tls_valid = await _poll_with_pinning(url, self.fingerprint_env, self.name)

        if not tls_valid:
            logger.warning("oracle_vote_nullified", oracle=self.name, reason="tls_mismatch")
            return OracleVote(
                oracle_name=self.name,
                vote="nullified",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=False,
            )
        if payload is None:
            return OracleVote(
                oracle_name=self.name,
                vote="abstain",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=True,
            )

        data_ts = self._extract_data_timestamp(payload)
        vote: VoteType = "affirm" if self._is_affirmative(payload) else "deny"
        return OracleVote(
            oracle_name=self.name,
            vote=vote,
            data_timestamp=data_ts,
            polled_at=polled_at,
            tls_valid=True,
            raw_payload=payload,
        )


class CPCBOracleClient(OracleClient):
    """Central Pollution Control Board — CAAQMS AQI oracle."""

    name = "cpcb"
    base_url_env = "CPCB_API_BASE_URL"
    fingerprint_env = "CPCB_CERT_FINGERPRINT"

    def _build_url(self, zone_id: str, event_type: str) -> str:
        base = os.environ.get(self.base_url_env, "")
        return f"{base}/aqi?zone_id={zone_id}"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        aqi = float(payload.get("aqi", 0))
        threshold = float(os.environ.get("CPCB_AQI_THRESHOLD", "300"))
        return aqi >= threshold

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        polled_at = datetime.now(timezone.utc)
        url = self._build_url(zone_id, event_type)
        payload, tls_valid = await _poll_with_pinning(url, self.fingerprint_env, self.name)

        if not tls_valid:
            logger.warning("oracle_vote_nullified", oracle=self.name, reason="tls_mismatch")
            return OracleVote(
                oracle_name=self.name,
                vote="nullified",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=False,
            )
        if payload is None:
            return OracleVote(
                oracle_name=self.name,
                vote="abstain",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=True,
            )

        data_ts = self._extract_data_timestamp(payload)
        vote: VoteType = "affirm" if self._is_affirmative(payload) else "deny"
        return OracleVote(
            oracle_name=self.name,
            vote=vote,
            data_timestamp=data_ts,
            polled_at=polled_at,
            tls_valid=True,
            raw_payload=payload,
        )


class ForecastOracleClient(OracleClient):
    """IMD 72-hour forecast oracle for adverse-selection enrollment lockout."""

    name = "imd_forecast"
    base_url_env = "IMD_FORECAST_API_BASE_URL"
    fingerprint_env = "IMD_FORECAST_CERT_FINGERPRINT"

    def _build_url(self, zone_id: str, event_type: str) -> str:
        base = os.environ.get(self.base_url_env, "")
        return f"{base}/forecast?zone_id={zone_id}&hours_ahead=72"

    def _is_affirmative(self, payload: dict[str, Any]) -> bool:
        """Returns True when the 72-hour forecast exceeds the high-risk threshold."""
        severity = payload.get("forecast_severity", "")
        probability = float(payload.get("event_probability", 0.0))
        threshold = float(os.environ.get("FORECAST_LOCKOUT_PROBABILITY", "0.70"))
        return severity in ("red", "orange") or probability >= threshold

    async def poll(self, zone_id: str, event_type: str) -> OracleVote:
        polled_at = datetime.now(timezone.utc)
        url = self._build_url(zone_id, event_type)
        payload, tls_valid = await _poll_with_pinning(url, self.fingerprint_env, self.name)

        if not tls_valid:
            logger.warning("oracle_vote_nullified", oracle=self.name, reason="tls_mismatch")
            return OracleVote(
                oracle_name=self.name,
                vote="nullified",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=False,
            )
        if payload is None:
            return OracleVote(
                oracle_name=self.name,
                vote="abstain",
                data_timestamp=None,
                polled_at=polled_at,
                tls_valid=True,
            )

        data_ts = self._extract_data_timestamp(payload)
        vote: VoteType = "affirm" if self._is_affirmative(payload) else "deny"
        return OracleVote(
            oracle_name=self.name,
            vote=vote,
            data_timestamp=data_ts,
            polled_at=polled_at,
            tls_valid=True,
            raw_payload=payload,
        )


# Platform outage oracle clients (lazy import to avoid circular deps)
from .platform_outage import (
    DOWNDETECTOR_ORACLE_CLIENT,
    SYNTHETIC_PING_ORACLE_CLIENT,
)

# Core oracle clients — weather triggers use all 5, AQI uses CPCB + subset
ALL_ORACLE_CLIENTS: list[OracleClient] = [
    IMDOracleClient(),
    AccuWeatherOracleClient(),
    NASAGPMOracleClient(),
    GroundSensorOracleClient(),
    CPCBOracleClient(),
]

# Event-type → oracle mapping for weighted consensus
ORACLE_SETS: dict[str, list[OracleClient]] = {
    "heavy_rainfall": [IMDOracleClient(), AccuWeatherOracleClient(), NASAGPMOracleClient(), GroundSensorOracleClient()],
    "cyclone": [IMDOracleClient(), AccuWeatherOracleClient(), NASAGPMOracleClient(), GroundSensorOracleClient()],
    "aqi": [CPCBOracleClient(), GroundSensorOracleClient(), IMDOracleClient()],
    "platform_outage": [DOWNDETECTOR_ORACLE_CLIENT, SYNTHETIC_PING_ORACLE_CLIENT, GroundSensorOracleClient()],
}

FORECAST_ORACLE_CLIENT = ForecastOracleClient()
