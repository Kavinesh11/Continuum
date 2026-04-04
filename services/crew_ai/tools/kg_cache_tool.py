"""
KGCacheTool — HTTP calls to the Knowledge Graph Cache service.
"""
from __future__ import annotations

import os
from typing import Any

import httpx
from pydantic import BaseModel, Field


class KGCacheInput(BaseModel):
    zone_id: str = Field(..., description="Zone identifier")
    event_type: str = Field(..., description="Event type to look up")


class KGCacheTool:
    """Tool wrapper for Knowledge Graph Cache HTTP lookups."""

    name: str = "kg_cache_lookup"
    description: str = (
        "Look up disruption events from the Knowledge Graph Cache "
        "for a given zone_id and event_type."
    )

    def run(self, zone_id: str, event_type: str) -> dict[str, Any]:
        base_url = os.environ.get("KG_CACHE_URL", "http://localhost:8080")
        url = f"{base_url}/cache/{zone_id}/{event_type}"
        try:
            resp = httpx.get(url, timeout=5.0)
            if resp.status_code == 200:
                return resp.json()
            return {"found": False, "zone_id": zone_id, "event_type": event_type}
        except Exception as exc:  # noqa: BLE001
            return {"error": str(exc), "zone_id": zone_id, "event_type": event_type}

    # crewai BaseTool compatibility
    def _run(self, zone_id: str, event_type: str) -> dict[str, Any]:
        return self.run(zone_id, event_type)


def make_kg_cache_tool():
    """Return a crewai-compatible KGCacheTool if crewai is available, else plain tool."""
    try:
        from crewai.tools import BaseTool  # noqa: PLC0415

        class _KGCacheTool(BaseTool):
            name: str = "kg_cache_lookup"
            description: str = (
                "Look up disruption events from the Knowledge Graph Cache "
                "for a given zone_id and event_type."
            )
            args_schema: type[BaseModel] = KGCacheInput

            def _run(self, zone_id: str, event_type: str) -> dict[str, Any]:
                return KGCacheTool().run(zone_id, event_type)

        return _KGCacheTool()
    except ImportError:
        return KGCacheTool()
