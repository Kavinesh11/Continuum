"""
payout_authorization agent — final authorization gate before human escalation.
"""
from __future__ import annotations

from ..llm_factory import make_gemini_llm


def make_payout_authorization_agent():
    from crewai import Agent  # noqa: PLC0415
    return Agent(
        role="Payout Authorization Officer",
        goal=(
            "Review the fraud analysis report and all prior agent findings to make "
            "a final authorization decision: approve payout, reject claim, or escalate "
            "to a human adjuster."
        ),
        backstory=(
            "You are the final gatekeeper in the claims pipeline. You review the "
            "document verification result, oracle cross-check, and fraud signal "
            "aggregation report. You authorize payouts only when all signals are "
            "consistent and confidence is sufficient. High-confidence fraud signals "
            "are escalated to human adjusters with the full report attached."
        ),
        llm=make_gemini_llm(),
        verbose=True,
        allow_delegation=False,
    )
