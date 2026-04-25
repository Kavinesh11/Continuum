# Feature: continuum-ml-pipelines, Property 6: Onboarding Payload Validation
#
# Validates: Requirements 1.1, 1.2, 1.3
#
# Property 6: For any onboarding payload that is missing required fields or
# contains incorrectly typed values, the FastAPI Gateway MUST return HTTP 422
# with a structured error body that identifies each offending field.

import pytest
import httpx
from unittest.mock import patch, AsyncMock, MagicMock
from starlette.testclient import TestClient
from hypothesis import given, settings, strategies as st

from main import app

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

VALID_PAYLOAD: dict = {
    "worker_id": "worker-001",
    "zone_id": "MUM_ANDHERI_W",
    "platform": "swiggy",
    "tier": "gold",
    "gps_coordinates": [19.1136, 72.8697],
    "activity_history": [{"date": "2024-01-15", "orders": 12}],
}

REQUIRED_FIELDS = [
    "worker_id",
    "zone_id",
    "platform",
    "tier",
    "gps_coordinates",
    "activity_history",
]


def _error_locs(response_json: dict) -> list[tuple]:
    """Extract (loc[-1],) tuples from a 422 detail list."""
    return [tuple(item["loc"]) for item in response_json.get("detail", [])]


def _field_in_errors(field: str, response_json: dict) -> bool:
    """Return True if `field` appears anywhere in the 422 detail locations."""
    for item in response_json.get("detail", []):
        if field in item.get("loc", []):
            return True
    return False


# ---------------------------------------------------------------------------
# Fixture: TestClient (no running server needed)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def client():
    """
    In-process TestClient.  We patch the httpx.AsyncClient so that valid
    payloads never actually reach Risk_Profiler — but invalid payloads are
    rejected by Pydantic before the httpx call is ever made.
    """
    with patch("main.httpx.AsyncClient") as mock_cls:
        mock_instance = AsyncMock()
        mock_cls.return_value.__aenter__ = AsyncMock(return_value=mock_instance)
        mock_cls.return_value.__aexit__ = AsyncMock(return_value=False)
        with TestClient(app, raise_server_exceptions=False) as c:
            yield c


# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

# A non-empty string that is NOT a valid platform value
invalid_platform_st = st.text(min_size=1).filter(
    lambda s: s not in ("swiggy", "zomato")
)

# A non-empty string that is NOT a valid tier value
invalid_tier_st = st.text(min_size=1).filter(
    lambda s: s not in ("silver", "gold", "platinum")
)

# Non-numeric values for gps_coordinates that Pydantic v2 cannot coerce to float.
# We use strings that are NOT valid float representations, or wrong-length tuples,
# or a scalar instead of a 2-tuple.
_non_float_str_st = st.text(min_size=1).filter(
    lambda s: not _is_float_coercible(s)
)

def _is_float_coercible(v) -> bool:
    """Return True if Pydantic v2 would accept v as a float coordinate."""
    try:
        float(v)
        return True
    except (TypeError, ValueError):
        return False

invalid_gps_st = st.one_of(
    # A scalar string that is not a valid float
    _non_float_str_st,
    # A list of non-float strings (Pydantic can't coerce them)
    st.lists(_non_float_str_st, min_size=2, max_size=2),
    # Wrong length: 0, 1, or 3+ elements (tuple[float, float] requires exactly 2)
    st.lists(st.floats(allow_nan=False, allow_infinity=False), min_size=0, max_size=1),
    st.lists(st.floats(allow_nan=False, allow_infinity=False), min_size=3, max_size=5),
    # A plain scalar (not a sequence at all)
    st.none(),
)

# Strategy that picks 1..N fields to remove from the valid payload
fields_to_remove_st = st.lists(
    st.sampled_from(REQUIRED_FIELDS),
    min_size=1,
    max_size=len(REQUIRED_FIELDS),
    unique=True,
)


