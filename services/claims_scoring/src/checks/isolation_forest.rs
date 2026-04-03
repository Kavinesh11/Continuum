use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixStream;
use tracing::{error, info};

/// JSON-RPC request sent to the Python Isolation Forest sidecar
#[derive(Debug, Serialize)]
struct IsolationForestRequest {
    jsonrpc: &'static str,
    method: &'static str,
    params: IsolationForestParams,
    id: u64,
}

#[derive(Debug, Serialize)]
struct IsolationForestParams {
    feature_vector: [f64; 6],
}

/// JSON-RPC response from the Python sidecar
#[derive(Debug, Deserialize)]
struct IsolationForestResponse {
    result: Option<IsolationForestResult>,
    error: Option<serde_json::Value>,
}

#[derive(Debug, Deserialize)]
struct IsolationForestResult {
    fraud_score: f64,
}

/// Calls the Python Isolation Forest sidecar via Unix domain socket (JSON-RPC).
///
/// The sidecar normalises the raw anomaly score to `Fraud_Score = 1 - (raw_score + 0.5)`,
/// clipped to [0.0, 1.0], and returns it in the `fraud_score` field.
///
/// On sidecar unreachable or error, routes conservatively to FRAUD_QUEUE by returning 0.0.
pub async fn check_isolation_forest(feature_vector: [f64; 6]) -> Result<f64> {
    let socket_path = std::env::var("ISOLATION_FOREST_SOCKET")
        .unwrap_or_else(|_| "/tmp/isolation_forest.sock".to_string());

    let result = call_sidecar(&socket_path, feature_vector).await;

    match result {
        Ok(score) => {
            info!(score, "Isolation Forest sidecar returned score");
            Ok(score)
        }
        Err(e) => {
            error!(
                error = %e,
                socket_path,
                "Isolation Forest sidecar unreachable — routing conservatively to FRAUD_QUEUE (score 0.0)"
            );
            // Conservative: route to FRAUD_QUEUE on sidecar failure
            Ok(0.0)
        }
    }
}

async fn call_sidecar(socket_path: &str, feature_vector: [f64; 6]) -> Result<f64> {
    let mut stream = UnixStream::connect(socket_path)
        .await
        .with_context(|| format!("Failed to connect to Unix socket at {socket_path}"))?;

    let request = IsolationForestRequest {
        jsonrpc: "2.0",
        method: "score",
        params: IsolationForestParams { feature_vector },
        id: 1,
    };

    let request_bytes = serde_json::to_vec(&request)?;

    // Write length-prefixed message (4-byte big-endian length + payload)
    let len = request_bytes.len() as u32;
    stream.write_all(&len.to_be_bytes()).await?;
    stream.write_all(&request_bytes).await?;

    // Read length-prefixed response
    let mut len_buf = [0u8; 4];
    stream.read_exact(&mut len_buf).await?;
    let response_len = u32::from_be_bytes(len_buf) as usize;

    let mut response_buf = vec![0u8; response_len];
    stream.read_exact(&mut response_buf).await?;

    let response: IsolationForestResponse = serde_json::from_slice(&response_buf)
        .context("Failed to deserialize Isolation Forest response")?;

    if let Some(err) = response.error {
        anyhow::bail!("Isolation Forest sidecar returned error: {err}");
    }

    let result = response
        .result
        .context("Isolation Forest response missing result field")?;

    // Clamp to [0.0, 1.0] as a safety measure
    let score = result.fraud_score.clamp(0.0, 1.0);
    Ok(score)
}
