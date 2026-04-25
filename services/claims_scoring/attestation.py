import logging
import os

import httpx

logger = logging.getLogger(__name__)

_PLAY_INTEGRITY_URL = "https://playintegrity.googleapis.com/v1:decodeIntegrityToken"


async def verify_attestation(token: str) -> bool:
    api_key = os.getenv("PLAY_INTEGRITY_API_KEY")
    if not api_key:
        logger.warning("PLAY_INTEGRITY_API_KEY not set — accepting all tokens (dev/test mode)")
        return True
    return await _call_play_integrity_api(token, api_key)


async def _call_play_integrity_api(token: str, api_key: str) -> bool:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            _PLAY_INTEGRITY_URL,
            params={"key": api_key},
            json={"integrity_token": token},
        )

    if not response.is_success:
        logger.error("Play Integrity API returned status %d", response.status_code)
        return False

    payload = response.json()
    verdicts = (
        payload
        .get("tokenPayloadExternal", {})
        .get("deviceIntegrity", {})
        .get("deviceRecognitionVerdict", [])
    )
    attested = "MEETS_DEVICE_INTEGRITY" in verdicts
    logger.info("Play Integrity attestation result: %s", attested)
    return attested
