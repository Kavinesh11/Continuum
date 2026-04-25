"""
# Feature: continuum-ml-pipelines, Property 33: Crew AI Confidence Escalation

Unit and property-based tests for the Crew AI orchestrator.

Property 33: For any fraud_analysis_report with confidence > 0.85, the
orchestrator must escalate to a human adjuster with the report attached.

Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6
"""
from __future__ import annotations

import asyncio
import json
import uuid
from datetime import datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

# ---------------------------------------------------------------------------
# Import the modules under test
# ---------------------------------------------------------------------------
from services.crew_ai.models import AuditLogEntry, FraudAnalysisReport
from services.crew_ai.crew_ai_orchestrator import _parse_fraud_report


# ---------------------------------------------------------------------------
# Unit tests — FraudAnalysisReport model
# ---------------------------------------------------------------------------

class TestFraudAnalysisReport:
    def test_valid_report(self):
        report = FraudAnalysisReport(
            claim_id=str(uuid.uuid4()),
            worker_id=str(uuid.uuid4()),
            confidence=0.72,
            signals=[{"source": "kg_cache", "value": "flood_confirmed"}],
            recommendation="approve",
        )
        assert 0.0 <= report.confidence <= 1.0
        assert report.recommendation == "approve"
        assert isinstance(report.generated_at, datetime)

    def test_confidence_above_one_rejected(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            FraudAnalysisReport(
                claim_id="c1",
                worker_id="w1",
                confidence=1.5,
                signals=[],
                recommendation="escalate",
            )

    def test_confidence_below_zero_rejected(self):
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            FraudAnalysisReport(
                claim_id="c1",
                worker_id="w1",
                confidence=-0.3,
                signals=[],
                recommendation="reject",
            )

    def test_default_signals_empty_list(self):
        report = FraudAnalysisReport(
            claim_id="c1",
            worker_id="w1",
            confidence=0.5,
            recommendation="escalate",
        )
        assert report.signals == []


class TestAuditLogEntry:
    def test_auto_log_id(self):
        entry = AuditLogEntry(
            claim_id="c1",
            agent_name="fraud_signal_aggregation",
            action="report_produced",
        )
        assert entry.log_id  # non-empty UUID string
        assert entry.payload == {}
        assert isinstance(entry.logged_at, datetime)

    def test_custom_payload(self):
        entry = AuditLogEntry(
            claim_id="c1",
            agent_name="orchestrator",
            action="crew_kickoff_start",
            payload={"agents": ["doc", "oracle"]},
        )
        assert entry.payload["agents"] == ["doc", "oracle"]


# ---------------------------------------------------------------------------
# Unit tests — _parse_fraud_report
# ---------------------------------------------------------------------------

class TestParseFraudReport:
    def test_parses_valid_json_in_output(self):
        claim_id = str(uuid.uuid4())
        worker_id = str(uuid.uuid4())
        data = {
            "claim_id": claim_id,
            "worker_id": worker_id,
            "confidence": 0.91,
            "signals": [{"source": "kg_cache"}],
            "recommendation": "escalate",
        }
        raw_output = f"Analysis complete. {json.dumps(data)}"
        report = _parse_fraud_report(raw_output, claim_id, worker_id)
        assert report.confidence == 0.91
        assert report.recommendation == "escalate"
        assert report.claim_id == claim_id

    def test_fallback_on_no_json(self):
        claim_id = str(uuid.uuid4())
        worker_id = str(uuid.uuid4())
        report = _parse_fraud_report("No JSON here at all.", claim_id, worker_id)
        assert report.claim_id == claim_id
        assert report.worker_id == worker_id
        assert report.recommendation == "escalate"
        assert 0.0 <= report.confidence <= 1.0

    def test_fallback_on_malformed_json(self):
        claim_id = "c1"
        worker_id = "w1"
        report = _parse_fraud_report("{bad json}", claim_id, worker_id)
        assert report.recommendation == "escalate"

    def test_none_output_fallback(self):
        report = _parse_fraud_report(None, "c1", "w1")
        assert report.recommendation == "escalate"


# ---------------------------------------------------------------------------
# Unit tests — process_fraud_queue_claim (mocked crew)
# ---------------------------------------------------------------------------

class TestProcessFraudQueueClaim:
    @pytest.mark.asyncio
    async def test_returns_fraud_analysis_report(self):
        claim_id = str(uuid.uuid4())
        claim_data = {
            "claim_id": claim_id,
            "worker_id": str(uuid.uuid4()),
            "zone_id": "MUM_ANDHERI_W",
            "event_type": "heavy_rainfall",
            "status": "FRAUD_QUEUE",
        }

        mock_report_json = json.dumps({
            "claim_id": claim_id,
            "worker_id": claim_data["worker_id"],
            "confidence": 0.72,
            "signals": [{"source": "kg_cache", "value": "flood_confirmed"}],
            "recommendation": "approve",
        })

        with (
            patch("services.crew_ai.crew_ai_orchestrator.log_agent_action", new=AsyncMock()),
            patch("services.crew_ai.crew_ai_orchestrator._build_crew") as mock_build,
        ):
            mock_crew_output = MagicMock()
            mock_crew_output.raw = mock_report_json
            mock_crew = MagicMock()
            mock_crew.kickoff_async = AsyncMock(return_value=mock_crew_output)
            mock_build.return_value = mock_crew

            from services.crew_ai.crew_ai_orchestrator import process_fraud_queue_claim
            report = await process_fraud_queue_claim(claim_id, claim_data)

        assert isinstance(report, FraudAnalysisReport)
        assert report.claim_id == claim_id
        assert 0.0 <= report.confidence <= 1.0

    @pytest.mark.asyncio
    async def test_escalation_logged_when_confidence_above_threshold(self):
        claim_id = str(uuid.uuid4())
        worker_id = str(uuid.uuid4())
        claim_data = {
            "claim_id": claim_id,
            "worker_id": worker_id,
            "zone_id": "DEL_CONNAUGHT",
            "event_type": "platform_outage",
            "status": "FRAUD_QUEUE",
        }

        high_confidence_json = json.dumps({
            "claim_id": claim_id,
            "worker_id": worker_id,
            "confidence": 0.92,
            "signals": [{"source": "postgres", "value": "velocity_cap_exceeded"}],
            "recommendation": "escalate",
        })

        logged_actions: list[dict] = []

        async def capture_log(claim_id, agent_name, action, payload=None):
            logged_actions.append({"agent_name": agent_name, "action": action})

        with (
            patch("services.crew_ai.crew_ai_orchestrator.log_agent_action", side_effect=capture_log),
            patch("services.crew_ai.crew_ai_orchestrator._build_crew") as mock_build,
        ):
            mock_crew_output = MagicMock()
            mock_crew_output.raw = high_confidence_json
            mock_crew = MagicMock()
            mock_crew.kickoff_async = AsyncMock(return_value=mock_crew_output)
            mock_build.return_value = mock_crew

            from services.crew_ai.crew_ai_orchestrator import process_fraud_queue_claim
            report = await process_fraud_queue_claim(claim_id, claim_data)

        assert report.confidence == 0.92
        escalation_actions = [a for a in logged_actions if a["action"] == "escalated_to_human_adjuster"]
        assert len(escalation_actions) == 1

    @pytest.mark.asyncio
    async def test_no_escalation_when_confidence_at_or_below_threshold(self):
        claim_id = str(uuid.uuid4())
        worker_id = str(uuid.uuid4())
        claim_data = {
            "claim_id": claim_id,
            "worker_id": worker_id,
            "zone_id": "BLR_KORAMANGALA",
            "event_type": "heavy_rainfall",
            "status": "FRAUD_QUEUE",
        }

        low_confidence_json = json.dumps({
            "claim_id": claim_id,
            "worker_id": worker_id,
            "confidence": 0.85,  # exactly at threshold — should NOT escalate (> 0.85 required)
            "signals": [],
            "recommendation": "approve",
        })

        logged_actions: list[dict] = []

        async def capture_log(claim_id, agent_name, action, payload=None):
            logged_actions.append({"agent_name": agent_name, "action": action})

        with (
            patch("services.crew_ai.crew_ai_orchestrator.log_agent_action", side_effect=capture_log),
            patch("services.crew_ai.crew_ai_orchestrator._build_crew") as mock_build,
        ):
            mock_crew_output = MagicMock()
            mock_crew_output.raw = low_confidence_json
            mock_crew = MagicMock()
            mock_crew.kickoff_async = AsyncMock(return_value=mock_crew_output)
            mock_build.return_value = mock_crew

            from services.crew_ai.crew_ai_orchestrator import process_fraud_queue_claim
            report = await process_fraud_queue_claim(claim_id, claim_data)

        assert report.confidence == 0.85
        escalation_actions = [a for a in logged_actions if a["action"] == "escalated_to_human_adjuster"]
        assert len(escalation_actions) == 0


# ---------------------------------------------------------------------------
# Property 33: Crew AI Confidence Escalation
# Feature: continuum-ml-pipelines, Property 33: Crew AI Confidence Escalation
# Validates: Requirements 12.4
# ---------------------------------------------------------------------------

@settings(max_examples=100)
@given(confidence=st.floats(min_value=0.0, max_value=1.0, allow_nan=False))
def test_property_33_confidence_escalation(confidence: float):
    """
    Property 33: For any fraud_analysis_report with confidence > 0.85,
    the orchestrator must escalate to a human adjuster.
    For confidence <= 0.85, no escalation should occur.

    Validates: Requirements 12.4
    """
    claim_id = str(uuid.uuid4())
    worker_id = str(uuid.uuid4())

    report_json = json.dumps({
        "claim_id": claim_id,
        "worker_id": worker_id,
        "confidence": confidence,
        "signals": [],
        "recommendation": "escalate" if confidence > 0.85 else "approve",
    })

    logged_actions: list[str] = []

    async def capture_log(claim_id, agent_name, action, payload=None):
        logged_actions.append(action)

    async def run():
        with (
            patch("services.crew_ai.crew_ai_orchestrator.log_agent_action", side_effect=capture_log),
            patch("services.crew_ai.crew_ai_orchestrator._build_crew") as mock_build,
        ):
            mock_crew_output = MagicMock()
            mock_crew_output.raw = report_json
            mock_crew = MagicMock()
            mock_crew.kickoff_async = AsyncMock(return_value=mock_crew_output)
            mock_build.return_value = mock_crew

            from services.crew_ai.crew_ai_orchestrator import process_fraud_queue_claim
            return await process_fraud_queue_claim(claim_id, {"worker_id": worker_id})

    report = asyncio.run(run())

    escalated = "escalated_to_human_adjuster" in logged_actions

    if confidence > 0.85:
        assert escalated, (
            f"Expected escalation for confidence={confidence} > 0.85, but none occurred"
        )
    else:
        assert not escalated, (
            f"Unexpected escalation for confidence={confidence} <= 0.85"
        )
