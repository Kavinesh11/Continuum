import asyncio
import json
import logging
import os

logger = logging.getLogger(__name__)


async def check_isolation_forest(feature_vector: list) -> float:
    socket_path = os.getenv("ISOLATION_FOREST_SOCKET", "/tmp/isolation_forest.sock")
    try:
        score = await _call_sidecar(socket_path, feature_vector)
        logger.info("Isolation Forest sidecar returned score=%.4f", score)
        return score
    except Exception as e:
        logger.error(
            "Isolation Forest sidecar unreachable socket=%s error=%s — routing conservatively (score=0.0)",
            socket_path, e,
        )
        return 0.0


async def _call_sidecar(socket_path: str, feature_vector: list) -> float:
    request = {
        "jsonrpc": "2.0",
        "method": "score",
        "params": {"features": list(feature_vector)},
        "id": 1,
    }
    line = json.dumps(request) + "\n"

    reader, writer = await asyncio.open_unix_connection(socket_path)
    try:
        writer.write(line.encode())
        await writer.drain()
        response_line = await reader.readline()
    finally:
        writer.close()
        await writer.wait_closed()

    response = json.loads(response_line)
    if response.get("error"):
        raise RuntimeError(f"Isolation Forest sidecar error: {response['error']}")

    fraud_score = response["result"]["fraud_score"]
    return max(0.0, min(1.0, float(fraud_score)))