# ---------------------------------------------------------------------------
# Property 6a — Missing required fields → HTTP 422 with per-field detail
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None)
@given(fields_to_remove=fields_to_remove_st)
def test_missing_required_fields_returns_422(fields_to_remove):
    """
    **Validates: Requirements 1.2, 1.3**

    For any subset of required fields removed from an otherwise valid
    onboarding payload, the gateway MUST return HTTP 422 and the response
    detail list MUST reference each missing field.
    """
    payload = dict(VALID_PAYLOAD)
    for field in fields_to_remove:
        del payload[field]

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.post("/onboard", json=payload)

    assert response.status_code == 422, (
        f"Expected 422 for missing fields {fields_to_remove}, "
        f"got {response.status_code}: {response.text}"
    )
    body = response.json()
    assert "detail" in body, "422 response must contain a 'detail' key"
    assert len(body["detail"]) > 0, "detail list must be non-empty"

    # Every removed field must appear somewhere in the error locations
    for field in fields_to_remove:
        assert _field_in_errors(field, body), (
            f"Field '{field}' not found in 422 detail: {body['detail']}"
        )


# ---------------------------------------------------------------------------
# Property 6b — Invalid platform value → HTTP 422
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None)
@given(bad_platform=invalid_platform_st)
def test_invalid_platform_returns_422(bad_platform):
    """
    **Validates: Requirements 1.1, 1.2**

    Sending a platform value that is not 'swiggy' or 'zomato' MUST yield
    HTTP 422 with the 'platform' field referenced in the detail.
    """
    payload = {**VALID_PAYLOAD, "platform": bad_platform}

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.post("/onboard", json=payload)

    assert response.status_code == 422, (
        f"Expected 422 for invalid platform '{bad_platform}', "
        f"got {response.status_code}: {response.text}"
    )
    body = response.json()
    assert "detail" in body
    assert _field_in_errors("platform", body), (
        f"'platform' not in 422 detail: {body['detail']}"
    )


# ---------------------------------------------------------------------------
# Property 6c — Invalid tier value → HTTP 422
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None)
@given(bad_tier=invalid_tier_st)
def test_invalid_tier_returns_422(bad_tier):
    """
    **Validates: Requirements 1.1, 1.2**

    Sending a tier value that is not 'silver', 'gold', or 'platinum' MUST
    yield HTTP 422 with the 'tier' field referenced in the detail.
    """
    payload = {**VALID_PAYLOAD, "tier": bad_tier}

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.post("/onboard", json=payload)

    assert response.status_code == 422, (
        f"Expected 422 for invalid tier '{bad_tier}', "
        f"got {response.status_code}: {response.text}"
    )
    body = response.json()
    assert "detail" in body
    assert _field_in_errors("tier", body), (
        f"'tier' not in 422 detail: {body['detail']}"
    )


# ---------------------------------------------------------------------------
# Property 6d — Invalid gps_coordinates type → HTTP 422
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None)
@given(bad_gps=invalid_gps_st)
def test_invalid_gps_coordinates_returns_422(bad_gps):
    """
    **Validates: Requirements 1.1, 1.2**

    Sending non-numeric gps_coordinates MUST yield HTTP 422 with the
    'gps_coordinates' field referenced in the detail.
    """
    payload = {**VALID_PAYLOAD, "gps_coordinates": bad_gps}

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.post("/onboard", json=payload)

    assert response.status_code == 422, (
        f"Expected 422 for invalid gps_coordinates '{bad_gps}', "
        f"got {response.status_code}: {response.text}"
    )
    body = response.json()
    assert "detail" in body


# ---------------------------------------------------------------------------
# Sanity check — valid payload is accepted (not a property test)
# ---------------------------------------------------------------------------

def test_valid_payload_does_not_return_422():
    """
    A fully valid onboarding payload must NOT return 422.
    (The gateway may return 5xx because Risk_Profiler is not running,
    but validation itself must pass.)
    """
    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.post("/onboard", json=VALID_PAYLOAD)

    assert response.status_code != 422, (
        f"Valid payload incorrectly rejected with 422: {response.text}"
    )


# ---------------------------------------------------------------------------
# V50 — Downstream timeout (httpx.TimeoutException) → HTTP 504
# ---------------------------------------------------------------------------

