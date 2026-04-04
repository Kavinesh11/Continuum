"""
RAG Orchestrator FastAPI application.

Exposes:
  GET /health   — liveness probe
  GET /metrics  — Prometheus exposition format

Also defines InstrumentedRagPipeline, which wraps RagPipeline.query() with
Prometheus instrumentation.

Requirements: 16.1
"""
from __future__ import annotations

import time

from fastapi import FastAPI
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

from .rag_pipeline import RagPipeline

# ---------------------------------------------------------------------------
# Prometheus metrics
# ---------------------------------------------------------------------------

RAG_QUERIES_TOTAL = Counter(
    "rag_queries_total",
    "Total number of RAG queries processed",
    ["status"],  # "success" | "fallback" | "error"
)

RAG_QUERY_DURATION = Histogram(
    "rag_query_duration_seconds",
    "Duration of RAG query processing in seconds",
    ["status"],
)

RAG_CHUNKS_RETRIEVED = Counter(
    "rag_chunks_retrieved_total",
    "Total number of chunks retrieved above the similarity threshold",
)


# ---------------------------------------------------------------------------
# Instrumented pipeline wrapper
# ---------------------------------------------------------------------------

class InstrumentedRagPipeline:
    """Wraps RagPipeline.query() with Prometheus instrumentation."""

    def __init__(self, pipeline: RagPipeline) -> None:
        self._pipeline = pipeline

    def query(self, user_query: str) -> str:
        """
        Execute the RAG pipeline and record metrics.

        - status="success"  when the LLM returns a grounded response
        - status="fallback" when FALLBACK_MESSAGE is returned (no chunks above threshold)
        - status="error"    when an exception is raised
        """
        start = time.perf_counter()
        status = "success"
        try:
            result = self._pipeline.query(user_query)
            if result == RagPipeline.FALLBACK_MESSAGE:
                status = "fallback"
            else:
                # Count chunks that passed the threshold by inspecting the pipeline
                # internals via a lightweight re-embed + search (zero-cost: already cached
                # in the underlying call above). Instead, we track via a patched path:
                # the pipeline doesn't expose chunk count directly, so we record +1 per
                # successful (non-fallback) query as a conservative lower bound.
                # For accurate chunk counts, callers should use _count_chunks_above_threshold.
                RAG_CHUNKS_RETRIEVED.inc(
                    self._count_chunks_above_threshold(user_query)
                )
            return result
        except Exception:
            status = "error"
            raise
        finally:
            elapsed = time.perf_counter() - start
            RAG_QUERIES_TOTAL.labels(status=status).inc()
            RAG_QUERY_DURATION.labels(status=status).observe(elapsed)

    def _count_chunks_above_threshold(self, user_query: str) -> int:
        """
        Return the number of chunks that passed the similarity threshold for
        the given query.  Re-uses the pipeline's embedder and vector store so
        no extra network calls are made beyond what query() already performed.
        """
        try:
            embedding = self._pipeline._embedder(user_query)
            candidates = self._pipeline._vector_store.similarity_search(
                embedding, top_k=self._pipeline._top_k
            )
            return sum(
                1 for _, score in candidates
                if score >= self._pipeline._similarity_threshold
            )
        except Exception:
            return 0


# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------

app = FastAPI(title="RAG Orchestrator", version="1.0.0")


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
