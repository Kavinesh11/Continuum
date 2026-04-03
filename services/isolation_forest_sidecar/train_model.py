"""
Train and serialize a sample Isolation Forest model for dev/test.

Generates a synthetic dataset of 1 000 legitimate claim feature vectors
and trains an IsolationForest with the parameters specified in the design:

    IsolationForest(n_estimators=200, contamination=0.03, random_state=42)

The trained model is serialized with joblib to:
    model/isolation_forest.joblib

Feature vector (6 dimensions):
    [event_type_encoded, zone_id_encoded, hour_of_day,
     day_of_week, claim_velocity_7d, zone_claim_density_1h]
"""

import logging
from pathlib import Path

import joblib
import numpy as np
from sklearn.ensemble import IsolationForest

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("train_model")

# ---------------------------------------------------------------------------
# Synthetic dataset parameters
# ---------------------------------------------------------------------------

N_SAMPLES = 1_000
RANDOM_STATE = 42

# Feature ranges for legitimate claims
# [event_type_encoded, zone_id_encoded, hour_of_day,
#  day_of_week, claim_velocity_7d, zone_claim_density_1h]
FEATURE_RANGES = {
    "event_type_encoded": (0, 5),       # 6 event types (int-encoded)
    "zone_id_encoded": (0, 49),         # 50 zones (int-encoded)
    "hour_of_day": (6, 22),             # active delivery hours
    "day_of_week": (0, 6),              # 0=Monday … 6=Sunday
    "claim_velocity_7d": (0.0, 2.0),    # legitimate workers: 0–2 claims/week
    "zone_claim_density_1h": (0.0, 5.0),# normal zone density
}

OUTPUT_DIR = Path("model")
OUTPUT_PATH = OUTPUT_DIR / "isolation_forest.joblib"


def generate_synthetic_data(n_samples: int, rng: np.random.Generator) -> np.ndarray:
    """Return an (n_samples, 6) array of synthetic legitimate claim features."""
    event_type = rng.integers(
        FEATURE_RANGES["event_type_encoded"][0],
        FEATURE_RANGES["event_type_encoded"][1] + 1,
        size=n_samples,
    ).astype(float)

    zone_id = rng.integers(
        FEATURE_RANGES["zone_id_encoded"][0],
        FEATURE_RANGES["zone_id_encoded"][1] + 1,
        size=n_samples,
    ).astype(float)

    hour = rng.integers(
        FEATURE_RANGES["hour_of_day"][0],
        FEATURE_RANGES["hour_of_day"][1] + 1,
        size=n_samples,
    ).astype(float)

    day = rng.integers(
        FEATURE_RANGES["day_of_week"][0],
        FEATURE_RANGES["day_of_week"][1] + 1,
        size=n_samples,
    ).astype(float)

    velocity = rng.uniform(
        FEATURE_RANGES["claim_velocity_7d"][0],
        FEATURE_RANGES["claim_velocity_7d"][1],
        size=n_samples,
    )

    density = rng.uniform(
        FEATURE_RANGES["zone_claim_density_1h"][0],
        FEATURE_RANGES["zone_claim_density_1h"][1],
        size=n_samples,
    )

    return np.column_stack([event_type, zone_id, hour, day, velocity, density])


def train_and_save() -> None:
    rng = np.random.default_rng(RANDOM_STATE)

    logger.info("Generating %d synthetic legitimate claim feature vectors…", N_SAMPLES)
    X_train = generate_synthetic_data(N_SAMPLES, rng)
    logger.info("Feature matrix shape: %s", X_train.shape)

    logger.info(
        "Training IsolationForest(n_estimators=200, contamination=0.03, random_state=42)…"
    )
    model = IsolationForest(
        n_estimators=200,
        contamination=0.03,
        random_state=RANDOM_STATE,
    )
    model.fit(X_train)
    logger.info("Training complete.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, OUTPUT_PATH)
    logger.info("Model serialized to '%s'.", OUTPUT_PATH)

    # Quick sanity check
    sample = X_train[:5]
    scores = model.decision_function(sample)
    fraud_scores = [float(np.clip(1.0 - (s + 0.5), 0.0, 1.0)) for s in scores]
    logger.info("Sanity check – first 5 fraud scores: %s", fraud_scores)


if __name__ == "__main__":
    train_and_save()
