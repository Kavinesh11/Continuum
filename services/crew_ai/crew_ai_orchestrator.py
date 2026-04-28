"""
Crew AI Multi-Agent Orchestrator for Continuum claim validation.

Exposes:
  process_fraud_queue_claim(claim_id, claim_data) -> FraudAnalysisReport

Kafka consumer listens on `claim_decision` topic for status == "FRAUD_QUEUE"
and triggers orchestration within 60 seconds. Full pipeline has a 300-second
(5-minute) SLA enforced via asyncio.wait_for.
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
from datetime import datetime
from typing import Any

from .agents.document_verification import make_document_verification_agent
from .agents.fraud_signal_aggregation import make_fraud_signal_aggregation_agent
from .agents.oracle_cross_check import make_oracle_cross_check_agent
from .agents.payout_authorization import make_payout_authorization_agent
from .audit_logger import log_agent_action
from .models import FraudAnalysisReport

logger = logging.getLogger(__name__)

# SLA constants
FRAUD_QUEUE_ASSIGNMENT_TIMEOUT_S = 60   # assign within 60 seconds
SECONDARY_ANALYSIS_TIMEOUT_S = 300      # complete within 5 minutes


def _build_crew(claim_id: str, claim_data: dict[str, Any]):
    """Construct the four-agent crew and task graph for a single claim."""
    from crewai import Crew, Task  # noqa: PLC0415

    doc_agent = make_document_verification_agent()
    oracle_agent = make_oracle_cross_check_agent()
    fraud_agent = make_fraud_signal_aggregation_agent()
    auth_agent = make_payout_authorization_agent()

    worker_id = claim_data.get("worker_id", "unknown")
    zone_id = claim_data.get("zone_id", "unknown")
    event_type = claim_data.get("event_type", "unknown")

    task_doc = Task(
        description=(
            f"Verify claim documents for claim_id={claim_id}, worker_id={worker_id}. "
            f"Check that the claim event_type='{event_type}' is consistent with the "
            f"worker's active policy terms and that all required fields are present."
        ),
        expected_output=(
            "A brief document verification summary: PASS or FAIL with reasons."
        ),
        agent=doc_agent,
    )

    task_oracle = Task(
        description=(
            f"Cross-check claim_id={claim_id} against oracle vote history. "
            f"Confirm whether a parametric trigger was authorized for "
            f"zone_id='{zone_id}' and event_type='{event_type}' at the claimed time."
        ),
        expected_output=(
            "Oracle cross-check result: CONFIRMED or NOT_CONFIRMED with vote summary."
        ),
        agent=oracle_agent,
        context=[task_doc],
    )

    task_fraud = Task(
        description=(
            f"Aggregate fraud signals for claim_id={claim_id}, worker_id={worker_id}. "
            f"Query the Knowledge Graph Cache for zone_id='{zone_id}' event_type='{event_type}', "
            f"search the Vector Store for relevant policy context, and retrieve the worker's "
            f"PostgreSQL claim history. Produce a structured fraud_analysis_report with "
            f"confidence (float in [0,1]) and recommendation (approve/escalate/reject)."
        ),
        expected_output=(
            "JSON fraud_analysis_report with fields: claim_id, worker_id, confidence, "
            "signals (list), recommendation, generated_at."
        ),
        agent=fraud_agent,
        context=[task_doc, task_oracle],
    )

    task_auth = Task(
        description=(
            f"Review all findings for claim_id={claim_id} and make the final "
            f"authorization decision. If confidence > 0.85, escalate to human adjuster "
            f"with the full fraud_analysis_report attached."
        ),
        expected_output=(
            "Final decision: APPROVED, REJECTED, or ESCALATED_TO_HUMAN with justification."
        ),
        agent=auth_agent,
        context=[task_doc, task_oracle, task_fraud],
    )

    return Crew(
        agents=[doc_agent, oracle_agent, fraud_agent, auth_agent],
        tasks=[task_doc, task_oracle, task_fraud, task_auth],
        verbose=True,
    )


def _parse_fraud_report(
    crew_output: Any,
    claim_id: str,
    worker_id: str,
) -> FraudAnalysisReport:
    """
    Extract a FraudAnalysisReport from the crew's raw output string.
    Falls back to a conservative report if parsing fails.
    """
    raw = (getattr(crew_output, "raw", None) or str(crew_output)) if crew_output else ""

    # Attempt JSON extraction from the output
    try:
        # Look for a JSON block in the output
        start = raw.find("{")
        end = raw.rfind("}") + 1
        if start >= 0 and end > start:
            data = json.loads(raw[start:end])
            return FraudAnalysisReport(
                claim_id=data.get("claim_id", claim_id),
                worker_id=data.get("worker_id", worker_id),
                confidence=float(data.get("confidence", 0.5)),
                signals=data.get("signals", []),
                recommendation=data.get("recommendation", "escalate"),
                generated_at=datetime.utcnow(),
            )
    except (json.JSONDecodeError, ValueError, KeyError):
        pass

    # Conservative fallback: escalate for human review
    return FraudAnalysisReport(
        claim_id=claim_id,
        worker_id=worker_id,
        confidence=0.5,
        signals=[{"source": "crew_output", "raw": raw[:500]}],
        recommendation="escalate",
        generated_at=datetime.utcnow(),
    )


async def process_fraud_queue_claim(
    claim_id: str,
    claim_data: dict[str, Any],
) -> FraudAnalysisReport:
    """
    Run the full four-agent pipeline for a FRAUD_QUEUE claim.

    Enforces a 300-second (5-minute) SLA via asyncio.wait_for.
    Logs all agent actions to PostgreSQL agent_audit_log.
    """
    worker_id = claim_data.get("worker_id", "unknown")

    await log_agent_action(
        claim_id=claim_id,
        agent_name="orchestrator",
        action="fraud_queue_assigned",
        payload={"claim_data": claim_data},
    )

    async def _run_crew() -> FraudAnalysisReport:
        crew = _build_crew(claim_id, claim_data)

        await log_agent_action(
            claim_id=claim_id,
            agent_name="orchestrator",
            action="crew_kickoff_start",
            payload={"agents": ["document_verification", "oracle_cross_check",
                                 "fraud_signal_aggregation", "payout_authorization"]},
        )

        result = await crew.kickoff_async()

        await log_agent_action(
            claim_id=claim_id,
            agent_name="orchestrator",
            action="crew_kickoff_complete",
            payload={"raw_output": str(result)[:1000]},
        )

        report = _parse_fraud_report(result, claim_id, worker_id)

        await log_agent_action(
            claim_id=claim_id,
            agent_name="fraud_signal_aggregation",
            action="fraud_analysis_report_produced",
            payload={
                "confidence": report.confidence,
                "recommendation": report.recommendation,
                "signal_count": len(report.signals),
            },
        )

        # Confidence-based escalation (Requirement 12.4)
        if report.confidence > 0.85:
            await log_agent_action(
                claim_id=claim_id,
                agent_name="payout_authorization",
                action="escalated_to_human_adjuster",
                payload={
                    "confidence": report.confidence,
                    "report": report.model_dump(mode="json"),
                },
            )
            logger.info(
                "claim_id=%s escalated to human adjuster confidence=%.3f",
                claim_id,
                report.confidence,
            )

        return report

    try:
        report = await asyncio.wait_for(
            _run_crew(),
            timeout=SECONDARY_ANALYSIS_TIMEOUT_S,
        )
    except asyncio.TimeoutError:
        logger.error(
            "claim_id=%s secondary analysis timed out after %ds",
            claim_id,
            SECONDARY_ANALYSIS_TIMEOUT_S,
        )
        await log_agent_action(
            claim_id=claim_id,
            agent_name="orchestrator",
            action="secondary_analysis_timeout",
            payload={"timeout_seconds": SECONDARY_ANALYSIS_TIMEOUT_S},
        )
        # Return conservative escalation report on timeout
        report = FraudAnalysisReport(
            claim_id=claim_id,
            worker_id=worker_id,
            confidence=0.5,
            signals=[{"source": "timeout", "timeout_seconds": SECONDARY_ANALYSIS_TIMEOUT_S}],
            recommendation="escalate",
            generated_at=datetime.utcnow(),
        )

    return report
