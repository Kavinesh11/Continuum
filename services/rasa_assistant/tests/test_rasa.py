# Feature: continuum-ml-pipelines, Property 34: RASA Low-Confidence Escalation
"""
Unit and property-based tests for the RASA Assistant service.

Property 34: For any intent with confidence < 0.7, the RASA handler MUST
escalate to a human support agent (response.escalated == True).
For confidence >= 0.7 (and intent != escalate_to_human), the handler MUST NOT
escalate (response.escalated == False).

Validates: Requirements 13.4
"""
from __future__ import annotations

import asyncio
import sys
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from services.rasa_assistant.models import Intent, MessageRequest, MessageResponse
from services.rasa_assistant.intent_classifier import (
    IntentClassifier,
    should_escalate,
    ESCALATION_THRESHOLD,
)
from services.rasa_assistant.rasa_handler import RasaHandler, ESCALATION_RESPONSE
from services.rasa_assistant.indic_conformer import IndicConformerClient


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_request(worker_id: str = "worker-1") -> MessageRequest:
    return MessageRequest(
        worker_id=worker_id,
        message="What is my policy status?",
        language="en",
        jwt_token="test-token",
    )


class _StubClassifier:
    """Returns a fixed Intent with the given confidence and intent name."""

    def __init__(self, confidence: float, intent_name: str = "policy_inquiry") -> None:
        self._confidence = confidence
        self._intent_name = intent_name

    def classify(self, message: str) -> Intent:  # noqa: ARG002
        return Intent(name=self._intent_name, confidence=self._confidence)


# ---------------------------------------------------------------------------
# Unit tests — Intent model
# ---------------------------------------------------------------------------

class TestIntentModel:
    def test_intent_valid_confidence_range(self):
        for confidence in (0.0, 0.5, 1.0):
            intent = Intent(name="policy_inquiry", confidence=confidence)
            assert intent.confidence == confidence

    def test_intent_invalid_confidence_raises(self):
        for bad in (-0.1, 1.1, 2.0, -1.0):
            with pytest.raises(ValueError):
                Intent(name="policy_inquiry", confidence=bad)


# ---------------------------------------------------------------------------
# Unit tests — should_escalate
# ---------------------------------------------------------------------------

class TestShouldEscalate:
    def test_should_escalate_below_threshold(self):
        intent = Intent(name="policy_inquiry", confidence=0.5)
        assert should_escalate(intent) is True

    def test_should_escalate_at_threshold(self):
        # confidence == 0.7 is NOT strictly less than threshold → no escalation
        intent = Intent(name="policy_inquiry", confidence=0.7)
        assert should_escalate(intent) is False

    def test_should_escalate_above_threshold(self):
        intent = Intent(name="policy_inquiry", confidence=0.9)
        assert should_escalate(intent) is False

    def test_escalate_to_human_intent_always_escalates(self):
        """escalate_to_human intent escalates even with confidence=1.0 (via RasaHandler)."""
        classifier = _StubClassifier(confidence=1.0, intent_name="escalate_to_human")
        indic = IndicConformerClient(use_stub=True)
        handler = RasaHandler(
            classifier=classifier,
            core_backend_base_url="http://localhost:3000",
            indic_client=indic,
        )
        request = _make_request()
        with patch(
            "services.rasa_assistant.rasa_handler.CoreBackendClient",
            autospec=True,
        ) as MockClient:
            mock_instance = MockClient.return_value
            mock_instance.get_policy_context = AsyncMock(return_value={})
            mock_instance.get_claim_status = AsyncMock(return_value={})
            mock_instance.get_payout_history = AsyncMock(return_value={})
            response = asyncio.run(handler.handle(request))
        assert response.escalated is True


# ---------------------------------------------------------------------------
# Unit tests — RasaHandler.handle()
# ---------------------------------------------------------------------------

class TestRasaHandler:
    def _make_handler(self, confidence: float, intent_name: str = "policy_inquiry") -> RasaHandler:
        classifier = _StubClassifier(confidence=confidence, intent_name=intent_name)
        indic = IndicConformerClient(use_stub=True)
        return RasaHandler(
            classifier=classifier,
            core_backend_base_url="http://localhost:3000",
            indic_client=indic,
        )

    @pytest.mark.asyncio
    async def test_low_confidence_returns_escalated_response(self):
        handler = self._make_handler(confidence=0.3)
        request = _make_request()
        with patch(
            "services.rasa_assistant.rasa_handler.CoreBackendClient",
            autospec=True,
        ) as MockClient:
            mock_instance = MockClient.return_value
            mock_instance.get_policy_context = AsyncMock(return_value={})
            response = await handler.handle(request)
        assert response.escalated is True
        assert response.reply == ESCALATION_RESPONSE

    @pytest.mark.asyncio
    async def test_high_confidence_returns_non_escalated_response(self):
        handler = self._make_handler(confidence=0.9, intent_name="policy_inquiry")
        request = _make_request()
        with patch(
            "services.rasa_assistant.rasa_handler.CoreBackendClient",
            autospec=True,
        ) as MockClient:
            mock_instance = MockClient.return_value
            mock_instance.get_policy_context = AsyncMock(return_value={"tier": "gold"})
            mock_instance.get_claim_status = AsyncMock(return_value={})
            mock_instance.get_payout_history = AsyncMock(return_value={})
            response = await handler.handle(request)
        assert response.escalated is False

    @pytest.mark.asyncio
    async def test_explicit_escalate_to_human_intent_escalates(self):
        handler = self._make_handler(confidence=1.0, intent_name="escalate_to_human")
        request = _make_request()
        with patch(
            "services.rasa_assistant.rasa_handler.CoreBackendClient",
            autospec=True,
        ) as MockClient:
            mock_instance = MockClient.return_value
            mock_instance.get_policy_context = AsyncMock(return_value={})
            response = await handler.handle(request)
        assert response.escalated is True


# ---------------------------------------------------------------------------
# Property 34: RASA Low-Confidence Escalation
# Feature: continuum-ml-pipelines, Property 34: RASA Low-Confidence Escalation
# Validates: Requirements 13.4
# ---------------------------------------------------------------------------

@settings(max_examples=100)
@given(confidence=st.floats(min_value=0.0, max_value=1.0, allow_nan=False))
def test_property_34_rasa_low_confidence_escalation(confidence: float):
    """
    Property 34: RASA Low-Confidence Escalation

    For any intent with confidence < 0.7, the RASA handler MUST escalate
    to a human support agent (response.escalated == True).
    For confidence >= 0.7 (and intent != escalate_to_human), the handler
    MUST NOT escalate (response.escalated == False).

    Validates: Requirements 13.4
    """
    classifier = _StubClassifier(confidence=confidence, intent_name="policy_inquiry")
    indic = IndicConformerClient(use_stub=True)
    handler = RasaHandler(
        classifier=classifier,
        core_backend_base_url="http://localhost:3000",
        indic_client=indic,
    )
    request = _make_request()

    async def run() -> MessageResponse:
        with patch(
            "services.rasa_assistant.rasa_handler.CoreBackendClient",
            autospec=True,
        ) as MockClient:
            mock_instance = MockClient.return_value
            mock_instance.get_policy_context = AsyncMock(return_value={})
            mock_instance.get_claim_status = AsyncMock(return_value={})
            mock_instance.get_payout_history = AsyncMock(return_value={})
            return await handler.handle(request)

    response = asyncio.run(run())

    if confidence < ESCALATION_THRESHOLD:
        assert response.escalated is True, (
            f"Expected escalation for confidence={confidence} < {ESCALATION_THRESHOLD}, "
            f"but response.escalated={response.escalated}"
        )
    else:
        assert response.escalated is False, (
            f"Unexpected escalation for confidence={confidence} >= {ESCALATION_THRESHOLD}, "
            f"but response.escalated={response.escalated}"
        )


# ---------------------------------------------------------------------------
# V53-V55 — Explicit boundary tests for escalation threshold
# ---------------------------------------------------------------------------

class TestEscalationThresholdBoundary:
    """Explicit boundary tests per V53, V54, V55."""

    def _make_handler(self, confidence: float, intent_name: str = "policy_inquiry") -> RasaHandler:
        classifier = _StubClassifier(confidence=confidence, intent_name=intent_name)
        indic = IndicConformerClient(use_stub=True)
        return RasaHandler(
            classifier=classifier,
            core_backend_base_url="http://localhost:3000",
            indic_client=indic,
        )

    def test_v54_confidence_epsilon_below_threshold_escalates(self):
        """V54: confidence one float epsilon below ESCALATION_THRESHOLD → escalated=True."""
        epsilon_below = ESCALATION_THRESHOLD - sys.float_info.epsilon * 100
        # Only test if epsilon_below is strictly less than threshold
        if epsilon_below < ESCALATION_THRESHOLD:
            intent = Intent(name="policy_inquiry", confidence=epsilon_below)
            assert should_escalate(intent) is True

    def test_v55_confidence_exactly_at_threshold_not_escalated(self):
        """V55: confidence == ESCALATION_THRESHOLD on non-escalate intent → escalated=False."""
        intent = Intent(name="claim_status", confidence=ESCALATION_THRESHOLD)
        assert should_escalate(intent) is False

    def test_v53_escalate_intent_at_zero_confidence_escalates(self):
        """V53: escalate_to_human intent even at confidence=0.0 → escalated=True."""
        handler = self._make_handler(confidence=0.0, intent_name="escalate_to_human")
        request = _make_request()

        async def run():
            with patch("services.rasa_assistant.rasa_handler.CoreBackendClient", autospec=True) as MockClient:
                MockClient.return_value.get_policy_context = AsyncMock(return_value={})
                return await handler.handle(request)

        response = asyncio.run(run())
        assert response.escalated is True

    def test_v53_escalate_intent_at_max_confidence_escalates(self):
        """V53: escalate_to_human intent at confidence=1.0 → escalated=True (regardless of high confidence)."""
        handler = self._make_handler(confidence=1.0, intent_name="escalate_to_human")
        request = _make_request()

        async def run():
            with patch("services.rasa_assistant.rasa_handler.CoreBackendClient", autospec=True) as MockClient:
                MockClient.return_value.get_policy_context = AsyncMock(return_value={})
                return await handler.handle(request)

        response = asyncio.run(run())
        assert response.escalated is True

    @pytest.mark.parametrize("confidence", [0.0, 0.1, 0.3, 0.5, 0.69])
    def test_v54_various_low_confidence_values_escalate(self, confidence: float):
        """V54: various confidence values strictly below threshold all escalate."""
        intent = Intent(name="policy_inquiry", confidence=confidence)
        assert should_escalate(intent) is True

    @pytest.mark.parametrize("confidence", [0.7, 0.75, 0.9, 1.0])
    def test_v55_various_high_confidence_values_do_not_escalate(self, confidence: float):
        """V55: various confidence values at or above threshold do not escalate."""
        intent = Intent(name="claim_status", confidence=confidence)
        assert should_escalate(intent) is False


