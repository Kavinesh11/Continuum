# Feature: continuum-ml-pipelines, Property 1: Risk_Score Range Invariant, Property 2: Model Determinism
#
# Validates: Requirements 1.10, 2.7
#
# Property 1: For any valid 15-dimensional feature vector, the Risk_Score
#             returned by the Gradient Boosting Model must be in [0.0, 1.0].
#
# Property 2: For any feature vector, calling predict() twice with identical
#             inputs must return the exact same Risk_Score (model determinism).

from unittest.mock import MagicMock, patch

import numpy as np
import pytest
import xgboost as xgb
from hypothesis import given, settings, strategies as st
from sklearn.preprocessing import StandardScaler

from model import RiskModel

# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

# Generate arbitrary floats for each feature dimension (no NaN/inf to keep
# the booster well-behaved; extreme values test the clip behaviour).
feature_dim = st.floats(
    min_value=-1e6,
    max_value=1e6,
    allow_nan=False,
    allow_infinity=False,
)

feature_vector_st = st.lists(feature_dim, min_size=15, max_size=15)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

def _make_mock_booster(raw_value: float) -> xgb.Booster:
    """
    Build a tiny real XGBoost booster trained on synthetic data so that
    predict() returns a value that may be outside [0, 1], exercising the
    clip step.  We override the booster's predict to return a fixed raw
    value so the test is fully deterministic.
    """
    # Train a minimal booster on 4 synthetic samples (15 features each)
    X = np.zeros((4, 15), dtype=np.float32)
    y = np.array([0.0, 0.5, 1.5, -0.3], dtype=np.float32)  # intentionally outside [0,1]
    dtrain = xgb.DMatrix(X, label=y)
    booster = xgb.train({"n_estimators": 1, "max_depth": 1}, dtrain, num_boost_round=1)

    # Monkey-patch predict to return a controlled raw value so we can test
    # both in-range and out-of-range clipping.
    original_predict = booster.predict

    def _patched_predict(dmatrix, **kwargs):
        # Return an array with the desired raw value regardless of input
        n = dmatrix.num_row()
        return np.full(n, raw_value, dtype=np.float32)

    booster.predict = _patched_predict
    return booster


def _make_identity_scaler() -> StandardScaler:
    """Return a StandardScaler fitted to pass data through unchanged."""
    scaler = StandardScaler()
    # Fit on identity data: mean=0, std=1 → transform is identity
    scaler.fit(np.zeros((2, 15)))
    # Override mean_ and scale_ so transform(x) == x
    scaler.mean_ = np.zeros(15)
    scaler.scale_ = np.ones(15)
    scaler.var_ = np.ones(15)
    return scaler


@pytest.fixture
def risk_model_clipping():
    """
    RiskModel with a mock booster that returns raw=1.8 (above 1.0) to
    exercise the upper-clip path, and an identity scaler.
    """
    model = RiskModel.__new__(RiskModel)
    model._model_version = "test_v0"
    model._bucket = "test-bucket"
    import threading
    model._lock = threading.Lock()
    model._booster = _make_mock_booster(raw_value=1.8)
    model._scaler = _make_identity_scaler()
    return model


@pytest.fixture
def risk_model_negative():
    """
    RiskModel with a mock booster that returns raw=-0.5 (below 0.0) to
    exercise the lower-clip path.
    """
    model = RiskModel.__new__(RiskModel)
    model._model_version = "test_v0"
    model._bucket = "test-bucket"
    import threading
    model._lock = threading.Lock()
    model._booster = _make_mock_booster(raw_value=-0.5)
    model._scaler = _make_identity_scaler()
    return model


def _make_model_with_raw(raw_value: float) -> RiskModel:
    """Helper: build a RiskModel whose booster returns the given raw value."""
    import threading
    model = RiskModel.__new__(RiskModel)
    model._model_version = "test_v0"
    model._bucket = "test-bucket"
    model._lock = threading.Lock()
    model._booster = _make_mock_booster(raw_value=raw_value)
    model._scaler = _make_identity_scaler()
    return model


# ---------------------------------------------------------------------------
# Property 1: Risk_Score Range Invariant
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None)
@given(features=feature_vector_st)
def test_risk_score_range_invariant_upper_clip(features):
    """
    **Validates: Requirements 1.10**

    Property 1 (upper clip): When the booster returns a raw value > 1.0,
    predict() must still return a score in [0.0, 1.0] for any 15-dim input.
    """
    model = _make_model_with_raw(raw_value=1.8)
    score = model.predict(features)
    assert 0.0 <= score <= 1.0, f"Risk_Score {score} out of [0.0, 1.0] for features {features}"


@settings(max_examples=100, deadline=None)
@given(features=feature_vector_st)
def test_risk_score_range_invariant_lower_clip(features):
    """
    **Validates: Requirements 1.10**

    Property 1 (lower clip): When the booster returns a raw value < 0.0,
    predict() must still return a score in [0.0, 1.0] for any 15-dim input.
    """
    model = _make_model_with_raw(raw_value=-0.5)
    score = model.predict(features)
    assert 0.0 <= score <= 1.0, f"Risk_Score {score} out of [0.0, 1.0] for features {features}"


@settings(max_examples=100, deadline=None)
@given(
    features=feature_vector_st,
    raw=st.floats(min_value=-1e6, max_value=1e6, allow_nan=False, allow_infinity=False),
)
def test_risk_score_range_invariant_arbitrary_raw(features, raw):
    """
    **Validates: Requirements 1.10**

    Property 1 (arbitrary raw): For any 15-dim feature vector and any raw
    booster output, predict() must return a score in [0.0, 1.0].
    """
    model = _make_model_with_raw(raw_value=raw)
    score = model.predict(features)
    assert 0.0 <= score <= 1.0, (
        f"Risk_Score {score} out of [0.0, 1.0] for raw={raw}, features={features}"
    )


# ---------------------------------------------------------------------------
# Property 2: Model Determinism
# ---------------------------------------------------------------------------

@settings(max_examples=100, deadline=None)
@given(
    features=feature_vector_st,
    raw=st.floats(min_value=-1e6, max_value=1e6, allow_nan=False, allow_infinity=False),
)
def test_model_determinism(features, raw):
    """
    **Validates: Requirements 2.7**

    Property 2: Calling predict() twice with the same 15-dim feature vector
    on the same model instance must return the exact same Risk_Score.
    """
    model = _make_model_with_raw(raw_value=raw)
    score_a = model.predict(features)
    score_b = model.predict(features)
    assert score_a == score_b, (
        f"Non-deterministic: first call returned {score_a}, second returned {score_b} "
        f"for features={features}"
    )
