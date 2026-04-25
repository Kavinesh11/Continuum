import logging
import threading
import time
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

TTL_SECONDS = 15 * 60  # 15 minutes (Req 11.4)


class _CacheEntry:
    __slots__ = ("value", "expires_at")

    def __init__(self, value: str, expires_at: float):
        self.value = value
        self.expires_at = expires_at


class TTLCache:
    def __init__(self, web_intel_url: str):
        self._lock = threading.Lock()
        self._entries: dict[str, _CacheEntry] = {}
        self._web_intel_url = web_intel_url

    def set(self, key: str, value: str) -> None:
        with self._lock:
            self._entries[key] = _CacheEntry(value=value, expires_at=time.monotonic() + TTL_SECONDS)

    def get(self, key: str) -> Optional[str]:
        with self._lock:
            entry = self._entries.get(key)
            if entry is None:
                return None
            if time.monotonic() > entry.expires_at:
                del self._entries[key]
                threading.Thread(
                    target=self._trigger_rescrape, args=(key,), daemon=True
                ).start()
                return None
            return entry.value

    def delete(self, key: str) -> None:
        with self._lock:
            self._entries.pop(key, None)

    def _trigger_rescrape(self, key: str) -> None:
        try:
            with httpx.Client(timeout=10.0) as client:
                resp = client.post(
                    f"{self._web_intel_url}/rescrape",
                    json={"key": key},
                )
            logger.info("Rescrape triggered key=%s status=%d", key, resp.status_code)
        except Exception as e:
            logger.error("Rescrape failed key=%s error=%s", key, e)