# ---------------------------------------------------------------------------
# Indic language path — handler routes through IndicConformerClient
# ---------------------------------------------------------------------------

class TestIndicLanguagePath:
    def _make_handler_with_spy_indic(self, confidence: float = 0.9) -> tuple[RasaHandler, MagicMock]:
        """Build handler with a spy IndicConformerClient to verify translation calls."""
        classifier = _StubClassifier(confidence=confidence, intent_name="policy_inquiry")
        mock_indic = MagicMock(spec=IndicConformerClient)
        mock_indic.detect_language.return_value = "en"
        mock_indic.translate_to_english.side_effect = lambda text, lang: text
        mock_indic.translate_from_english.side_effect = lambda text, lang: text
        handler = RasaHandler(
            classifier=classifier,
            core_backend_base_url="http://localhost:3000",
            indic_client=mock_indic,
        )
        return handler, mock_indic

    @pytest.mark.asyncio
    async def test_hindi_message_triggers_translation_to_english(self):
        """Indic path: language='hi' causes translate_to_english to be called before classification."""
        handler, mock_indic = self._make_handler_with_spy_indic()
        request = MessageRequest(
            worker_id="worker-hi",
            message="मेरी पॉलिसी की स्थिति क्या है?",
            language="hi",
            jwt_token="token",
        )

        with patch("services.rasa_assistant.rasa_handler.CoreBackendClient", autospec=True) as MockClient:
            MockClient.return_value.get_policy_context = AsyncMock(return_value={"tier": "gold"})
            MockClient.return_value.get_claim_status = AsyncMock(return_value={})
            MockClient.return_value.get_payout_history = AsyncMock(return_value={})
            response = await handler.handle(request)

        mock_indic.translate_to_english.assert_called_once_with(request.message, "hi")
        assert response.escalated is False

    @pytest.mark.asyncio
    async def test_english_message_skips_translation(self):
        """Indic path: language='en' skips translate_to_english and translate_from_english."""
        handler, mock_indic = self._make_handler_with_spy_indic()
        request = MessageRequest(
            worker_id="worker-en",
            message="What is my policy status?",
            language="en",
            jwt_token="token",
        )

        with patch("services.rasa_assistant.rasa_handler.CoreBackendClient", autospec=True) as MockClient:
            MockClient.return_value.get_policy_context = AsyncMock(return_value={"tier": "silver"})
            MockClient.return_value.get_claim_status = AsyncMock(return_value={})
            MockClient.return_value.get_payout_history = AsyncMock(return_value={})
            await handler.handle(request)

        mock_indic.translate_to_english.assert_not_called()
        mock_indic.translate_from_english.assert_not_called()

    @pytest.mark.asyncio
    async def test_supported_indic_languages_trigger_translation(self):
        """Indic path: all supported non-English languages trigger translation."""
        for lang_code in ["ta", "te", "kn", "bn"]:
            handler, mock_indic = self._make_handler_with_spy_indic()
            request = MessageRequest(
                worker_id=f"worker-{lang_code}",
                message="My query in regional language",
                language=lang_code,
                jwt_token="token",
            )

            with patch("services.rasa_assistant.rasa_handler.CoreBackendClient", autospec=True) as MockClient:
                MockClient.return_value.get_policy_context = AsyncMock(return_value={})
                MockClient.return_value.get_claim_status = AsyncMock(return_value={})
                MockClient.return_value.get_payout_history = AsyncMock(return_value={})
                await handler.handle(request)

            mock_indic.translate_to_english.assert_called_once_with(request.message, lang_code)
            mock_indic.reset_mock()
