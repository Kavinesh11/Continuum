# Feature: continuum-ml-pipelines, Property 27: RAG Retrieval Count Bound, Property 28: RAG Similarity Threshold Fallback
# Validates: Requirements 10.3, 10.5

from __future__ import annotations

import re
import sys
import os
from datetime import datetime
from typing import List, Tuple

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

# Ensure the parent directory is on the path so the package can be imported
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from rag_orchestrator.rag_pipeline import RagPipeline
from rag_orchestrator.models import PolicyDocument

# ---------------------------------------------------------------------------
# Helpers / factories
# ---------------------------------------------------------------------------

_FIXED_EMBEDDING: List[float] = [0.0] * 768
_FIXED_DT = datetime(2024, 1, 1, 0, 0, 0)


def _make_policy_document(chunk_id: str, content: str) -> PolicyDocument:
    """Factory that creates a PolicyDocument with a fixed 768-dim zero embedding."""
    return PolicyDocument(
        chunk_id=chunk_id,
        source_type="policy_document",
        content=content,
        embedding=list(_FIXED_EMBEDDING),
        metadata={},
        created_at=_FIXED_DT,
        updated_at=_FIXED_DT,
    )


def _mock_embedder(_query: str) -> List[float]:
    """Returns a fixed 768-dim zero vector regardless of input."""
    return list(_FIXED_EMBEDDING)


def _mock_llm(_prompt: str) -> str:
    """Returns a fixed LLM response string."""
    return "llm_response"


class _MockVectorStore:
    """Vector store that returns a pre-configured list of (PolicyDocument, float) pairs."""

    def __init__(self, results: List[Tuple[PolicyDocument, float]]) -> None:
        self._results = results

    def similarity_search(
        self, embedding: List[float], top_k: int
    ) -> List[Tuple[PolicyDocument, float]]:
        # Honour the top_k limit exactly as a real store would
        return self._results[:top_k]


# ---------------------------------------------------------------------------
# Hypothesis strategies
# ---------------------------------------------------------------------------

_doc_strategy = st.builds(
    _make_policy_document,
    chunk_id=st.text(min_size=1, max_size=50),
    content=st.text(min_size=1, max_size=200),
)

# Arbitrary score in [0.0, 1.0] for Property 27
_arbitrary_score = st.floats(min_value=0.0, max_value=1.0, allow_nan=False)

# Score strictly below threshold for Property 28
_below_threshold_score = st.floats(
    min_value=0.0, max_value=0.5999999, allow_nan=False
)

_results_strategy = st.lists(
    st.tuples(_doc_strategy, _arbitrary_score),
    min_size=0,
    max_size=10,
)

_below_threshold_results_strategy = st.lists(
    st.tuples(_doc_strategy, _below_threshold_score),
    min_size=0,
    max_size=10,
)


# ---------------------------------------------------------------------------
# Property 27: RAG Retrieval Count Bound
# ---------------------------------------------------------------------------

@settings(max_examples=100)
@given(raw_results=_results_strategy)
def test_property_27_rag_retrieval_count_bound(
    raw_results: List[Tuple[PolicyDocument, float]]
) -> None:
    """
    Property 27: RAG Retrieval Count Bound
    Validates: Requirements 10.3

    For any vector store that returns between 0 and 10 results, the pipeline
    must never use more than 5 chunks in context assembly.  We verify this by
    counting the numbered context markers ([1], [2], …) in the LLM prompt
    captured via a spy, OR by confirming the fallback message is returned when
    no chunk passes the similarity threshold.
    """
    captured_prompts: List[str] = []

    def spy_llm(prompt: str) -> str:
        captured_prompts.append(prompt)
        return "llm_response"

    store = _MockVectorStore(raw_results)
    pipeline = RagPipeline(
        embedder=_mock_embedder,
        vector_store=store,
        llm_client=spy_llm,
    )

    result = pipeline.query("test query")

    if result == RagPipeline.FALLBACK_MESSAGE:
        # Fallback path — no context was assembled, constraint trivially satisfied
        assert len(captured_prompts) == 0
    else:
        # LLM was called — count numbered context blocks in the prompt
        assert len(captured_prompts) == 1
        prompt = captured_prompts[0]
        # Context markers are formatted as "[N]" by _assemble_context
        markers = re.findall(r"\[\d+\]", prompt)
        assert len(markers) <= RagPipeline.TOP_K, (
            f"Expected at most {RagPipeline.TOP_K} context blocks, "
            f"found {len(markers)}: {markers}"
        )


# ---------------------------------------------------------------------------
# Property 28: RAG Similarity Threshold Fallback
# ---------------------------------------------------------------------------

@settings(max_examples=100)
@given(raw_results=_below_threshold_results_strategy)
def test_property_28_rag_similarity_threshold_fallback(
    raw_results: List[Tuple[PolicyDocument, float]]
) -> None:
    """
    Property 28: RAG Similarity Threshold Fallback
    Validates: Requirements 10.5

    When ALL similarity scores returned by the vector store are < 0.6, the
    pipeline must return exactly RagPipeline.FALLBACK_MESSAGE.
    """
    store = _MockVectorStore(raw_results)
    pipeline = RagPipeline(
        embedder=_mock_embedder,
        vector_store=store,
        llm_client=_mock_llm,
    )

    result = pipeline.query("test query")

    assert result == RagPipeline.FALLBACK_MESSAGE, (
        f"Expected fallback message when all scores < 0.6, got: {result!r}"
    )


# Property 29: Policy Document Round-Trip
# Validates: Requirements 10.7

from datetime import timezone
from hypothesis import HealthCheck


@settings(max_examples=100, suppress_health_check=[HealthCheck.large_base_example])
@given(
    chunk_id=st.text(min_size=1, max_size=50),
    source_type=st.sampled_from(["policy_document", "disruption_event", "advisory"]),
    content=st.text(min_size=1, max_size=500),
    embedding=st.lists(
        st.floats(allow_nan=False, allow_infinity=False),
        min_size=768,
        max_size=768,
    ),
    created_at=st.datetimes(timezones=st.just(timezone.utc)),
    updated_at=st.datetimes(timezones=st.just(timezone.utc)),
)
def test_property_29_policy_document_round_trip(
    chunk_id: str,
    source_type: str,
    content: str,
    embedding: list,
    created_at: datetime,
    updated_at: datetime,
) -> None:
    """
    Property 29: Policy Document Round-Trip
    Validates: Requirements 10.7

    Arbitrary valid PolicyDocument instances must survive a to_dict() /
    from_dict() round-trip with all fields equal to the originals.
    """
    original = PolicyDocument(
        chunk_id=chunk_id,
        source_type=source_type,
        content=content,
        embedding=embedding,
        metadata={},
        created_at=created_at,
        updated_at=updated_at,
    )

    serialized = original.to_dict()
    restored = PolicyDocument.from_dict(serialized)

    assert restored.chunk_id == original.chunk_id
    assert restored.source_type == original.source_type
    assert restored.content == original.content
    assert restored.embedding == original.embedding
    assert restored.metadata == original.metadata
    assert restored.created_at == original.created_at
    assert restored.updated_at == original.updated_at
