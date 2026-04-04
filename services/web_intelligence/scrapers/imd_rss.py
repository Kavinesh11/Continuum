"""IMD weather advisory RSS feed parser.

Parses RSS entries from the India Meteorological Department advisory feed.
Returns list[DisruptionEvent]; returns [] on any error.
"""
from __future__ import annotations

import logging
import re

from services.web_intelligence.models import DisruptionEvent

logger = logging.getLogger(__name__)

IMD_RSS_URL = "https://mausam.imd.gov.in/rss/advisories.xml"

# Known city/zone codes to extract from advisory text
_ZONE_PATTERN = re.compile(
    r"\b(MUM|DEL|BLR|HYD|CHE|KOL|PUN|AHM|JAI|LKO|PAT|BHO|IND|NGP|SUR)\b",
    re.IGNORECASE,
)

_SEVERITY_KEYWORDS: list[tuple[str, str]] = [
    ("cyclone", "critical"),
    ("flood", "critical"),
    ("warning", "high"),
    ("watch", "medium"),
    ("advisory", "low"),
]


def _severity_from_text(text: str) -> str:
    lower = text.lower()
    for keyword, severity in _SEVERITY_KEYWORDS:
        if keyword in lower:
            return severity
    return "low"


def _zone_from_text(text: str) -> str:
    match = _ZONE_PATTERN.search(text)
    return match.group(0).upper() if match else "ALL"


def _parse_entry(entry: object) -> DisruptionEvent | None:
    """Parse a single feedparser entry. Returns None on any error."""
    try:
        title: str = getattr(entry, "title", "") or ""
        summary: str = getattr(entry, "summary", "") or ""
        link: str = getattr(entry, "link", "") or ""
        combined = f"{title} {summary}"

        zone_id = _zone_from_text(combined)
        severity = _severity_from_text(combined)

        return DisruptionEvent.create(
            zone_id=zone_id,
            event_type="weather_advisory",
            severity=severity,
            source=link or IMD_RSS_URL,
            raw_advisory_text=combined.strip(),
            structured_data={"title": title, "summary": summary, "link": link},
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Failed to parse IMD RSS entry: %s", exc)
        return None


def scrape_imd_rss() -> list[DisruptionEvent]:
    """Fetch and parse the IMD RSS feed. Returns [] on any error."""
    try:
        import feedparser  # type: ignore

        feed = feedparser.parse(IMD_RSS_URL)
        events: list[DisruptionEvent] = []

        for entry in feed.entries:
            try:
                event = _parse_entry(entry)
                if event is not None:
                    events.append(event)
            except Exception as exc:  # noqa: BLE001
                logger.error("Skipping malformed IMD RSS entry: %s", exc)

        return events
    except Exception as exc:  # noqa: BLE001
        logger.error("IMD RSS scrape failed: %s", exc)
        return []
