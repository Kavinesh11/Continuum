use anyhow::Result;
use tracing::{info, warn};

/// Verifies a Play Integrity API device attestation token.
///
/// In production, calls the Play Integrity API with the provided token.
/// In dev/test (when PLAY_INTEGRITY_API_KEY is not set), treats all tokens as valid
/// and logs a warning.
///
/// Returns `Ok(true)` if the device is attested, `Ok(false)` if attestation fails.
/// Returns `Err` if the attestation service itself is unreachable.
pub async fn verify_attestation(token: &str) -> Result<bool> {
    let api_key = std::env::var("PLAY_INTEGRITY_API_KEY").ok();

    match api_key {
        None => {
            warn!(
                "PLAY_INTEGRITY_API_KEY not set — treating all attestation tokens as valid (dev/test mode)"
            );
            Ok(true)
        }
        Some(key) => call_play_integrity_api(token, &key).await,
    }
}

async fn call_play_integrity_api(token: &str, api_key: &str) -> Result<bool> {
    // Play Integrity API endpoint
    let url = "https://playintegrity.googleapis.com/v1:decodeIntegrityToken";

    let client = reqwest::Client::new();
    let body = serde_json::json!({
        "integrity_token": token
    });

    let response = client
        .post(url)
        .query(&[("key", api_key)])
        .json(&body)
        .send()
        .await?;

    if !response.status().is_success() {
        tracing::error!(
            status = %response.status(),
            "Play Integrity API returned non-success status"
        );
        return Ok(false);
    }

    let payload: serde_json::Value = response.json().await?;

    // Check MEETS_DEVICE_INTEGRITY verdict
    let verdict = payload
        .pointer("/tokenPayloadExternal/deviceIntegrity/deviceRecognitionVerdict")
        .and_then(|v| v.as_array());

    match verdict {
        Some(verdicts) => {
            let attested = verdicts
                .iter()
                .any(|v| v.as_str() == Some("MEETS_DEVICE_INTEGRITY"));
            info!(attested, "Play Integrity API attestation result");
            Ok(attested)
        }
        None => {
            warn!("Play Integrity API response missing deviceRecognitionVerdict");
            Ok(false)
        }
    }
}
