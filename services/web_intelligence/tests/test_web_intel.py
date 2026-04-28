# Feature: continuum-ml-pipelines, Property 30: Advisory Text Round-Trip
# Feature: continuum-ml-pipelines, Property 31: Malformed Scrape Resilience

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from hypothesis import given, settings
from hypothesis import strategies as st
import pytest
from unittest.mock import patch, MagicMock

from services.web_intelligence.models import DisruptionEvent
from services.web_intelligence.service import run_all_scrapers

# --- Property 30: Advisory Text Round-Trip ---

VALID_EVENT_TYPES = ["platform_outage", "weather_advisory", "lockdown"]
VALID_SEVERITIES = ["low", "medium", "high", "critical"]

@given(
    event_type=st.sampled_from(VALID_EVENT_TYPES),
    zone_id=st.text(min_size=1, max_size=50, alphabet=st.characters(blacklist_characters="|")),
    severity=st.sampled_from(VALID_SEVERITIES),
    raw_text=st.text(min_size=0, max_size=200, alphabet=st.characters(blacklist_characters="|")),
)
@settings(max_examples=100)
def test_advisory_text_round_trip(event_type, zone_id, severity, raw_text):
    # Feature: continuum-ml-pipelines, Property 30: Advisory Text Round-Trip
    # Validates: Requirements 11.7
    event = DisruptionEvent.create(
        zone_id=zone_id,
        event_type=event_type,
        severity=severity,
        source="test",
        raw_advisory_text=raw_text,
    )
    advisory_text = event.to_advisory_text()
    restored = DisruptionEvent.from_advisory_text(advisory_text)

    assert restored.event_type == event.event_type
    assert restored.zone_id == event.zone_id
    assert restored.severity == event.severity
    assert restored.raw_advisory_text == event.raw_advisory_text

# --- Property 31: Malformed Scrape Resilience ---

malformed_strategy = st.one_of(
    st.text(),
    st.binary(),
    st.none(),
    st.integers(),
    st.lists(st.text()),
    st.dictionaries(st.text(), st.text()),
    st.just(b"\x00\xff\xfe"),
    st.just(""),
    st.just("{}"),
    st.just("<not>valid</xml>"),
)

@given(malformed_content=malformed_strategy)
@settings(max_examples=100, deadline=None)
def test_imd_rss_malformed_resilience(malformed_content):
    # Feature: continuum-ml-pipelines, Property 31: Malformed Scrape Resilience
    # Validates: Requirements 11.3
    from services.web_intelligence.scrapers.imd_rss import scrape_imd_rss

    mock_feed = MagicMock()
    mock_feed.entries = malformed_content if isinstance(malformed_content, list) else []

    # feedparser is imported lazily inside scrape_imd_rss(); inject via sys.modules
    mock_feedparser = MagicMock()
    mock_feedparser.parse.return_value = mock_feed
    with patch.dict(sys.modules, {"feedparser": mock_feedparser}):
        result = scrape_imd_rss()

    assert isinstance(result, list)  # never raises, always returns list

@given(malformed_content=malformed_strategy)
@settings(max_examples=100, deadline=None)
def test_municipal_malformed_resilience(malformed_content):
    # Feature: continuum-ml-pipelines, Property 31: Malformed Scrape Resilience
    # Validates: Requirements 11.3
    from services.web_intelligence.scrapers.municipal import scrape_municipal

    mock_response = MagicMock()
    mock_response.raise_for_status = MagicMock()
    mock_response.json = MagicMock(return_value=malformed_content)

    mock_httpx = MagicMock()
    mock_httpx.get.return_value = mock_response
    with patch.dict(sys.modules, {"httpx": mock_httpx}):
        result = scrape_municipal()

    assert isinstance(result, list)

@given(malformed_content=malformed_strategy)
@settings(max_examples=100, deadline=None)
def test_run_all_scrapers_never_raises(malformed_content):
    # Feature: continuum-ml-pipelines, Property 31: Malformed Scrape Resilience
    # Validates: Requirements 11.3
    # Simulate all scrapers raising exceptions
    with patch("services.web_intelligence.service.scrape_downdetector", side_effect=Exception("boom")):
        with patch("services.web_intelligence.service.scrape_imd_rss", side_effect=Exception("boom")):
            with patch("services.web_intelligence.service.scrape_municipal", side_effect=Exception("boom")):
                result = run_all_scrapers()

    assert isinstance(result, list)


# ---------------------------------------------------------------------------
# V56 — Exception in one scraper does NOT prevent other scrapers from running
# ---------------------------------------------------------------------------

def _make_fake_scrapers(behavior: dict) -> list:
    """Build a _SCRAPERS-style list where each scraper has controlled behavior.

    behavior: {"name": callable or Exception instance}
    """
    result = []
    for name, action in behavior.items():
        if isinstance(action, Exception):
            exc = action
            fn = MagicMock(side_effect=exc)
        else:
            fn = action
        result.append((name, fn))
    return result


def test_v56_downdetector_failure_does_not_block_imd_and_municipal():
    """V56: downdetector raising must not prevent imd_rss and municipal from executing."""
    imd_event = DisruptionEvent.create("MUM", "weather_advisory", "high", "imd", "flood warning")
    municipal_event = DisruptionEvent.create("DEL", "platform_outage", "low", "municipal", "roadblock")
    imd_ran = []
    municipal_ran = []

    def fake_imd():
        imd_ran.append(True)
        return [imd_event]

    def fake_municipal():
        municipal_ran.append(True)
        return [municipal_event]

    scrapers = _make_fake_scrapers({
        "downdetector": Exception("network error"),
        "imd_rss": fake_imd,
        "municipal": fake_municipal,
    })

    with patch("services.web_intelligence.service._SCRAPERS", scrapers):
        result = run_all_scrapers()

    assert imd_ran, "imd_rss scraper was not called after downdetector failure"
    assert municipal_ran, "municipal scraper was not called after downdetector failure"
    assert len(result) == 2


def test_v56_imd_failure_does_not_block_downdetector_and_municipal():
    """V56: imd_rss raising must not prevent downdetector and municipal from executing."""
    dd_ran = []
    municipal_ran = []

    def fake_downdetector():
        dd_ran.append(True)
        return []

    def fake_municipal():
        municipal_ran.append(True)
        return []

    scrapers = _make_fake_scrapers({
        "downdetector": fake_downdetector,
        "imd_rss": Exception("parse error"),
        "municipal": fake_municipal,
    })

    with patch("services.web_intelligence.service._SCRAPERS", scrapers):
        result = run_all_scrapers()

    assert dd_ran, "downdetector scraper was not called after imd_rss failure"
    assert municipal_ran, "municipal scraper was not called after imd_rss failure"
    assert isinstance(result, list)


def test_v56_each_scraper_runs_independently():
    """V56: all scrapers run even when two of the three raise exceptions."""
    ran = []

    def make_raiser(name):
        def fn():
            ran.append(name)
            raise Exception(f"{name} failed")
        return fn

    def surviving_scraper():
        ran.append("municipal")
        return []

    scrapers = [
        ("downdetector", make_raiser("downdetector")),
        ("imd_rss", make_raiser("imd_rss")),
        ("municipal", surviving_scraper),
    ]

    with patch("services.web_intelligence.service._SCRAPERS", scrapers):
        run_all_scrapers()

    # All three scrapers must have been called
    assert "downdetector" in ran
    assert "imd_rss" in ran
    assert "municipal" in ran


# ---------------------------------------------------------------------------
# V57 — Malformed RSS/XML entry skipped without crashing the poll cycle
# ---------------------------------------------------------------------------

def test_v57_malformed_entry_skipped_valid_entry_returned():
    """V57: when feed has one malformed and one valid entry, valid entry is parsed and returned."""
    from services.web_intelligence.scrapers.imd_rss import scrape_imd_rss

    # Malformed: no attributes at all — _parse_entry will call getattr() safely (returns "")
    # so we need to simulate a case where _parse_entry raises internally
    class MalformedEntry:
        """Entry whose attribute access raises TypeError."""
        @property
        def title(self):
            raise TypeError("bad entry")

    class ValidEntry:
        title = "Flood Warning BLR Bangalore"
        summary = "Heavy rainfall expected in Bangalore zone"
        link = "http://mausam.imd.gov.in"

    mock_feed = MagicMock()
    mock_feed.entries = [MalformedEntry(), ValidEntry()]

    mock_feedparser = MagicMock()
    mock_feedparser.parse.return_value = mock_feed

    with patch.dict(sys.modules, {"feedparser": mock_feedparser}):
        result = scrape_imd_rss()

    # Malformed entry skipped; valid entry still returned
    assert isinstance(result, list)
    assert len(result) == 1
    assert result[0].event_type == "weather_advisory"


def test_v57_all_malformed_entries_returns_empty_list():
    """V57: feed with only malformed entries returns [] without crashing."""
    from services.web_intelligence.scrapers.imd_rss import scrape_imd_rss

    class AlwaysRaisesEntry:
        @property
        def title(self):
            raise ValueError("totally broken")

    mock_feed = MagicMock()
    mock_feed.entries = [AlwaysRaisesEntry(), AlwaysRaisesEntry(), AlwaysRaisesEntry()]

    mock_feedparser = MagicMock()
    mock_feedparser.parse.return_value = mock_feed

    with patch.dict(sys.modules, {"feedparser": mock_feedparser}):
        result = scrape_imd_rss()

    assert result == []


def test_v57_empty_feed_entries_returns_empty_list():
    """V57: feed with no entries returns [] without crashing."""
    from services.web_intelligence.scrapers.imd_rss import scrape_imd_rss

    mock_feed = MagicMock()
    mock_feed.entries = []

    mock_feedparser = MagicMock()
    mock_feedparser.parse.return_value = mock_feed

    with patch.dict(sys.modules, {"feedparser": mock_feedparser}):
        result = scrape_imd_rss()

    assert result == []
