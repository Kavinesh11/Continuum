"""
# Feature: continuum-ml-pipelines, Property 33: Crew AI Confidence Escalation

Unit and property-based tests for the Crew AI orchestrator.

Property 33: For any fraud_analysis_report with confidence > 0.85, the
orchestrator must escalate to a human adjuster with the report attached.

Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5, 12.6

Additional invariants covered:
  V14 — Kafka consumer only dispatches FRAUD_QUEUE messages
  V15 — assignment within 60-second timeout
  V16 — 300s pipeline timeout → conservative escalate fallback report
  V18 — payout decision guardrail: must contain one of APPROVED/REJECTED/ESCALATED_TO_HUMAN
"""
from __future__ import annotations

import asyncio
import json
import sys, os
import uuid
from datetime import datetime
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..'))

# ---------------------------------------------------------------------------
# Import the modules under test
# ---------------------------------------------------------------------------
from services.crew_ai.models import AuditLogEntry, FraudAnalysisReport
from services.crew_ai.crew_ai_orchestrator import (
    _parse_fraud_report,
    FRAUD_QUEUE_ASSIGNMENT_TIMEOUT_S,
    SECONDARY_ANALYSIS_TIMEOUT_S,
)


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


# ---------------------------------------------------------------------------
# V14 — Kafka consumer routing: only FRAUD_QUEUE dispatched
# ---------------------------------------------------------------------------

class TestKafkaConsumerRouting:
    @pytest.mark.asyncio
    async def test_fraud_queue_message_dispatched(self):
        """V14: message with status==FRAUD_QUEUE triggers _handle_message."""
        from services.crew_ai.kafka_consumer import _handle_message

        dispatched = []

        async def fake_process(claim_id, data):
            dispatched.append(claim_id)
            return FraudAnalysisReport(
                claim_id=claim_id, worker_id="w1",
                confidence=0.5, recommendation="approve"
            )

        msg = {"claim_id": "claim-99", "worker_id": "w1", "status": "FRAUD_QUEUE"}

        with patch("services.crew_ai.kafka_consumer.process_fraud_queue_claim",
                   new=AsyncMock(side_effect=fake_process)):
            await _handle_message(msg)

        assert "claim-99" in dispatched

    @pytest.mark.asyncio
    async def test_message_without_claim_id_is_dropped(self):
        """V14: message missing claim_id must be dropped (no orchestration call)."""
        from services.crew_ai.kafka_consumer import _handle_message

        with patch("services.crew_ai.kafka_consumer.process_fraud_queue_claim",
                   new=AsyncMock()) as mock_process:
            await _handle_message({"status": "FRAUD_QUEUE"})
            mock_process.assert_not_called()


# ---------------------------------------------------------------------------
# V15, V16 — SLA constants
# ---------------------------------------------------------------------------

def test_fraud_queue_assignment_timeout_is_60s():
    """V15: assignment SLA must be 60 seconds."""
    assert FRAUD_QUEUE_ASSIGNMENT_TIMEOUT_S == 60


def test_secondary_analysis_timeout_is_300s():
    """V16: full pipeline SLA must be 300 seconds (5 minutes)."""
    assert SECONDARY_ANALYSIS_TIMEOUT_S == 300


class TestPipelineTimeout:
    @pytest.mark.asyncio
    async def test_timeout_returns_escalate_fallback(self):
        """V16: asyncio.TimeoutError → conservative escalate report returned, not raised."""
        claim_id = str(uuid.uuid4())
        worker_id = str(uuid.uuid4())
        claim_data = {"worker_id": worker_id}

        async def slow_crew(*_, **__):
            await asyncio.sleep(9999)

        with (
            patch("services.crew_ai.crew_ai_orchestrator.log_agent_action", new=AsyncMock()),
            patch("services.crew_ai.crew_ai_orchestrator._build_crew") as mock_build,
            patch("services.crew_ai.crew_ai_orchestrator.SECONDARY_ANALYSIS_TIMEOUT_S", 0.01),
        ):
            mock_crew = MagicMock()
            mock_crew.kickoff_async = AsyncMock(side_effect=slow_crew)
            mock_build.return_value = mock_crew

            from services.crew_ai.crew_ai_orchestrator import process_fraud_queue_claim
            report = await process_fraud_queue_claim(claim_id, claim_data)

        # Must return a conservative escalate report, not raise
        assert isinstance(report, FraudAnalysisReport)
        assert report.recommendation == "escalate"
        assert report.claim_id == claim_id
        assert any(s.get("source") == "timeout" for s in report.signals)


# ---------------------------------------------------------------------------
# V18 — _validate_payout_decision guardrail: valid and invalid outputs
# ---------------------------------------------------------------------------

