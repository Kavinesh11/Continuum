"""
VectorStoreTool — MongoDB Atlas queries for relevant policy/disruption chunks.
"""
from __future__ import annotations

import os
from typing import Any

from pydantic import BaseModel, Field


class VectorStoreInput(BaseModel):
    query: str = Field(..., description="Text query to search in the vector store")
    top_k: int = Field(default=5, description="Number of results to return")


class VectorStoreTool:
    """Tool wrapper for MongoDB Atlas vector store queries."""

    name: str = "vector_store_search"
    description: str = (
        "Search the MongoDB Atlas vector store for policy documents and "
        "disruption event summaries relevant to a claim."
    )

    def run(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        try:
            from motor.motor_asyncio import AsyncIOMotorClient  # noqa: PLC0415
            import asyncio  # noqa: PLC0415

            async def _search() -> list[dict[str, Any]]:
                client = AsyncIOMotorClient(os.environ["MONGODB_URI"])
                db = client[os.environ.get("MONGODB_DB", "continuum")]
                collection = db["policy_chunks"]
                cursor = collection.find(
                    {"$text": {"$search": query}},
                    {"content": 1, "metadata": 1, "source_type": 1},
                ).limit(top_k)
                results = []
                async for doc in cursor:
                    doc.pop("_id", None)
                    results.append(doc)
                client.close()
                return results

            loop = asyncio.new_event_loop()
            try:
                return loop.run_until_complete(_search())
            finally:
                loop.close()
        except Exception as exc:  # noqa: BLE001
            return [{"error": str(exc)}]

    def _run(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        return self.run(query, top_k)


def make_vector_store_tool():
    """Return a crewai-compatible VectorStoreTool if crewai is available."""
    try:
        from crewai.tools import BaseTool  # noqa: PLC0415

        class _VectorStoreTool(BaseTool):
            name: str = "vector_store_search"
            description: str = (
                "Search the MongoDB Atlas vector store for policy documents and "
                "disruption event summaries relevant to a claim."
            )
            args_schema: type[BaseModel] = VectorStoreInput

            def _run(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
                return VectorStoreTool().run(query, top_k)

        return _VectorStoreTool()
    except ImportError:
        return VectorStoreTool()
