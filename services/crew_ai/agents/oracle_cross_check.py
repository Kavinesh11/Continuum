"""
oracle_cross_check agent — verifies claim event against oracle vote history.
"""
from __future__ import annotations

from ..llm_factory import make_gemini_llm
from ..tools.oracle_vote_history_tool import make_oracle_vote_history_tool


def make_oracle_cross_check_agent():
    from crewai import Agent  # noqa: PLC0415
    return Agent(
        role="Oracle Cross-Check Analyst",
        goal=(
            "Verify that the claimed disruption event is corroborated by the "
            "oracle consensus vote history for the worker's zone and event type."
        ),
        backstory=(
            "You are a data integrity specialist who cross-references claim "
            "events against the multi-oracle consensus records. You confirm "
            "whether a parametric trigger was authorized for the claimed zone "
            "and time window, and flag claims that lack oracle support. "
            "Absence of any authorized trigger in the lookback window is a "
            "strong fraud signal and must be reported as NOT_CONFIRMED."
        ),
        llm=make_gemini_llm(),
        tools=[make_oracle_vote_history_tool()],
        max_iter=15,
        max_execution_time=90,
        verbose=True,
        allow_delegation=False,
    )
