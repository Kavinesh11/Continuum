"""
RAG Orchestrator pipeline.

Pipeline:
  Worker query
    → BGE-Large embed (768-dim vector)
    → MongoDB Atlas cosine similarity search (top-5, threshold 0.6)
    → Context assembly
    → LLM prompt (Gemini/Groq/GPT-4o)
    → Response

All external dependencies are injected so the pipeline is fully testable
without real MongoDB or LLM connections.
"""
from __future__ import annotations

from typing import Callable, Protocol

from .models import PolicyDocument


class VectorStore(Protocol):
    """Minimal interface expected from the vector store."""

    def similarity_search(
        self, embedding: list[float], top_k: int
    ) -> list[tuple[PolicyDocument, float]]:
        """Return up to *top_k* (document, score) pairs ordered by descending similarity."""
        ...


class RagPipeline:
    """
    Dependency-injectable RAG pipeline.

    Parameters
    ----------
    embedder:
        Callable that converts a query string into a 768-dim float list.
    vector_store:
        Object implementing ``similarity_search(embedding, top_k)``.
    llm_client:
        Callable that accepts a prompt string and returns the LLM response string.
    top_k:
        Maximum number of chunks to retrieve (default 5, per design spec).
    similarity_threshold:
        Minimum cosine similarity score for a chunk to be included (default 0.6).
    """

    FALLBACK_MESSAGE: str = (
        "No relevant information found. Please contact human support."
    )

    TOP_K: int = 5
    SIMILARITY_THRESHOLD: float = 0.6

    def __init__(
        self,
        embedder: Callable[[str], list[float]],
        vector_store: VectorStore,
        llm_client: Callable[[str], str],
        top_k: int = TOP_K,
        similarity_threshold: float = SIMILARITY_THRESHOLD,
    ) -> None:
        self._embedder = embedder
        self._vector_store = vector_store
        self._llm_client = llm_client
        self._top_k = top_k
        self._similarity_threshold = similarity_threshold

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def query(self, user_query: str) -> str:
        """
        Process a worker query through the full RAG pipeline.

        1. Embed the query with BGE-Large.
        2. Retrieve top-5 chunks from the vector store.
        3. Filter to chunks with similarity >= 0.6.
        4. If none pass the threshold, return FALLBACK_MESSAGE.
        5. Otherwise assemble context, build prompt, call LLM, return response.
        """
        # Step 1 — embed
        query_embedding = self._embedder(user_query)

        # Step 2 — retrieve
        candidates = self._vector_store.similarity_search(
            query_embedding, top_k=self._top_k
        )

        # Step 3 — filter by threshold
        relevant = [
            (doc, score)
            for doc, score in candidates
            if score >= self._similarity_threshold
        ]

        # Step 4 — fallback when nothing passes threshold
        if not relevant:
            return self.FALLBACK_MESSAGE

        # Step 5 — assemble context and call LLM
        context = self._assemble_context(relevant)
        prompt = self._build_prompt(user_query, context)
        return self._llm_client(prompt)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _assemble_context(chunks: list[tuple[PolicyDocument, float]]) -> str:
        """Concatenate chunk content into a single context block."""
        parts = []
        for i, (doc, score) in enumerate(chunks, start=1):
            parts.append(f"[{i}] (score={score:.4f}) {doc.content}")
        return "\n\n".join(parts)

    @staticmethod
    def _build_prompt(user_query: str, context: str) -> str:
        """Build the LLM prompt from the user query and retrieved context."""
        return (
            "You are a helpful assistant for Continuum, a parametric income protection "
            "app for gig delivery workers.\n\n"
            "Use the following context to answer the worker's question accurately. "
            "If the context does not contain enough information, say so.\n\n"
            f"Context:\n{context}\n\n"
            f"Worker question: {user_query}\n\n"
            "Answer:"
        )
