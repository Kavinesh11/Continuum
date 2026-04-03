"""Downdetector scraper using ScrapeGraph.AI SmartScraperGraph.

Scrapes Swiggy and Zomato outage reports from Downdetector India.
Returns a list[DisruptionEvent]; returns [] on any error.
"""
from __future__ import annotations

import logging
from typing import Any

from services.web_intelligence.models import DisruptionEvent

logger = logging.getLogger(__name__)

_TARGETS = {
    "swiggy": "https://downdetector.in/status/swiggy/",
    "zomato": "https://downdetector.in/status/zomato/",
}

_PROMPT = (
    "Extract the following fields from this Downdetector page: "
    "platform_name (string), current_status (string), "
    "report_count (integer), peak_time (string or null)."
)


def _severity_from_report_count(count: int) -> str:
    if count < 100:
        return "low"
    if count < 500:
        return "medium"
    if count < 2000:
        return "high"
    return "critical"


def _scrape_platform(platform: str, url: str) -> DisruptionEvent | None:
    """Scrape a single Downdetector page. Returns None on any error."""
    try:
        from scrapegraphai.graphs import SmartScraperGraph  # type: ignore

        graph = SmartScraperGraph(
            prompt=_PROMPT,
            source=url,
            config={"llm": {"model": "ollama/mistral", "temperature": 0}},
        )
        result: dict[str, Any] = graph.run()

        report_count = int(result.get("report_count") or 0)
        severity = _severity_from_report_count(report_count)
        current_status = str(result.get("current_status") or "unknown")
        peak_time = result.get("peak_time")

        raw_text = (
            f"{platform} status: {current_status}, "
            f"reports: {report_count}, peak: {peak_time}"
        )

        return DisruptionEvent.create(
            zone_id="ALL",
            event_type="platform_outage",
            severity=severity,
            source=url,
            raw_advisory_text=raw_text,
            structured_data={
                "platform": platform,
                "current_status": current_status,
                "report_count": report_count,
                "peak_time": peak_time,
            },
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Downdetector scrape failed for %s: %s", platform, exc)
        return None


def scrape_downdetector() -> list[DisruptionEvent]:
    """Scrape all configured Downdetector targets. Returns [] on total failure."""
    events: list[DisruptionEvent] = []
    for platform, url in _TARGETS.items():
        try:
            event = _scrape_platform(platform, url)
            if event is not None:
                events.append(event)
        except Exception as exc:  # noqa: BLE001
            logger.error("Unexpected error scraping %s: %s", platform, exc)
    return events
