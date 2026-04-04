"""
HTTP client for authenticated calls to the Core_Backend REST API.

All methods return an empty dict on any HTTP or network error so that the
RASA handler can degrade gracefully without crashing.
"""
from __future__ import annotations

import logging
from typing import Any

import httpx

logger = logging.getLogger(__name__)


class CoreBackendClient:
    """Async HTTP client wrapping Core_Backend REST endpoints."""

    def __init__(self, base_url: str, jwt_token: str) -> None:
        self._base_url = base_url.rstrip("/")
        self._jwt_token = jwt_token

    @property
    def _auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self._jwt_token}"}

    async def get_policy_context(self, worker_id: str) -> dict[str, Any]:
        """GET /policies — returns policy data for the worker or {} on error."""
        url = f"{self._base_url}/policies"
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    url,
                    headers=self._auth_headers,
                    params={"worker_id": worker_id},
                    timeout=10.0,
                )
                response.raise_for_status()
                return response.json()
        except Exception as exc:
            logger.error(
                "core_backend_get_policy_error",
                extra={"worker_id": worker_id, "error": str(exc)},
            )
            return {}

    async def get_claim_status(self, worker_id: str, claim_id: str) -> dict[str, Any]:
        """GET /claims/{claim_id}/status — returns claim status or {} on error."""
        url = f"{self._base_url}/claims/{claim_id}/status"
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    url,
                    headers=self._auth_headers,
                    params={"worker_id": worker_id},
                    timeout=10.0,
                )
                response.raise_for_status()
                return response.json()
        except Exception as exc:
            logger.error(
                "core_backend_get_claim_error",
                extra={"worker_id": worker_id, "claim_id": claim_id, "error": str(exc)},
            )
            return {}

    async def get_payout_history(self, worker_id: str) -> dict[str, Any]:
        """GET /payouts — returns payout history for the worker or {} on error."""
        url = f"{self._base_url}/payouts"
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    url,
                    headers=self._auth_headers,
                    params={"worker_id": worker_id},
                    timeout=10.0,
                )
                response.raise_for_status()
                return response.json()
        except Exception as exc:
            logger.error(
                "core_backend_get_payout_error",
                extra={"worker_id": worker_id, "error": str(exc)},
            )
            return {}
