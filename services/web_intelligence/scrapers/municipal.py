"""Municipal lockdown advisory JSON feed parser.

Fetches and parses the municipal advisory JSON feed.
Returns list[DisruptionEvent]; returns [] on any error.
"""
from __future__ import annotations

import logging

from services.web_intelligence.models import DisruptionEvent

logger = logging.getLogger(__name__)

MUNICIPAL_API_URL = "https://api.municipal.gov.in/advisories"

_VALID_SEVERITIES = {"low", "medium", "high", "critical"}


def _parse_advisory(advisory: dict) -> DisruptionEvent | None:
    """Parse a single advisory dict. Returns None on any error."""
    try:
        zone_id = str(advisory.get("zone_id") or "ALL")
        severity_raw = str(advisory.get("severity") or "low").lower()
        severity = severity_raw if severity_raw in _VALID_SEVERITIES else "low"
        description = str(advisory.get("description") or "")
        source = str(advisory.get("source_url") or MUNICIPAL_API_URL)

        return DisruptionEvent.create(
            zone_id=zone_id,
            event_type="lockdown",
            severity=severity,
            source=source,
            raw_advisory_text=description,
            structured_data=dict(advisory),
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Failed to parse municipal advisory: %s", exc)
        return None


def scrape_municipal() -> list[DisruptionEvent]:
    """Fetch and parse the municipal advisory feed. Returns [] on any error."""
    try:
        import httpx  # type: ignore

        response = httpx.get(MUNICIPAL_API_URL, timeout=10.0)
        response.raise_for_status()
        data = response.json()

        # Accept either a list at root or {"advisories": [...]}
        if isinstance(data, list):
            advisories = data
        elif isinstance(data, dict):
            advisories = data.get("advisories") or []
        else:
            logger.error("Unexpected municipal feed format: %s", type(data))
            return []

        events: list[DisruptionEvent] = []
        for advisory in advisories:
            try:
                event = _parse_advisory(advisory)
                if event is not None:
                    events.append(event)
            except Exception as exc:  # noqa: BLE001
                logger.error("Skipping malformed municipal advisory: %s", exc)

        return events
    except Exception as exc:  # noqa: BLE001
        logger.error("Municipal advisory scrape failed: %s", exc)
        return []
