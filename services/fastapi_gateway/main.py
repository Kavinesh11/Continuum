# Feature: continuum-ml-pipelines
import os
import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

from models import ClaimPayload, OnboardingPayload

logger = logging.getLogger(__name__)

# --- Prometheus metrics ---
unhandled_exceptions_total = Counter(
    "unhandled_exceptions_total",
    "Total number of unhandled exceptions in the FastAPI Gateway",
)

# --- Service URLs (from environment) ---
RISK_PROFILER_URL = os.getenv("RISK_PROFILER_URL", "http://localhost:8001")
CLAIMS_SCORING_URL = os.getenv("CLAIMS_SCORING_URL", "http://localhost:8002")

# --- CORS allowed origins (V2: never wildcard) ---
_raw_origins = os.getenv("ALLOWED_ORIGINS", "")
ALLOWED_ORIGINS: list[str] = [
    o.strip() for o in _raw_origins.split(",") if o.strip() and o.strip() != "*"
]


# --- App lifespan (shared async HTTP client) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.http_client = httpx.AsyncClient(timeout=10.0)
    yield
    await app.state.http_client.aclose()


app = FastAPI(title="Continuum FastAPI Gateway", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Content-Type", "Authorization"],
    max_age=86400,
)


# --- Unhandled exception middleware ---
@app.middleware("http")
async def catch_unhandled_exceptions(request: Request, call_next):
    try:
        return await call_next(request)
    except Exception as exc:
        unhandled_exceptions_total.inc()
        logger.exception("Unhandled exception: %s", exc)
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal server error"},
        )


# --- Endpoints ---

@app.get("/health")
async def health():
    """Liveness probe."""
    return {"status": "ok"}


@app.get("/metrics")
async def metrics():
    """Prometheus exposition endpoint."""
    return PlainTextResponse(
        content=generate_latest().decode("utf-8"),
        media_type=CONTENT_TYPE_LATEST,
    )


@app.post("/onboard")
async def onboard(payload: OnboardingPayload, request: Request):
    """
    Validate onboarding payload and forward to Risk_Profiler.
    Returns HTTP 422 automatically on schema failure (FastAPI/Pydantic).
    V50: timeout → 504; V51: upstream 5xx → proxied status.
    """
    client: httpx.AsyncClient = request.app.state.http_client
    try:
        response = await client.post(
            f"{RISK_PROFILER_URL}/score",
            json=payload.model_dump(mode="json"),
        )
        response.raise_for_status()
        return response.json()
    except httpx.TimeoutException:
        return JSONResponse(status_code=504, content={"detail": "Upstream timeout"})
    except httpx.HTTPStatusError as exc:
        return JSONResponse(
            status_code=exc.response.status_code,
            content={"detail": f"Upstream error {exc.response.status_code}"},
        )


@app.post("/claims/submit")
async def submit_claim(payload: ClaimPayload, request: Request):
    """
    Validate claim payload and forward to Claims_Scoring_Service.
    Returns HTTP 422 automatically on schema failure (FastAPI/Pydantic).
    V50: timeout → 504; V51: upstream 5xx → proxied status.
    """
    client: httpx.AsyncClient = request.app.state.http_client
    try:
        response = await client.post(
            f"{CLAIMS_SCORING_URL}/score",
            json=payload.model_dump(mode="json"),
        )
        response.raise_for_status()
        return response.json()
    except httpx.TimeoutException:
        return JSONResponse(status_code=504, content={"detail": "Upstream timeout"})
    except httpx.HTTPStatusError as exc:
        return JSONResponse(
            status_code=exc.response.status_code,
            content={"detail": f"Upstream error {exc.response.status_code}"},
        )
