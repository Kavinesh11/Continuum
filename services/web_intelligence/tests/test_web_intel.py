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
