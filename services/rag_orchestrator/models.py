"""
Data models for the RAG Orchestrator service.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any


@dataclass
class PolicyDocument:
    """Represents a chunked policy document stored in the vector store."""

    chunk_id: str
    source_type: str  # "policy_document" | "disruption_event" | "advisory"
    content: str
    embedding: list[float]  # 768-dim BGE-Large vector
    metadata: dict[str, Any]
    created_at: datetime
    updated_at: datetime

    def to_dict(self) -> dict[str, Any]:
        """Serialize to a plain dictionary (round-trip safe)."""
        return {
            "chunk_id": self.chunk_id,
            "source_type": self.source_type,
            "content": self.content,
            "embedding": list(self.embedding),
            "metadata": dict(self.metadata),
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "PolicyDocument":
        """Deserialize from a plain dictionary (round-trip safe)."""
        return cls(
            chunk_id=d["chunk_id"],
            source_type=d["source_type"],
            content=d["content"],
            embedding=list(d["embedding"]),
            metadata=dict(d["metadata"]),
            created_at=datetime.fromisoformat(d["created_at"]),
            updated_at=datetime.fromisoformat(d["updated_at"]),
        )
