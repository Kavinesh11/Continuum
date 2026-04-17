mod attestation;
mod checks;
#[cfg(feature = "kafka")]
mod kafka_publisher;
mod metrics;
mod models;
mod population_fraud;
mod scoring;

use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::post,
    Json, Router,
};
use chrono::Utc;
use models::{ClaimStatus, ScoreRequest, ScoreResponse};
#[cfg(feature = "kafka")]
use models::ClaimDecisionEvent;
use scoring::ScoringInputs;
use sqlx::PgPool;
use std::sync::Arc;
use tracing::{error, info};

/// Shared application state
#[derive(Clone)]
struct AppState {
    db: PgPool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialise structured tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("claims_scoring=info".parse()?),
        )
        .json()
        .init();

    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL environment variable must be set");

    let pool = sqlx::PgPool::connect(&database_url).await?;

    let port: u16 = std::env::var("PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8002);

    let state = Arc::new(AppState { db: pool });

    let app = Router::new()
        .route("/score", post(score_handler))
        .route("/metrics", axum::routing::get(metrics_handler))
        .with_state(state);

    let addr = format!("0.0.0.0:{port}");
    info!(addr, "Claims Scoring Service starting");

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

/// GET /metrics — Prometheus metrics endpoint
async fn metrics_handler() -> impl IntoResponse {
    (
        StatusCode::OK,
        [(axum::http::header::CONTENT_TYPE, "text/plain; version=0.0.4")],
        metrics::gather_metrics(),
    )
}

/// POST /score — main claim scoring endpoint
async fn score_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ScoreRequest>,
) -> impl IntoResponse {
    info!(claim_id = %req.claim_id, worker_id = %req.worker_id, "Received score request");

    match process_claim(&state.db, req).await {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(e) => {
            error!(error = %e, "Unhandled error in score_handler");
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"error": "internal_server_error"})),
            )
                .into_response()
        }
    }
}

