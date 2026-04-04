"""
Pydantic models for Crew AI orchestrator.
"""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class FraudAnalysisReport(BaseModel):
    """Structured output produced by the fraud_signal_aggregation agent."""

    claim_id: str
    worker_id: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    signals: list[dict[str, Any]] = Field(default_factory=list)
    recommendation: str
    generated_at: datetime = Field(default_factory=datetime.utcnow)

    @field_validator("confidence")
    @classmethod
    def validate_confidence_range(cls, v: float) -> float:
        # ge=0.0, le=1.0 already enforced by Field; this is a no-op guard
        return v


class AuditLogEntry(BaseModel):
    """Row written to PostgreSQL agent_audit_log."""

    log_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    claim_id: str
    agent_name: str
    action: str
    payload: dict[str, Any] = Field(default_factory=dict)
    logged_at: datetime = Field(default_factory=datetime.utcnow)
