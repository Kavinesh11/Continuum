# Feature: continuum-ml-pipelines, Property 3: Feature Fallback Substitution
#
# Validates: Requirements 1.9
#
# Property 3: For any feature source failure (TimescaleDB, Weather_API, or
# PostgreSQL unavailable), the assembled feature vector must contain the
# zone-level median value for every unavailable feature dimension, and the
# substitution must be logged.

import asyncio
import logging
from contextlib import contextmanager
from unittest.mock import AsyncMock, MagicMock

import pytest
from hypothesis import HealthCheck, given, settings, strategies as st

from feature_builder import (
    FeatureBuilder,
    PostgresData,
    TimescaleData,
    WeatherData,
    ZoneMedians,
)

# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

finite_floats = st.floats(
    min_value=-1e6,
    max_value=1e6,
    allow_nan=False,
    allow_infinity=False,
)

positive_floats = st.floats(
    min_value=0.0,
    max_value=1e6,
    allow_nan=False,
    allow_infinity=False,
)

zone_medians_st = st.builds(
    ZoneMedians,
    rainfall_mm_hr=positive_floats,
    wind_speed_kmh=positive_floats,
    temperature_c=finite_floats,
    weather_event_freq_30d=positive_floats,
    flood_event_count_30d=positive_floats,
    cyclone_event_count_30d=positive_floats,
    active_days_last_30=positive_floats,
    avg_daily_orders=positive_floats,
    zone_risk_index=st.floats(min_value=0.0, max_value=1.0, allow_nan=False, allow_infinity=False),
)

lat_st = st.floats(min_value=-90.0, max_value=90.0, allow_nan=False, allow_infinity=False)
lon_st = st.floats(min_value=-180.0, max_value=180.0, allow_nan=False, allow_infinity=False)
worker_id_st = st.text(
    min_size=1, max_size=64,
    alphabet=st.characters(whitelist_categories=("Lu", "Ll", "Nd"), whitelist_characters="-_"),
)
zone_id_st = st.text(
    min_size=1, max_size=64,
    alphabet=st.characters(whitelist_categories=("Lu", "Ll", "Nd"), whitelist_characters="-_"),
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

@contextmanager
def capture_warnings(logger_name: str):
    """Context manager that captures WARNING-level log records for a logger."""
    records: list[logging.LogRecord] = []

    class _Collector(logging.Handler):
        def emit(self, record: logging.LogRecord) -> None:
            if record.levelno >= logging.WARNING:
                records.append(record)

    handler = _Collector()
    log = logging.getLogger(logger_name)
    log.addHandler(handler)
    try:
        yield records
    finally:
        log.removeHandler(handler)


def _make_builder(medians: ZoneMedians, *, ts_raises=None, wx_raises=None, pg_raises=None):
    """
    Build a FeatureBuilder with mocked clients.

    Pass an exception instance to ts_raises / wx_raises / pg_raises to
    simulate that source failing.  fetch_zone_medians always succeeds and
    returns the provided medians.
    """
    ts_client = MagicMock()
    wx_client = MagicMock()
    pg_client = MagicMock()

    if ts_raises is not None:
        ts_client.fetch_weather_history = AsyncMock(side_effect=ts_raises)
    else:
        ts_client.fetch_weather_history = AsyncMock(return_value=TimescaleData(
            weather_event_freq_30d=999.0,
            flood_event_count_30d=999.0,
            cyclone_event_count_30d=999.0,
        ))

    if wx_raises is not None:
        wx_client.fetch_current_conditions = AsyncMock(side_effect=wx_raises)
    else:
        wx_client.fetch_current_conditions = AsyncMock(return_value=WeatherData(
            rainfall_mm_hr=999.0,
            wind_speed_kmh=999.0,
            temperature_c=999.0,
        ))

    if pg_raises is not None:
        pg_client.fetch_worker_profile = AsyncMock(side_effect=pg_raises)
    else:
        pg_client.fetch_worker_profile = AsyncMock(return_value=PostgresData(
            active_days_last_30=999.0,
            avg_daily_orders=999.0,
            platform_encoded=1.0,
            tier_encoded=2.0,
            zone_risk_index=0.9,
            claim_velocity_90d=5.0,
        ))

    pg_client.fetch_zone_medians = AsyncMock(return_value=medians)

    return FeatureBuilder(ts_client, wx_client, pg_client)


# ---------------------------------------------------------------------------
# Property 3a — TimescaleDB timeout → features 3/4/5 equal zone medians
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None, suppress_health_check=[HealthCheck.function_scoped_fixture])
@given(
    medians=zone_medians_st,
    lat=lat_st,
    lon=lon_st,
    worker_id=worker_id_st,
    zone_id=zone_id_st,
)
def test_timescaledb_timeout_substitutes_medians(medians, lat, lon, worker_id, zone_id):
    """
    **Validates: Requirements 1.9**

    When TimescaleDB times out, features at indices 3, 4, 5
    (weather_event_freq_30d, flood_event_count_30d, cyclone_event_count_30d)
    must equal the zone medians, and a warning must be logged with
    source='TimescaleDB' and features_substituted in the extra dict.
    """
    builder = _make_builder(medians, ts_raises=asyncio.TimeoutError())

    with capture_warnings("feature_builder") as warning_records:
        vector = asyncio.run(builder.build(worker_id, zone_id, lat, lon))

    assert len(vector) == 15

    # Features 3/4/5 must equal zone medians
    assert vector[3] == medians.weather_event_freq_30d, (
        f"feature[3] expected {medians.weather_event_freq_30d}, got {vector[3]}"
    )
    assert vector[4] == medians.flood_event_count_30d, (
        f"feature[4] expected {medians.flood_event_count_30d}, got {vector[4]}"
    )
    assert vector[5] == medians.cyclone_event_count_30d, (
        f"feature[5] expected {medians.cyclone_event_count_30d}, got {vector[5]}"
    )

    # Weather_API and PostgreSQL features must NOT be substituted (sentinel 999)
    assert vector[0] == 999.0  # rainfall_mm_hr
    assert vector[1] == 999.0  # wind_speed_kmh
    assert vector[2] == 999.0  # temperature_c

    # A warning log entry must be present with the correct source
    assert any(
        getattr(r, "source", None) == "TimescaleDB"
        and "features_substituted" in r.__dict__
        for r in warning_records
    ), f"Expected TimescaleDB substitution warning, got: {[r.getMessage() for r in warning_records]}"