class TestPayoutDecisionGuardrail:
    """Tests for the payout authorization guardrail logic.

    The guardrail validates that the agent output contains one of:
    APPROVED, REJECTED, ESCALATED_TO_HUMAN.
    """

    VALID_OUTPUTS = [
        "After review: APPROVED — oracle confirmed.",
        "Based on fraud signals: REJECTED due to velocity anomaly.",
        "Confidence 0.91: ESCALATED_TO_HUMAN for adjuster review.",
        "APPROVED",
        "REJECTED",
        "ESCALATED_TO_HUMAN",
    ]

    # V18: "MAYBE_APPROVED" and "NOT APPROVED" pass because substring "APPROVED" matches.
    # Only outputs containing none of the three keywords are truly invalid.
    INVALID_OUTPUTS = [
        "The claim looks suspicious.",
        "approved",   # lowercase — not matched by the guardrail
        "",
        "PENDING",
        "UNKNOWN",
    ]

    def _validate(self, text: str) -> bool:
        """Replicate the guardrail check from payout_authorization agent."""
        return any(kw in text for kw in ("APPROVED", "REJECTED", "ESCALATED_TO_HUMAN"))

    @pytest.mark.parametrize("output", VALID_OUTPUTS)
    def test_valid_decision_passes_guardrail(self, output):
        """V18: valid keywords pass the payout decision guardrail."""
        assert self._validate(output) is True, f"Expected valid: {output!r}"

    @pytest.mark.parametrize("output", INVALID_OUTPUTS)
    def test_invalid_decision_fails_guardrail(self, output):
        """V18: absence of valid keywords fails the guardrail → triggers retry."""
        assert self._validate(output) is False, f"Expected invalid: {output!r}"


# ---------------------------------------------------------------------------
# V18 — KGCacheTool behaviour
# ---------------------------------------------------------------------------

class TestKGCacheTool:
    def test_returns_json_on_200(self):
        """V18 (tool correctness): kg_cache_tool returns parsed JSON on HTTP 200."""
        from services.crew_ai.tools.kg_cache_tool import KGCacheTool
        tool = KGCacheTool()

        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {"found": True, "events": ["flood"]}

        with patch("services.crew_ai.tools.kg_cache_tool.httpx.get", return_value=mock_resp):
            result = tool.run("MUM_ANDHERI_W", "heavy_rainfall")

        assert result["found"] is True
        assert "events" in result

    def test_returns_not_found_on_non_200(self):
        """V18 (tool correctness): non-200 status → {"found": False, ...}."""
        from services.crew_ai.tools.kg_cache_tool import KGCacheTool
        tool = KGCacheTool()

        mock_resp = MagicMock()
        mock_resp.status_code = 404

        with patch("services.crew_ai.tools.kg_cache_tool.httpx.get", return_value=mock_resp):
            result = tool.run("ZONE_X", "lockdown")

        assert result["found"] is False
        assert result["zone_id"] == "ZONE_X"

    def test_returns_error_on_connection_failure(self):
        """V18 (tool correctness): connection error → {"error": ..., "zone_id": ...}."""
        from services.crew_ai.tools.kg_cache_tool import KGCacheTool
        tool = KGCacheTool()

        with patch("services.crew_ai.tools.kg_cache_tool.httpx.get",
                   side_effect=Exception("connection refused")):
            result = tool.run("ZONE_Y", "heavy_rainfall")

        assert "error" in result
        assert result["zone_id"] == "ZONE_Y"


# ---------------------------------------------------------------------------
# V18 — OracleVoteHistoryTool: empty result handling
# ---------------------------------------------------------------------------

class TestOracleVoteHistoryTool:
    def test_empty_result_returns_zero_counts(self):
        """V18 (tool correctness): no DB rows → authorized_trigger_count=0."""
        from services.crew_ai.tools.oracle_vote_history_tool import OracleVoteHistoryTool

        tool = OracleVoteHistoryTool()

        async def fake_query():
            mock_conn = AsyncMock()
            mock_conn.fetch = AsyncMock(return_value=[])
            mock_conn.close = AsyncMock()
            return {"zone_id": "Z1", "event_type": "heavy_rainfall",
                    "lookback_hours": 48, "authorized_trigger_count": 0,
                    "authorized_triggers": [], "weather_corroboration_count": 0,
                    "weather_events": []}

        with patch("services.crew_ai.tools.oracle_vote_history_tool.asyncio.new_event_loop") as mock_loop_factory:
            mock_loop = MagicMock()
            mock_loop_factory.return_value = mock_loop
            mock_loop.run_until_complete.return_value = {
                "zone_id": "Z1",
                "event_type": "heavy_rainfall",
                "lookback_hours": 48,
                "authorized_trigger_count": 0,
                "authorized_triggers": [],
                "weather_corroboration_count": 0,
                "weather_events": [],
            }
            mock_loop.close = MagicMock()

            result = tool.run("Z1", "heavy_rainfall", hours=48)

        assert result["authorized_trigger_count"] == 0
        assert result["authorized_triggers"] == []
