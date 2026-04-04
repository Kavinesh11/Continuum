"""
Pydantic models for the RASA Assistant service.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


@dataclass
class Intent:
    """Classified intent with confidence score."""

    name: str
    confidence: float  # validated 0.0–1.0 by IntentClassifier

    def __post_init__(self) -> None:
        if not (0.0 <= self.confidence <= 1.0):
            raise ValueError(f"confidence must be in [0.0, 1.0], got {self.confidence}")


class MessageRequest(BaseModel):
    """Incoming message from a worker."""

    worker_id: str
    message: str
    language: str = "en"
    jwt_token: str


class MessageResponse(BaseModel):
    """Response returned to the worker after intent handling."""

    reply: str
    intent: str
    confidence: float
    escalated: bool
    context: dict[str, Any] = Field(default_factory=dict)


class EscalationEvent(BaseModel):
    """Event recorded when a conversation is escalated to a human agent."""

    worker_id: str
    intent: str
    confidence: float
    original_message: str
    escalated_at: datetime = Field(default_factory=datetime.utcnow)