/// Core claim processing pipeline
async fn process_claim(pool: &PgPool, req: ScoreRequest) -> anyhow::Result<ScoreResponse> {
    // ── Step 1: Play Integrity API attestation (sequential, must pass first) ──
    let attested = match attestation::verify_attestation(&req.device_attestation_token).await {
        Ok(result) => result,
        Err(e) => {
            error!(
                claim_id = %req.claim_id,
                error = %e,
                "Attestation service unreachable"
            );
            // Per error handling spec: reject with ATTESTATION_SERVICE_UNAVAILABLE
            return Ok(ScoreResponse {
                claim_id: req.claim_id,
                status: ClaimStatus::DeviceNotAttested,
                fraud_score: 0.0,
                spatial_score: 0.0,
                frequency_score: 0.0,
                isolation_forest_score: 0.0,
                flags: vec!["ATTESTATION_SERVICE_UNAVAILABLE".to_string()],
                estimated_payout: 0.0,
                decided_at: Utc::now(),
            });
        }
    };

    if !attested {
        info!(claim_id = %req.claim_id, "Device attestation failed — rejecting claim");
        return Ok(ScoreResponse {
            claim_id: req.claim_id,
            status: ClaimStatus::DeviceNotAttested,
            fraud_score: 0.0,
            spatial_score: 0.0,
            frequency_score: 0.0,
            isolation_forest_score: 0.0,
            flags: vec![],
            estimated_payout: 0.0,
            decided_at: Utc::now(),
        });
    }

    // ── Step 2: GPS spoofing pre-checks ──
    let spoofing_result = checks::gps_spoofing::run_gps_spoofing_checks(
        pool,
        req.claim_id,
        req.worker_id,
        req.gps_coordinates,
        req.cell_id_coordinates,
        req.gps_history.as_deref(),
        req.event_timestamp,
        &req.zone_id,
    )
    .await;

    let flags = spoofing_result.flags;
    let spatial_penalty = spoofing_result.spatial_penalty;
    let soak_period_failed = spoofing_result.soak_period_failed;
    let platform_activity_veto = spoofing_result.platform_activity_veto;

    // ── Step 3: Three parallel checks ──
    let lat = req.gps_coordinates[0];
    let lon = req.gps_coordinates[1];
    let zone_id = req.zone_id.clone();
    let worker_id = req.worker_id;
    let feature_vector = req.claim_feature_vector.unwrap_or([0.0; 6]);

    let (spatial_result, frequency_result, if_score) = tokio::join!(
        checks::spatial::check_spatial(pool, &zone_id, lat, lon),
        checks::frequency::check_frequency(pool, worker_id),
        checks::isolation_forest::check_isolation_forest(feature_vector),
    );

    let spatial = spatial_result?;
    let frequency = frequency_result?;
    let isolation_forest_score = if_score?;

    // ── Step 4: Compute composite score and routing decision ──
    let coverage_cap = req.coverage_cap.unwrap_or(0.0);
    let payout_cap = req.payout_cap.unwrap_or(1.0);
    let adjacency_factor = req.adjacency_factor.unwrap_or(
        if spatial.zone_mismatch { 0.5 } else { 1.0 }
    );

    let inputs = ScoringInputs {
        claim_id: req.claim_id,
        spatial,
        frequency,
        isolation_forest_score,
        flags,
        spatial_penalty,
        soak_period_failed,
        platform_activity_veto,
        coverage_cap,
        payout_cap,
        adjacency_factor,
    };

    let mut response = scoring::compute_score(inputs);

    // ── Step 5: Population-level fraud checks (Convergence Freeze + device proximity) ──
    let pop_result = population_fraud::check_population_fraud(
        pool,
        &req.zone_id,
        req.policy_id.unwrap_or_else(uuid::Uuid::new_v4),
        req.worker_id,
        req.device_id.as_deref().unwrap_or(""),
        req.event_timestamp,
    )
    .await;

    if pop_result.convergence_freeze {
        // Override status to FRAUD_QUEUE and add flag (Req 17.2)
        response.status = ClaimStatus::FraudQueue;
        if !response.flags.contains(&"CONVERGENCE_FREEZE".to_string()) {
            response.flags.push("CONVERGENCE_FREEZE".to_string());
        }
        info!(
            claim_id = %req.claim_id,
            zone_id = %req.zone_id,
            claim_count = pop_result.claim_count_5min,
            "Convergence Freeze — claim routed to FRAUD_QUEUE"
        );
    }

    if pop_result.device_cluster_flagged {
        // Flag for elevated review only — do not override status (Req 17.4)
        if !response.flags.contains(&"DEVICE_CLUSTER".to_string()) {
            response.flags.push("DEVICE_CLUSTER".to_string());
        }
        info!(
            claim_id = %req.claim_id,
            cluster_size = pop_result.cluster_size,
            "Device proximity cluster — claim flagged for elevated review"
        );
    }

    // ── Step 6: DB fallback for estimated_payout when coverage_cap not in request ──
    if response.status == ClaimStatus::AutoApproved && response.estimated_payout == 0.0 {
        if let Some(policy_id) = req.policy_id {
            let policy_result = sqlx::query!(
                "SELECT coverage_cap FROM policies WHERE policy_id = $1",
                policy_id
            )
            .fetch_optional(pool)
            .await;

            if let Ok(Some(policy)) = policy_result {
                let db_cap: f64 = policy.coverage_cap.to_string().parse().unwrap_or(0.0);
                response.estimated_payout = db_cap * payout_cap * adjacency_factor;
            }
        }
    }

    // ── Step 7: Emit Prometheus metrics (after final status is determined) ──
    metrics::FRAUD_SCORE_HISTOGRAM.observe(response.fraud_score);
    match response.status {
        ClaimStatus::AutoApproved => metrics::CLAIMS_AUTO_APPROVED_TOTAL.inc(),
        ClaimStatus::FraudQueue => metrics::CLAIMS_FRAUD_QUEUED_TOTAL.inc(),
        _ => {}
    }

    // ── Step 7: Publish claim_decision to Kafka ──
    #[cfg(feature = "kafka")]
    {
    let event = ClaimDecisionEvent {
        claim_id: response.claim_id,
        worker_id: req.worker_id,
        status: response.status.to_string().to_lowercase(),
        fraud_score: response.fraud_score,
        decided_at: response.decided_at,
    };

    if let Err(e) = kafka_publisher::publish_claim_decision(&event, &response.status).await {
        // Log but don't fail the request — Kafka publish is best-effort
        error!(
            claim_id = %req.claim_id,
            error = %e,
            "Failed to publish claim_decision to Kafka"
        );
    }
    }

    info!(
        claim_id = %req.claim_id,
        status = %response.status,
        fraud_score = response.fraud_score,
        "Claim scoring complete"
    );

    Ok(response)
}

#[cfg(test)]
mod tests {
    use super::*;

    // Unit tests for the GPS spoofing module are in checks/gps_spoofing.rs
    // Integration tests are in tests/test_claims_scoring.rs
}
