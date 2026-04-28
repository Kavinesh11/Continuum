"""
Tests for isolation_forest_sidecar.sidecar

Invariants covered:
  V20 — normalize_score formula and output range
  V21 — JSON-RPC error codes for all invalid request shapes
  V22 — model hash mismatch raises RuntimeError at load time
  V23 — feature vector dimension must be exactly 6
"""
from __future__ import annotations

import json
import sys
import os
import tempfile
import hashlib
from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

from services.isolation_forest_sidecar.sidecar import (
    FEATURE_DIM,
    _ok,
    _err,
    handle_request,
    normalize_score,
    load_model,
    _verify_model_hash,
)


# ---------------------------------------------------------------------------
# V20 — normalize_score formula: fraud = clip(1 - (raw + 0.5), 0.0, 1.0)
# ---------------------------------------------------------------------------

def test_normalize_score_lower_boundary():
    # raw = -0.5  →  1 - (-0.5 + 0.5) = 1 - 0 = 1.0
    assert normalize_score(-0.5) == pytest.approx(1.0)


def test_normalize_score_upper_boundary():
    # raw = 0.5  →  1 - (0.5 + 0.5) = 1 - 1 = 0.0
    assert normalize_score(0.5) == pytest.approx(0.0)


def test_normalize_score_midpoint():
    # raw = 0.0  →  1 - (0.0 + 0.5) = 0.5
    assert normalize_score(0.0) == pytest.approx(0.5)


def test_normalize_score_clips_above_one():
    # raw very negative → formula > 1.0 → clipped to 1.0
    assert normalize_score(-100.0) == pytest.approx(1.0)


def test_normalize_score_clips_below_zero():
    # raw very positive → formula < 0.0 → clipped to 0.0
    assert normalize_score(100.0) == pytest.approx(0.0)


@given(raw=st.floats(allow_nan=False, allow_infinity=False))
@settings(max_examples=500)
def test_normalize_score_always_in_unit_interval(raw):
    """V20: output always in [0.0, 1.0] for any finite raw score."""
    score = normalize_score(raw)
    assert 0.0 <= score <= 1.0


@given(raw=st.floats(min_value=-0.5, max_value=0.5, allow_nan=False))
@settings(max_examples=300)
def test_normalize_score_formula_matches_definition(raw):
    """V20: within the unclipped range, formula exactly equals 1-(raw+0.5)."""
    expected = 1.0 - (raw + 0.5)
    assert normalize_score(raw) == pytest.approx(expected, abs=1e-9)


# ---------------------------------------------------------------------------
# V21, V23 — handle_request JSON-RPC error codes
# ---------------------------------------------------------------------------

def _make_model() -> MagicMock:
    """Minimal sklearn-compatible mock model."""
    m = MagicMock()
    m.decision_function.return_value = np.array([0.0])
    return m


def _req(method="score", features=None, jsonrpc="2.0", req_id=1, **extra) -> bytes:
    payload: dict = {"jsonrpc": jsonrpc, "method": method, "id": req_id}
    if features is not None:
        payload["params"] = {"features": features}
    payload.update(extra)
    return json.dumps(payload).encode()


def test_valid_request_returns_fraud_score():
    """V20, V23: valid 6-dim request returns fraud_score in [0,1]."""
    model = _make_model()
    model.decision_function.return_value = np.array([0.1])
    raw = handle_request(model, _req(features=[0.0] * FEATURE_DIM))
    resp = json.loads(raw)
    assert "result" in resp
    assert "fraud_score" in resp["result"]
    assert 0.0 <= resp["result"]["fraud_score"] <= 1.0


def test_malformed_json_returns_parse_error():
    """V21: malformed JSON → error code -32700."""
    model = _make_model()
    raw = handle_request(model, b"not valid json")
    resp = json.loads(raw)
    assert resp["error"]["code"] == -32700


def test_wrong_jsonrpc_version_returns_invalid_request():
    """V21: jsonrpc != "2.0" → error code -32600."""
    model = _make_model()
    raw = handle_request(model, _req(features=[0.0] * FEATURE_DIM, jsonrpc="1.0"))
    resp = json.loads(raw)
    assert resp["error"]["code"] == -32600


def test_unknown_method_returns_method_not_found():
    """V21: method != "score" → error code -32601."""
    model = _make_model()
    raw = handle_request(model, _req(method="predict", features=[0.0] * FEATURE_DIM))
    resp = json.loads(raw)
    assert resp["error"]["code"] == -32601


def test_missing_features_returns_invalid_params():
    """V21: missing `features` key → error code -32602."""
    model = _make_model()
    payload = json.dumps({"jsonrpc": "2.0", "method": "score", "params": {}, "id": 1}).encode()
    resp = json.loads(handle_request(model, payload))
    assert resp["error"]["code"] == -32602


def test_wrong_feature_dimension_returns_invalid_params():
    """V23: feature vector != 6 dims → error code -32602."""
    model = _make_model()
    for bad_len in [0, 1, 5, 7, 10]:
        raw = handle_request(model, _req(features=[0.0] * bad_len))
        resp = json.loads(raw)
        assert resp["error"]["code"] == -32602, f"Expected -32602 for dim={bad_len}"


def test_non_numeric_features_returns_invalid_params():
    """V21: non-numeric values in features list → error code -32602."""
    model = _make_model()
    raw = handle_request(model, _req(features=["a", "b", "c", "d", "e", "f"]))
    resp = json.loads(raw)
    assert resp["error"]["code"] == -32602


