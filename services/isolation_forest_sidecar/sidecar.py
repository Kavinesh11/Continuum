"""
Isolation Forest Python sidecar.

Exposes JSON-RPC over a Unix domain socket. Keeps the serialized
Isolation Forest model in memory for low-latency inference.

Score normalization:
    Fraud_Score = 1 - (raw_anomaly_score + 0.5)
    then clipped to [0.0, 1.0]

Environment variables:
    MODEL_PATH   – path to the joblib-serialized model file
                   (default: model/isolation_forest.joblib)
    SOCKET_PATH  – Unix domain socket path
                   (default: /tmp/isolation_forest.sock)

JSON-RPC request:
    {"jsonrpc": "2.0", "method": "score",
     "params": {"features": [f1, f2, f3, f4, f5, f6]}, "id": 1}

JSON-RPC response (success):
    {"jsonrpc": "2.0", "result": {"fraud_score": 0.72}, "id": 1}

JSON-RPC response (error):
    {"jsonrpc": "2.0", "error": {"code": -32603, "message": "..."}, "id": 1}

Feature vector (6 dimensions):
    [event_type_encoded, zone_id_encoded, hour_of_day,
     day_of_week, claim_velocity_7d, zone_claim_density_1h]
"""

import asyncio
import json
import logging
import os
import signal
import sys
from pathlib import Path

import joblib
import numpy as np

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MODEL_PATH = os.environ.get("MODEL_PATH", "model/isolation_forest.joblib")
SOCKET_PATH = os.environ.get("SOCKET_PATH", "/tmp/isolation_forest.sock")

FEATURE_DIM = 6

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("isolation_forest_sidecar")

# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------


def load_model(path: str):
    """Load the serialized Isolation Forest model from *path*.

    Logs a substitution warning and raises RuntimeError on failure so the
    caller can decide whether to abort startup.
    """
    model_file = Path(path)
    if not model_file.exists():
        logger.error(
            "Model file not found at '%s'. "
            "Substituting with None – inference will be unavailable.",
            path,
        )
        raise RuntimeError(f"Model file not found: {path}")
    try:
        model = joblib.load(model_file)
        logger.info("Isolation Forest model loaded from '%s'.", path)
        return model
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Failed to load model from '%s': %s. "
            "Substituting with None – inference will be unavailable.",
            path,
            exc,
        )
        raise RuntimeError(f"Model load failed: {exc}") from exc


# ---------------------------------------------------------------------------
# Score normalization
# ---------------------------------------------------------------------------


def normalize_score(raw_score: float) -> float:
    """Convert sklearn Isolation Forest raw anomaly score to Fraud_Score.

    sklearn's decision_function returns values where inliers score positive
    and outliers score negative.  The convention used here is:

        Fraud_Score = 1 - (raw_score + 0.5)

    then clipped to [0.0, 1.0].
    """
    fraud_score = 1.0 - (raw_score + 0.5)
    return float(np.clip(fraud_score, 0.0, 1.0))


# ---------------------------------------------------------------------------
# JSON-RPC helpers
# ---------------------------------------------------------------------------

JSONRPC_VERSION = "2.0"


def _ok(result: dict, req_id) -> bytes:
    payload = {"jsonrpc": JSONRPC_VERSION, "result": result, "id": req_id}
    return (json.dumps(payload) + "\n").encode()


def _err(code: int, message: str, req_id) -> bytes:
    payload = {
        "jsonrpc": JSONRPC_VERSION,
        "error": {"code": code, "message": message},
        "id": req_id,
    }
    return (json.dumps(payload) + "\n").encode()


# ---------------------------------------------------------------------------
# Request handler
# ---------------------------------------------------------------------------


def handle_request(model, raw: bytes) -> bytes:
    """Parse a JSON-RPC request and return a JSON-RPC response."""
    req_id = None
    try:
        request = json.loads(raw.decode())
    except json.JSONDecodeError as exc:
        return _err(-32700, f"Parse error: {exc}", req_id)

    req_id = request.get("id")

    if request.get("jsonrpc") != JSONRPC_VERSION:
        return _err(-32600, "Invalid Request: jsonrpc must be '2.0'", req_id)

    method = request.get("method")
    if method != "score":
        return _err(-32601, f"Method not found: {method!r}", req_id)

    params = request.get("params", {})
    features = params.get("features")

    if features is None:
        return _err(-32602, "Invalid params: 'features' is required", req_id)

    if not isinstance(features, list) or len(features) != FEATURE_DIM:
        return _err(
            -32602,
            f"Invalid params: 'features' must be a list of {FEATURE_DIM} numbers",
            req_id,
        )

    try:
        feature_array = np.array(features, dtype=np.float64).reshape(1, -1)
    except (ValueError, TypeError) as exc:
        return _err(-32602, f"Invalid params: {exc}", req_id)

    try:
        raw_score = float(model.decision_function(feature_array)[0])
        fraud_score = normalize_score(raw_score)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Inference error: %s", exc)
        return _err(-32603, f"Internal error during inference: {exc}", req_id)

    return _ok({"fraud_score": fraud_score}, req_id)


# ---------------------------------------------------------------------------
# Async connection handler
# ---------------------------------------------------------------------------


async def handle_connection(
    model, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
) -> None:
    """Handle a single client connection (newline-delimited JSON-RPC)."""
    peer = writer.get_extra_info("peername", "<unix>")
    logger.debug("New connection from %s", peer)
    try:
        while True:
            line = await reader.readline()
            if not line:
                break  # client closed connection
            response = handle_request(model, line.strip())
            writer.write(response)
            await writer.drain()
    except asyncio.CancelledError:
        pass
    except Exception as exc:  # noqa: BLE001
        logger.warning("Connection error: %s", exc)
    finally:
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:  # noqa: BLE001
            pass
        logger.debug("Connection closed.")


# ---------------------------------------------------------------------------
# Server entry point
# ---------------------------------------------------------------------------


async def run_server(model, socket_path: str) -> None:
    """Start the Unix domain socket server."""
    # Remove stale socket file if present
    sock_file = Path(socket_path)
    if sock_file.exists():
        sock_file.unlink()

    server = await asyncio.start_unix_server(
        lambda r, w: handle_connection(model, r, w),
        path=socket_path,
    )
    logger.info("Isolation Forest sidecar listening on %s", socket_path)

    # Graceful shutdown on SIGTERM / SIGINT
    loop = asyncio.get_running_loop()

    def _shutdown():
        logger.info("Shutdown signal received.")
        server.close()

    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, _shutdown)

    async with server:
        await server.serve_forever()

    logger.info("Server stopped.")


def main() -> None:
    try:
        model = load_model(MODEL_PATH)
    except RuntimeError:
        logger.critical("Cannot start sidecar without a valid model. Exiting.")
        sys.exit(1)

    asyncio.run(run_server(model, SOCKET_PATH))


if __name__ == "__main__":
    main()