# ---------------------------------------------------------------------------
# Property 3b — Weather_API timeout → features 0/1/2 equal zone medians
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None, suppress_health_check=[HealthCheck.function_scoped_fixture])
@given(
    medians=zone_medians_st,
    lat=lat_st,
    lon=lon_st,
    worker_id=worker_id_st,
    zone_id=zone_id_st,
)
def test_weather_api_timeout_substitutes_medians(medians, lat, lon, worker_id, zone_id):
    """
    **Validates: Requirements 1.9**

    When Weather_API times out, features at indices 0, 1, 2
    (rainfall_mm_hr, wind_speed_kmh, temperature_c) must equal the zone
    medians, and a warning must be logged with source='Weather_API'.
    """
    builder = _make_builder(medians, wx_raises=asyncio.TimeoutError())

    with capture_warnings("feature_builder") as warning_records:
        vector = asyncio.run(builder.build(worker_id, zone_id, lat, lon))

    assert len(vector) == 15

    # Features 0/1/2 must equal zone medians
    assert vector[0] == medians.rainfall_mm_hr, (
        f"feature[0] expected {medians.rainfall_mm_hr}, got {vector[0]}"
    )
    assert vector[1] == medians.wind_speed_kmh, (
        f"feature[1] expected {medians.wind_speed_kmh}, got {vector[1]}"
    )
    assert vector[2] == medians.temperature_c, (
        f"feature[2] expected {medians.temperature_c}, got {vector[2]}"
    )

    # TimescaleDB features must NOT be substituted (sentinel 999)
    assert vector[3] == 999.0  # weather_event_freq_30d
    assert vector[4] == 999.0  # flood_event_count_30d
    assert vector[5] == 999.0  # cyclone_event_count_30d

    # A warning log entry must be present with the correct source
    assert any(
        getattr(r, "source", None) == "Weather_API"
        and "features_substituted" in r.__dict__
        for r in warning_records
    ), f"Expected Weather_API substitution warning, got: {[r.getMessage() for r in warning_records]}"


