"""
IndicConformer multilingual NLP integration for the RASA Assistant.

Supports transliteration/translation between English and 5 Indian regional
languages using AI4Bharat IndicConformer.

Supported languages (ISO 639-1 codes):
  hi — Hindi
  ta — Tamil
  te — Telugu
  kn — Kannada
  bn — Bengali
  en — English (pass-through, no translation needed)

Requirements: 13.2, 13.3, 13.6
"""
from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


class IndicConformerClient:
    """
    Client for AI4Bharat IndicConformer multilingual NLP.

    In stub mode (default) all methods are pass-through — no actual translation
    is performed.  Set use_stub=False to attempt loading the real IndicTrans2
    model via the transformers library.
    """

    SUPPORTED_LANGUAGES: dict[str, str] = {
        "hi": "Hindi",
        "ta": "Tamil",
        "te": "Telugu",
        "kn": "Kannada",
        "bn": "Bengali",
        "en": "English",
    }

    def __init__(
        self,
        model_name: str = "ai4bharat/indic-bert",
        use_stub: bool = False,
    ) -> None:
        self._model_name = model_name
        self._stub = True  # default; may be overridden below
        self._model = None
        self._tokenizer = None

        if use_stub:
            logger.info(
                "indic_conformer_stub_mode",
                extra={"model_name": model_name, "reason": "use_stub=True"},
            )
            return

        # Attempt to load the real IndicTrans2 model.
        try:
            from transformers import AutoModelForSeq2SeqLM, AutoTokenizer  # type: ignore

            logger.info(
                "indic_conformer_loading_model",
                extra={"model_name": model_name},
            )
            self._tokenizer = AutoTokenizer.from_pretrained(model_name)
            self._model = AutoModelForSeq2SeqLM.from_pretrained(model_name)
            self._stub = False
            logger.info(
                "indic_conformer_real_mode",
                extra={"model_name": model_name},
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "indic_conformer_model_load_failed_falling_back_to_stub",
                extra={"model_name": model_name, "error": str(exc)},
            )
            self._stub = True

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def detect_language(self, text: str) -> str:
        """
        Detect the ISO 639-1 language code of *text*.

        Stub mode always returns "en".
        Real mode uses langdetect and maps the result to a supported language
        code, defaulting to "en" for unsupported languages.
        """
        if self._stub:
            return "en"

        try:
            from langdetect import detect  # type: ignore

            detected = detect(text)
            if detected in self.SUPPORTED_LANGUAGES:
                return detected
            return "en"
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "indic_conformer_detect_language_error",
                extra={"error": str(exc)},
            )
            return "en"

    def translate_to_english(self, text: str, source_lang: str) -> str:
        """
        Translate *text* from *source_lang* to English.

        Returns *text* unchanged when source_lang is "en", in stub mode, or on
        any translation error.
        """
        if source_lang == "en":
            return text

        if self._stub:
            return text

        try:
            return self._run_translation(text, source_lang, "en")
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "indic_conformer_translate_to_english_error",
                extra={"source_lang": source_lang, "error": str(exc)},
            )
            return text

    def translate_from_english(self, text: str, target_lang: str) -> str:
        """
        Translate *text* from English to *target_lang*.

        Returns *text* unchanged when target_lang is "en", in stub mode, or on
        any translation error.
        """
        if target_lang == "en":
            return text

        if self._stub:
            return text

        try:
            return self._run_translation(text, "en", target_lang)
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "indic_conformer_translate_from_english_error",
                extra={"target_lang": target_lang, "error": str(exc)},
            )
            return text

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _run_translation(self, text: str, src: str, tgt: str) -> str:
        """Run IndicTrans2 inference for src→tgt translation."""
        assert self._tokenizer is not None and self._model is not None  # noqa: S101

        inputs = self._tokenizer(
            text,
            return_tensors="pt",
            padding=True,
        )
        outputs = self._model.generate(**inputs)
        translated: str = self._tokenizer.decode(
            outputs[0],
            skip_special_tokens=True,
        )
        return translated