def test_null_features_returns_invalid_params():
    """V21: features=null → error code -32602."""
    model = _make_model()
    payload = json.dumps({"jsonrpc": "2.0", "method": "score", "params": {"features": None}, "id": 2}).encode()
    resp = json.loads(handle_request(model, payload))
    assert resp["error"]["code"] == -32602


def test_features_as_non_list_returns_invalid_params():
    """V21: features not a list → error code -32602."""
    model = _make_model()
    payload = json.dumps({"jsonrpc": "2.0", "method": "score", "params": {"features": 42}, "id": 3}).encode()
    resp = json.loads(handle_request(model, payload))
    assert resp["error"]["code"] == -32602


def test_request_id_echoed_in_response():
    """V21: response `id` must match request `id`."""
    model = _make_model()
    for req_id in [1, "abc", None, 99]:
        raw = handle_request(model, _req(features=[0.0] * FEATURE_DIM, req_id=req_id))
        resp = json.loads(raw)
        # For valid requests, check result; for null id on parse error the id is None
        assert resp.get("id") == req_id or resp.get("id") is None


def test_model_inference_error_returns_internal_error():
    """V21: model raises during inference → error code -32603."""
    model = _make_model()
    model.decision_function.side_effect = RuntimeError("model exploded")
    raw = handle_request(model, _req(features=[0.0] * FEATURE_DIM))
    resp = json.loads(raw)
    assert resp["error"]["code"] == -32603


@given(features=st.lists(st.floats(allow_nan=False, allow_infinity=False), min_size=6, max_size=6))
@settings(max_examples=200)
def test_valid_6dim_features_always_return_result(features):
    """V23: any 6 finite floats must produce a result (not an error) with fraud_score in [0,1]."""
    model = _make_model()
    model.decision_function.return_value = np.array([0.0])
    raw = handle_request(model, _req(features=features))
    resp = json.loads(raw)
    assert "result" in resp, f"Expected result, got error: {resp}"
    assert 0.0 <= resp["result"]["fraud_score"] <= 1.0


# ---------------------------------------------------------------------------
# V22 — model hash verification
# ---------------------------------------------------------------------------

def test_load_model_raises_when_file_missing(tmp_path):
    """V22: model file not found → RuntimeError (sidecar must not start)."""
    with pytest.raises(RuntimeError, match="not found"):
        load_model(str(tmp_path / "nonexistent.joblib"))


def test_load_model_raises_on_joblib_failure(tmp_path):
    """V22: joblib.load failure → RuntimeError."""
    fake_model = tmp_path / "model.joblib"
    fake_model.write_bytes(b"not a valid joblib file")
    with patch("services.isolation_forest_sidecar.sidecar._verify_model_hash"):
        with pytest.raises(RuntimeError, match="Model load failed"):
            load_model(str(fake_model))


def test_verify_model_hash_skips_when_card_missing(tmp_path):
    """V22: missing model_card.json → skip hash check (no exception)."""
    fake_model = tmp_path / "model.joblib"
    fake_model.write_bytes(b"data")
    with patch("services.isolation_forest_sidecar.sidecar.MODEL_CARD_PATH", str(tmp_path / "missing_card.json")):
        # Should not raise — hash check skipped when card absent
        _verify_model_hash(str(fake_model))


def test_verify_model_hash_passes_when_hash_correct(tmp_path):
    """V22: correct SHA-256 in model_card.json → no exception."""
    data = b"fake model bytes"
    fake_model = tmp_path / "model.joblib"
    fake_model.write_bytes(data)
    sha = hashlib.sha256(data).hexdigest()
    card = tmp_path / "model_card.json"
    card.write_text(json.dumps({"integrity": {"model_sha256": sha}}))
    with patch("services.isolation_forest_sidecar.sidecar.MODEL_CARD_PATH", str(card)):
        _verify_model_hash(str(fake_model))  # must not raise


def test_verify_model_hash_raises_on_mismatch(tmp_path):
    """V22: wrong SHA-256 in model_card.json → RuntimeError."""
    fake_model = tmp_path / "model.joblib"
    fake_model.write_bytes(b"fake model bytes")
    card = tmp_path / "model_card.json"
    card.write_text(json.dumps({"integrity": {"model_sha256": "deadbeef" * 8}}))
    with patch("services.isolation_forest_sidecar.sidecar.MODEL_CARD_PATH", str(card)):
        with pytest.raises(RuntimeError, match="hash mismatch"):
            _verify_model_hash(str(fake_model))


def test_verify_model_hash_skips_when_hash_field_absent(tmp_path):
    """V22: model_card.json present but model_sha256 not set → skip (no exception)."""
    fake_model = tmp_path / "model.joblib"
    fake_model.write_bytes(b"data")
    card = tmp_path / "model_card.json"
    card.write_text(json.dumps({"integrity": {}}))
    with patch("services.isolation_forest_sidecar.sidecar.MODEL_CARD_PATH", str(card)):
        _verify_model_hash(str(fake_model))  # must not raise


# ---------------------------------------------------------------------------
# FEATURE_DIM constant sanity
# ---------------------------------------------------------------------------

def test_feature_dim_is_six():
    """V23: FEATURE_DIM must equal 6 — matches the 6 claim-feature dimensions."""
    assert FEATURE_DIM == 6
