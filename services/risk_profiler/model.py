# Feature: continuum-ml-pipelines
"""
RiskModel: XGBoost inference pipeline for the Risk Profiler.

Loads a serialized XGBoost booster (.ubj) and a fitted StandardScaler (.pkl)
from S3/MinIO on first use (lazy-load, thread-safe singleton pattern).

Inference pipeline:
  feature_vector (15-dim) → StandardScaler → XGBoost booster.predict()
                          → clip([0.0, 1.0]) → Risk_Score (float)

Environment variables:
  MODEL_VERSION       e.g. "xgb_v2.1.0"
  MODEL_BUCKET        S3/MinIO bucket name (default: "continuum-models")
  AWS_ENDPOINT_URL    optional MinIO override (e.g. "http://localhost:9000")
  AWS_ACCESS_KEY_ID   standard AWS credential
  AWS_SECRET_ACCESS_KEY standard AWS credential
"""

from __future__ import annotations

import logging
import os
import tempfile
import threading
from pathlib import Path
from typing import Union

import boto3
import joblib
import numpy as np
import xgboost as xgb

logger = logging.getLogger(__name__)

_DEFAULT_BUCKET = "continuum-models"


class RiskModel:
    """
    Thread-safe singleton wrapper around the XGBoost booster + StandardScaler.

    Usage:
        model = RiskModel()          # reads MODEL_VERSION from env
        score = model.predict(fv)    # fv: list[float] | np.ndarray (15-dim)
    """

    def __init__(self, model_version: str | None = None) -> None:
        self._model_version: str = model_version or os.environ["MODEL_VERSION"]
        self._bucket: str = os.environ.get("MODEL_BUCKET", _DEFAULT_BUCKET)
        self._lock = threading.Lock()
        self._booster: xgb.Booster | None = None
        self._scaler: object | None = None  # sklearn StandardScaler

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def predict(self, feature_vector: Union[list[float], "np.ndarray"]) -> float:
        """
        Run inference on a 15-dimensional feature vector.

        Steps:
          1. Convert input to numpy array (shape (1, 15))
          2. Apply StandardScaler transform
          3. Run XGBoost booster.predict()
          4. Clip result to [0.0, 1.0]
          5. Return as Python float
        """
        self._ensure_loaded()

        fv = np.asarray(feature_vector, dtype=np.float64).reshape(1, -1)
        fv_scaled = self._scaler.transform(fv)  # type: ignore[union-attr]
        dmatrix = xgb.DMatrix(fv_scaled)
        raw: np.ndarray = self._booster.predict(dmatrix)  # type: ignore[union-attr]
        score = float(np.clip(raw[0], 0.0, 1.0))
        return score

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _ensure_loaded(self) -> None:
        """Lazy-load artifacts under a lock (double-checked locking)."""
        if self._booster is not None:
            return
        with self._lock:
            if self._booster is None:
                self._load_artifacts()

    def _load_artifacts(self) -> None:
        """
        Download model.ubj and scaler.pkl from S3/MinIO into a temp directory,
        then load them into memory.

        S3 paths:
          {bucket}/{model_version}/model.ubj
          {bucket}/{model_version}/scaler.pkl
        """
        endpoint_url = os.environ.get("AWS_ENDPOINT_URL")
        s3 = boto3.client(
            "s3",
            endpoint_url=endpoint_url,  # None → standard AWS; set for MinIO
        )

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            booster_key = f"{self._model_version}/model.ubj"
            scaler_key = f"{self._model_version}/scaler.pkl"

            booster_path = tmp / "model.ubj"
            scaler_path = tmp / "scaler.pkl"

            logger.info(
                "Downloading model artifacts",
                extra={
                    "bucket": self._bucket,
                    "model_version": self._model_version,
                    "booster_key": booster_key,
                    "scaler_key": scaler_key,
                },
            )

            s3.download_file(self._bucket, booster_key, str(booster_path))
            s3.download_file(self._bucket, scaler_key, str(scaler_path))

            booster = xgb.Booster()
            booster.load_model(str(booster_path))

            scaler = joblib.load(str(scaler_path))

        # Assign after both artifacts are successfully loaded
        self._scaler = scaler
        self._booster = booster

        logger.info(
            "Model artifacts loaded",
            extra={"model_version": self._model_version},
        )
