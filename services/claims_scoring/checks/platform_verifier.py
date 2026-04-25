import os
from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx


@dataclass
class OrderCheckResult:
    orders_found: bool
    order_count: int
    provider: str


class PlatformOrderVerifier(ABC):
    @abstractmethod
    async def check_orders(
        self,
        worker_id: str,
        platform: str,
        window_start: str,
        window_end: str,
    ) -> OrderCheckResult:
        ...


class MockVerifier(PlatformOrderVerifier):
    async def check_orders(self, worker_id, platform, window_start, window_end):
        return OrderCheckResult(orders_found=False, order_count=0, provider="mock")


class SwiggyVerifier(PlatformOrderVerifier):
    def __init__(self):
        self.base_url = os.environ["SWIGGY_API_URL"]
        self.api_key = os.environ["SWIGGY_API_KEY"]

    async def check_orders(self, worker_id, platform, window_start, window_end):
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{self.base_url}/partner/orders",
                headers={"Authorization": f"Bearer {self.api_key}"},
                params={"partner_id": worker_id, "from": window_start, "to": window_end},
            )
        data = resp.json()
        count = len(data.get("orders", []))
        return OrderCheckResult(orders_found=count > 0, order_count=count, provider="swiggy")


class ZomatoVerifier(PlatformOrderVerifier):
    def __init__(self):
        self.base_url = os.environ["ZOMATO_API_URL"]
        self.api_key = os.environ["ZOMATO_API_KEY"]

    async def check_orders(self, worker_id, platform, window_start, window_end):
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                f"{self.base_url}/delivery-partner/orders",
                headers={"Authorization": f"Bearer {self.api_key}"},
                params={"partner_id": worker_id, "from": window_start, "to": window_end},
            )
        data = resp.json()
        count = len(data.get("orders", []))
        return OrderCheckResult(orders_found=count > 0, order_count=count, provider="zomato")


def create_verifier(platform: str) -> PlatformOrderVerifier:
    provider = os.getenv("PLATFORM_VERIFIER_PROVIDER", "mock")
    if provider == "prod":
        if platform == "swiggy":
            return SwiggyVerifier()
        elif platform == "zomato":
            return ZomatoVerifier()
        else:
            raise ValueError(f"Unknown platform: {platform}")
    return MockVerifier()