VALID_CLAIM_PAYLOAD: dict = {
    "claim_id": "claim-001",
    "worker_id": "worker-001",
    "event_type": "heavy_rainfall",
    "event_timestamp": "2024-01-15T10:30:00Z",
    "gps_coordinates": [19.1136, 72.8697],
    "zone_id": "MUM_ANDHERI_W",
    "device_attestation_token": "attestation-token-abc",
}


def _make_mock_http_client() -> AsyncMock:
    """Build a mock httpx.AsyncClient for injection into app.state."""
    return AsyncMock(spec=httpx.AsyncClient)


def test_v50_onboard_timeout_returns_504():
    """V50: downstream httpx.TimeoutException on /onboard → HTTP 504."""
    with TestClient(app, raise_server_exceptions=False) as client:
        mock_http = _make_mock_http_client()
        mock_http.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
        app.state.http_client = mock_http
        response = client.post("/onboard", json=VALID_PAYLOAD)

    assert response.status_code == 504, (
        f"Expected 504 for downstream timeout, got {response.status_code}: {response.text}"
    )


def test_v50_claims_timeout_returns_504():
    """V50: downstream httpx.TimeoutException on /claims/submit → HTTP 504."""
    with TestClient(app, raise_server_exceptions=False) as client:
        mock_http = _make_mock_http_client()
        mock_http.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
        app.state.http_client = mock_http
        response = client.post("/claims/submit", json=VALID_CLAIM_PAYLOAD)

    assert response.status_code == 504, (
        f"Expected 504 for downstream timeout on /claims/submit, got {response.status_code}: {response.text}"
    )


def test_v50_timeout_response_has_detail():
    """V50: timeout 504 response must contain a 'detail' field."""
    with TestClient(app, raise_server_exceptions=False) as client:
        mock_http = _make_mock_http_client()
        mock_http.post = AsyncMock(side_effect=httpx.TimeoutException("timeout"))
        app.state.http_client = mock_http
        response = client.post("/onboard", json=VALID_PAYLOAD)

    assert "detail" in response.json()


# ---------------------------------------------------------------------------
# V51 — Downstream 5xx → gateway returns same status code
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("upstream_status", [500, 502, 503])
def test_v51_upstream_5xx_proxied_through(upstream_status: int):
    """V51: downstream N-xx status code is proxied back unchanged."""
    upstream_resp = MagicMock(spec=httpx.Response)
    upstream_resp.status_code = upstream_status
    upstream_resp.raise_for_status.side_effect = httpx.HTTPStatusError(
        message=f"Server error {upstream_status}",
        request=MagicMock(),
        response=MagicMock(status_code=upstream_status),
    )

    with TestClient(app, raise_server_exceptions=False) as client:
        mock_http = _make_mock_http_client()
        mock_http.post = AsyncMock(return_value=upstream_resp)
        app.state.http_client = mock_http
        response = client.post("/onboard", json=VALID_PAYLOAD)

    assert response.status_code == upstream_status, (
        f"Expected {upstream_status} proxied from upstream, got {response.status_code}"
    )


# ---------------------------------------------------------------------------
# V52 — /claims/submit: missing required fields → HTTP 422 with per-field detail
# ---------------------------------------------------------------------------

CLAIM_REQUIRED_FIELDS = [
    "claim_id", "worker_id", "event_type", "event_timestamp",
    "gps_coordinates", "zone_id", "device_attestation_token",
]


@pytest.mark.parametrize("field", CLAIM_REQUIRED_FIELDS)
def test_v52_missing_claim_field_returns_422(field: str):
    """V52: missing required field in /claims/submit → HTTP 422 with field in detail."""
    payload = dict(VALID_CLAIM_PAYLOAD)
    del payload[field]

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.post("/claims/submit", json=payload)

    assert response.status_code == 422, (
        f"Expected 422 when '{field}' missing, got {response.status_code}"
    )
    assert _field_in_errors(field, response.json()), (
        f"Field '{field}' not referenced in 422 detail: {response.json()}"
    )
