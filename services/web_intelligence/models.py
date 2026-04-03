"""DisruptionEvent dataclass with JSON serialization and advisory text round-trip."""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime, timedelta, timezone
from typing import Any


@dataclass
class DisruptionEvent:
    event_id: str
    zone_id: str
    event_type: str   # "platform_outage" | "weather_advisory" | "lockdown"
    severity: str     # "low" | "medium" | "high" | "critical"
    source: str
    raw_advisory_text: str
    structured_data: dict
    scraped_at: datetime
    ttl_expires_at: datetime

    # ------------------------------------------------------------------
    # Factory helpers
    # ------------------------------------------------------------------

    @classmethod
    def create(
        cls,
        zone_id: str,
        event_type: str,
        severity: str,
        source: str,
        raw_advisory_text: str,
        structured_data: dict | None = None,
        scraped_at: datetime | None = None,
    ) -> "DisruptionEvent":
        now = scraped_at or datetime.now(timezone.utc)
        return cls(
            event_id=str(uuid.uuid4()),
            zone_id=zone_id,
            event_type=event_type,
            severity=severity,
            source=source,
            raw_advisory_text=raw_advisory_text,
            structured_data=structured_data or {},
            scraped_at=now,
            ttl_expires_at=now + timedelta(minutes=15),
        )

    # ------------------------------------------------------------------
    # Advisory text round-trip (Property 30 / Requirement 11.7)
    # Format: "{event_type}|{zone_id}|{severity}|{raw_advisory_text}"
    # ------------------------------------------------------------------

    def to_advisory_text(self) -> str:
        return f"{self.event_type}|{self.zone_id}|{self.severity}|{self.raw_advisory_text}"

    @classmethod
    def from_advisory_text(cls, text: str) -> "DisruptionEvent":
        """Parse canonical advisory text back into a DisruptionEvent.

        Raises ValueError if the text does not contain at least 4 pipe-separated fields.
        """
        parts = text.split("|", 3)
        if len(parts) < 4:
            raise ValueError(f"Invalid advisory text (expected 4 pipe-separated fields): {text!r}")
        event_type, zone_id, severity, raw_advisory_text = parts
        return cls.create(
            zone_id=zone_id,
            event_type=event_type,
            severity=severity,
            source="advisory_text",
            raw_advisory_text=raw_advisory_text,
        )

    # ------------------------------------------------------------------
    # JSON serialization
    # ------------------------------------------------------------------

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["scraped_at"] = self.scraped_at.isoformat()
        d["ttl_expires_at"] = self.ttl_expires_at.isoformat()
        return d
