"""
Main handler that orchestrates intent classification → context retrieval → response.

Flow:
  1. Classify intent from the worker's message.
  2. If confidence < ESCALATION_THRESHOLD or intent == escalate_to_human → escalate.
  3. Otherwise fetch context from Core_Backend based on the intent.
  4. Build and return a MessageResponse.
"""
from __future__ import annotations

import logging
from typing import Any

from .core_backend_client import CoreBackendClient
from .indic_conformer import IndicConformerClient
from .intent_classifier import IntentClassifier, should_escalate
from .models import MessageRequest, MessageResponse

logger = logging.getLogger(__name__)

INTENT_FALLBACK_RESPONSE = (
    "I'm sorry, I couldn't understand your query. Please contact human support."
)
ESCALATION_RESPONSE = (
    "Your query has been escalated to a human support agent. "
    "They will contact you shortly."
)

_STATIC_DISRUPTION_CONTEXT: dict[str, Any] = {
    "message": "There may be active disruption events in your zone.",
    "advice": "Check the app for the latest oracle-verified disruption alerts.",
}


class RasaHandler:
    """Orchestrates the full RASA assistant request/response cycle."""

    def __init__(
        self,
        classifier: IntentClassifier,
        core_backend_base_url: str,
        indic_client: IndicConformerClient | None = None,
    ) -> None:
        self._classifier = classifier
        self._core_backend_base_url = core_backend_base_url
        self._indic_client = indic_client

    async def handle(self, request: MessageRequest) -> MessageResponse:
        """
        Process a worker message and return a structured response.

        Escalation rules (in priority order):
          1. intent.name == "escalate_to_human" → always escalate
          2. intent.confidence < ESCALATION_THRESHOLD → escalate
        """
        # --- Language detection and pre-translation ---
        worker_lang = self._resolve_language(request)
        message_for_rasa = request.message
        if self._indic_client is not None and worker_lang != "en":
            message_for_rasa = self._indic_client.translate_to_english(
                request.message, worker_lang
            )
            logger.info(
                "indic_translated_to_english",
                extra={"worker_id": request.worker_id, "source_lang": worker_lang},
            )

        intent = self._classifier.classify(message_for_rasa)
        logger.info(
            "intent_classified",
            extra={
                "worker_id": request.worker_id,
                "intent": intent.name,
                "confidence": intent.confidence,
            },
        )

        # Rule 1: explicit escalation intent (regardless of confidence)
        if intent.name == "escalate_to_human":
            logger.info("escalating_explicit", extra={"worker_id": request.worker_id})
            return MessageResponse(
                reply=ESCALATION_RESPONSE,
                intent=intent.name,
                confidence=intent.confidence,
                escalated=True,
                context={},
            )

        # Rule 2: low-confidence escalation
        if should_escalate(intent):
            logger.info(
                "escalating_low_confidence",
                extra={"worker_id": request.worker_id, "confidence": intent.confidence},
            )
            return MessageResponse(
                reply=ESCALATION_RESPONSE,
                intent=intent.name,
                confidence=intent.confidence,
                escalated=True,
                context={},
            )

        # Fetch context from Core_Backend based on intent
        client = CoreBackendClient(
            base_url=self._core_backend_base_url,
            jwt_token=request.jwt_token,
        )
        context = await self._fetch_context(intent.name, request.worker_id, client)

        reply = self._build_reply(intent.name, context)

        # --- Back-translate reply to worker's language ---
        if self._indic_client is not None and worker_lang != "en":
            reply = self._indic_client.translate_from_english(reply, worker_lang)
            logger.info(
                "indic_back_translated",
                extra={"worker_id": request.worker_id, "target_lang": worker_lang},
            )

        return MessageResponse(
            reply=reply,
            intent=intent.name,
            confidence=intent.confidence,
            escalated=False,
            context=context,
        )

    def _resolve_language(self, request: MessageRequest) -> str:
        """
        Determine the worker's language code.

        Uses request.language if it is a recognised supported language code.
        Falls back to auto-detection via IndicConformerClient when available,
        otherwise defaults to "en".
        """
        if self._indic_client is None:
            return "en"

        lang = request.language.strip().lower() if request.language else ""
        if lang in IndicConformerClient.SUPPORTED_LANGUAGES:
            return lang

        # Auto-detect from message text
        return self._indic_client.detect_language(request.message)

    async def _fetch_context(
        self,
        intent_name: str,
        worker_id: str,
        client: CoreBackendClient,
    ) -> dict[str, Any]:
        """Retrieve context from Core_Backend appropriate for the given intent."""
        if intent_name == "policy_inquiry":
            return await client.get_policy_context(worker_id)
        if intent_name == "claim_status":
            return await client.get_claim_status(worker_id, "latest")
        if intent_name == "payout_inquiry":
            return await client.get_payout_history(worker_id)
        if intent_name == "disruption_alert":
            return dict(_STATIC_DISRUPTION_CONTEXT)
        # Unknown intent — return empty context
        return {}

    def _build_reply(self, intent_name: str, context: dict[str, Any]) -> str:
        """Construct a human-readable reply string from the intent and context."""
        if intent_name == "policy_inquiry":
            if context:
                return f"Here is your policy information: {context}"
            return "I couldn't retrieve your policy details right now. Please try again later."
        if intent_name == "claim_status":
            if context:
                return f"Here is your claim status: {context}"
            return "I couldn't retrieve your claim status right now. Please try again later."
        if intent_name == "payout_inquiry":
            if context:
                return f"Here is your payout history: {context}"
            return "I couldn't retrieve your payout history right now. Please try again later."
        if intent_name == "disruption_alert":
            return context.get("message", "No active disruption alerts at this time.")
        return INTENT_FALLBACK_RESPONSE
