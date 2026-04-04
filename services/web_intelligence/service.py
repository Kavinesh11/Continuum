"""Web Intelligence Service — main polling loop.

Polls Downdetector, IMD RSS, and municipal advisory feeds on a configurable
interval (POLL_INTERVAL_SECONDS env var, default 300 = 5 minutes).

Usage:
    python -m services.web_intelligence.service
"""
from __future__ import annotations

import asyncio
import logging
import os
from typing import Callable

from services.web_intelligence.models import DisruptionEvent
from services.web_intelligence.scrapers.downdetector import scrape_downdetector
from services.web_intelligence.scrapers.imd_rss import scrape_imd_rss
from services.web_intelligence.scrapers.municipal import scrape_municipal

logger = logging.getLogger(__name__)

POLL_INTERVAL_SECONDS: int = int(os.environ.get("POLL_INTERVAL_SECONDS", "300"))

# All scraper callables — each returns list[DisruptionEvent]
_SCRAPERS: list[tuple[str, Callable[[], list[DisruptionEvent]]]] = [
    ("downdetector", scrape_downdetector),
    ("imd_rss", scrape_imd_rss),
    ("municipal", scrape_municipal),
]


def run_all_scrapers() -> list[DisruptionEvent]:
    """Run every scraper synchronously and aggregate results.

    Each scraper is individually wrapped so a failure in one never
    prevents the others from running.
    """
    all_events: list[DisruptionEvent] = []
    for name, scraper in _SCRAPERS:
        try:
            events = scraper()
            logger.info("Scraper '%s' returned %d events", name, len(events))
            all_events.extend(events)
        except Exception as exc:  # noqa: BLE001
            logger.error("Scraper '%s' raised an unhandled exception: %s", name, exc)
    return all_events


async def polling_loop(
    interval: int = POLL_INTERVAL_SECONDS,
    on_events: Callable[[list[DisruptionEvent]], None] | None = None,
) -> None:
    """Async polling loop. Runs scrapers, then sleeps for *interval* seconds."""
    logger.info("Web Intelligence Service starting (interval=%ds)", interval)
    while True:
        try:
            events = run_all_scrapers()
            logger.info("Polling cycle complete — %d total events", len(events))
            if on_events is not None:
                on_events(events)
        except Exception as exc:  # noqa: BLE001
            logger.error("Polling cycle error: %s", exc)
        await asyncio.sleep(interval)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(polling_loop())
