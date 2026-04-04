"""
RASA Assistant FastAPI application.

Endpoints:
  POST /message  — classify intent and return a response
  GET  /health   — liveness probe
  GET  /metrics  — Prometheus exposition format

Environment variables:
  RASA_MODEL_PATH   — optional path to a trained RASA NLU model
  CORE_BACKEND_URL  — base URL for Core_Backend (default: http://localhost:3000)
"""
from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.responses import Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

from .intent_classifier import IntentClassifier
from .indic_conformer import IndicConformerClient
from .models import MessageRequest, MessageResponse
from .rasa_handler import RasaHandler

# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------

RASA_MESSAGES_TOTAL = Counter(
    "rasa_messages_total",
    "Total number of messages processed by the RASA assistant",
    ["intent", "escalated"],
)

RASA_ESCALATIONS_TOTAL = Counter(
    "rasa_escalations_total",
    "Total number of conversations escalated to a human agent",
)

# ---------------------------------------------------------------------------
# Service initialisation
# ---------------------------------------------------------------------------

_rasa_model_path: str | None = os.environ.get("RASA_MODEL_PATH") or None
_core_backend_url: str = os.environ.get("CORE_BACKEND_URL", "http://localhost:3000")

_indic_model_name: str = os.environ.get("INDIC_MODEL_NAME", "ai4bharat/indic-bert")
_indic_use_stub: bool = os.environ.get("INDIC_USE_STUB", "true").lower() not in ("false", "0", "no")

_classifier = IntentClassifier(rasa_model_path=_rasa_model_path)
_indic_client = IndicConformerClient(model_name=_indic_model_name, use_stub=_indic_use_stub)
_handler = RasaHandler(
    classifier=_classifier,
    core_backend_base_url=_core_backend_url,
    indic_client=_indic_client,
)

# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------

app = FastAPI(title="RASA Assistant", version="1.0.0")


@app.post("/message", response_model=MessageResponse)
async def message(request: MessageRequest) -> MessageResponse:
    """Classify intent and return a structured response to the worker."""
    response = await _handler.handle(request)
    RASA_MESSAGES_TOTAL.labels(
        intent=response.intent,
        escalated=str(response.escalated).lower(),
    ).inc()
    if response.escalated:
        RASA_ESCALATIONS_TOTAL.inc()
    return response


@app.get("/health")
def health() -> dict:
    """Liveness probe."""
    return {"status": "ok"}


@app.get("/metrics")
def metrics() -> Response:
    """Prometheus metrics endpoint in exposition format."""
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )
