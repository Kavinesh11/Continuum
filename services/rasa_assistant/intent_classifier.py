"""
Intent classification logic for the RASA Assistant.

When a real RASA NLU model path is provided via rasa_model_path, the model is
loaded and used for inference.  When no path is given (testing / stub mode) a
fixed stub response is returned so the rest of the pipeline can be exercised
without a trained model.
"""
from __future__ import annotations

import json
import logging
import os

from .models import Intent

logger = logging.getLogger(__name__)

SUPPORTED_INTENTS: list[str] = [
    "policy_inquiry",
    "claim_status",
    "payout_inquiry",
    "disruption_alert",
    "escalate_to_human",
]

ESCALATION_THRESHOLD: float = 0.7


class IntentClassifier:
    """Classifies worker messages into one of the supported intents."""

    def __init__(self, rasa_model_path: str | None = None) -> None:
        self._model = None
        if rasa_model_path:
            try:
                # Lazy import so the service starts even without rasa installed
                from rasa.core.agent import Agent  # type: ignore[import]

                self._model = Agent.load(rasa_model_path)
                logger.info("rasa_model_loaded", extra={"path": rasa_model_path})
            except Exception as exc:
                logger.warning(
                    "rasa_model_load_failed",
                    extra={"path": rasa_model_path, "error": str(exc)},
                )
                self._model = None
        else:
            self._gemini_api_key = os.environ.get("GEMINI_API_KEY")
            if self._gemini_api_key:
                logger.info("gemini_api_mode_enabled")
                import google.generativeai as genai
                genai.configure(api_key=self._gemini_api_key)
                # Use gemini-1.5-flash for fast intent classification
                self._gemini_model = genai.GenerativeModel("gemini-1.5-flash")
            else:
                logger.info("rasa_classifier_stub_mode")

    def classify(self, message: str) -> Intent:
        """
        Return an Intent for the given message.

        Uses the loaded RASA NLU model when available; falls back to a stub
        that always returns policy_inquiry with confidence 0.5 for testing.
        """
        if self._model is not None:
            try:
                result = self._model.parse_message_using_nlu_interpreter(message)
                intent_data = result.get("intent", {})
                name = intent_data.get("name", "policy_inquiry")
                confidence = float(intent_data.get("confidence", 0.0))
                # Clamp to supported intents
                if name not in SUPPORTED_INTENTS:
                    logger.warning("unknown_intent", extra={"intent": name})
                    name = "policy_inquiry"
                return Intent(name=name, confidence=max(0.0, min(1.0, confidence)))
            except Exception as exc:
                logger.error("rasa_classify_error", extra={"error": str(exc)})
                return Intent(name="policy_inquiry", confidence=0.5)

        if hasattr(self, "_gemini_model") and self._gemini_api_key:
            try:
                prompt = f"""
Classify the following message from a gig worker into exactly ONE of these intents: 
{", ".join(SUPPORTED_INTENTS)}

Message: "{message}"

Respond ONLY with a valid JSON strictly following this schema:
{{"intent": "<intent_name>", "confidence": <float_between_0_and_1>}}
"""
                response = self._gemini_model.generate_content(
                    prompt,
                    generation_config={"response_mime_type": "application/json"}
                )
                data = json.loads(response.text)
                name = data.get("intent", "policy_inquiry")
                confidence = float(data.get("confidence", 0.0))
                if name not in SUPPORTED_INTENTS:
                    name = "policy_inquiry"
                return Intent(name=name, confidence=max(0.0, min(1.0, confidence)))
            except Exception as exc:
                logger.error("gemini_classify_error", extra={"error": str(exc)})
                return Intent(name="policy_inquiry", confidence=0.5)

        # Stub implementation for testing
        return Intent(name="policy_inquiry", confidence=0.5)

def should_escalate(intent: Intent) -> bool:
    """Return True if the intent confidence is below the escalation threshold."""
    return intent.confidence < ESCALATION_THRESHOLD