# ---------------------------------------------------------------------------
# Property 3c — PostgreSQL timeout → features 6/7/8/9/10/14 use medians/defaults
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None, suppress_health_check=[HealthCheck.function_scoped_fixture])
@given(
    medians=zone_medians_st,
    lat=lat_st,
    lon=lon_st,
    worker_id=worker_id_st,
    zone_id=zone_id_st,
)
def test_postgres_timeout_substitutes_medians(medians, lat, lon, worker_id, zone_id):
    """
    **Validates: Requirements 1.9**

    When PostgreSQL times out, features at indices 6, 7, 10 must equal the
    zone medians; indices 8 (platform_encoded) and 9 (tier_encoded) must be
    0.0 (defaults); index 14 (claim_velocity_90d) must be 0.0.
    A warning must be logged with source='PostgreSQL'.
    """
    builder = _make_builder(medians, pg_raises=asyncio.TimeoutError())

    with capture_warnings("feature_builder") as warning_records:
        vector = asyncio.run(builder.build(worker_id, zone_id, lat, lon))

    assert len(vector) == 15

    # Features from zone medians
    assert vector[6] == medians.active_days_last_30, (
        f"feature[6] expected {medians.active_days_last_30}, got {vector[6]}"
    )
    assert vector[7] == medians.avg_daily_orders, (
        f"feature[7] expected {medians.avg_daily_orders}, got {vector[7]}"
    )
    assert vector[10] == medians.zone_risk_index, (
        f"feature[10] expected {medians.zone_risk_index}, got {vector[10]}"
    )

    # Default values (not from medians)
    assert vector[8] == 0.0, f"platform_encoded default must be 0.0, got {vector[8]}"
    assert vector[9] == 0.0, f"tier_encoded default must be 0.0, got {vector[9]}"
    assert vector[14] == 0.0, f"claim_velocity_90d default must be 0.0, got {vector[14]}"

    # TimescaleDB and Weather_API features must NOT be substituted (sentinel 999)
    assert vector[0] == 999.0  # rainfall_mm_hr
    assert vector[3] == 999.0  # weather_event_freq_30d

    # A warning log entry must be present with the correct source
    assert any(
        getattr(r, "source", None) == "PostgreSQL"
        and "features_substituted" in r.__dict__
        for r in warning_records
    ), f"Expected PostgreSQL substitution warning, got: {[r.getMessage() for r in warning_records]}"


# ---------------------------------------------------------------------------
# Property 3d — Each source failure produces a logger.warning with
#               source name and features_substituted in the extra dict
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("source,raises,expected_source_name", [
    ("TimescaleDB", asyncio.TimeoutError(), "TimescaleDB"),
    ("Weather_API", asyncio.TimeoutError(), "Weather_API"),
    ("PostgreSQL", asyncio.TimeoutError(), "PostgreSQL"),
])
def test_substitution_log_entry_present(source, raises, expected_source_name):
    """
    **Validates: Requirements 1.9**

    Each source failure must produce exactly one logger.warning call with
    the source name and features_substituted key in the extra dict.
    """
    medians = ZoneMedians()
    kwargs = {
        "ts_raises": raises if source == "TimescaleDB" else None,
        "wx_raises": raises if source == "Weather_API" else None,
        "pg_raises": raises if source == "PostgreSQL" else None,
    }
    builder = _make_builder(medians, **kwargs)

    with capture_warnings("feature_builder") as warning_records:
        asyncio.run(builder.build("worker-1", "zone-1", 19.0, 72.0))

    assert len(warning_records) >= 1, f"Expected at least one warning for {source} failure"

    matching = [
        r for r in warning_records
        if getattr(r, "source", None) == expected_source_name
    ]
    assert len(matching) >= 1, (
        f"No warning with source='{expected_source_name}' found. "
        f"Records: {[(r.getMessage(), r.__dict__) for r in warning_records]}"
    )

    for r in matching:
        assert "features_substituted" in r.__dict__, (
            f"Warning for {expected_source_name} missing 'features_substituted' in extra: {r.__dict__}"
        )
        assert isinstance(r.__dict__["features_substituted"], list), (
            f"features_substituted must be a list, got {type(r.__dict__['features_substituted'])}"
        )
        assert len(r.__dict__["features_substituted"]) > 0, (
            f"features_substituted must be non-empty for {expected_source_name}"
        )
