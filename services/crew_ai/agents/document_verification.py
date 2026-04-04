"""
document_verification agent — validates claim documents against policy terms.
"""
from __future__ import annotations


def make_document_verification_agent():
    from crewai import Agent  # noqa: PLC0415
    return Agent(
        role="Document Verification Specialist",
        goal=(
            "Validate that all claim documents are authentic, complete, and "
            "consistent with the worker's active policy terms."
        ),
        backstory=(
            "You are an expert in insurance document review. You check that "
            "submitted claim documents match the policy tier, coverage period, "
            "and event type. You flag any discrepancies for further review."
        ),
        verbose=True,
        allow_delegation=False,
    )
