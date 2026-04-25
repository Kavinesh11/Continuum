"""
fraud_signal_aggregation agent — aggregates signals from KG Cache, Vector Store,
and PostgreSQL claim history to produce a structured FraudAnalysisReport.
"""
from __future__ import annotations

from ..llm_factory import make_gemini_llm
from ..tools.kg_cache_tool import make_kg_cache_tool
from ..tools.postgres_tool import make_postgres_claim_history_tool
from ..tools.vector_store_tool import make_vector_store_tool


def make_fraud_signal_aggregation_agent():
    from crewai import Agent  # noqa: PLC0415
    return Agent(
        role="Fraud Signal Aggregation Specialist",
        goal=(
            "Aggregate fraud signals from the Knowledge Graph Cache, Vector Store, "
            "and PostgreSQL claim history to produce a structured fraud_analysis_report "
            "with a confidence score in [0.0, 1.0] and a clear recommendation."
        ),
        backstory=(
            "You are a fraud detection expert who synthesizes multiple data sources. "
            "You query the Knowledge Graph Cache for zone disruption context, the "
            "Vector Store for relevant policy and event documents, and PostgreSQL for "
            "the worker's claim history. You weigh all signals to produce a confidence "
            "score and recommendation (approve / escalate / reject)."
        ),
        llm=make_gemini_llm(),
        tools=[make_kg_cache_tool(), make_vector_store_tool(), make_postgres_claim_history_tool()],
        verbose=True,
        allow_delegation=False,
    )
