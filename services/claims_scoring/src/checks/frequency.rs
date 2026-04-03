use anyhow::Result;
use sqlx::PgPool;
use tracing::{error, info};
use uuid::Uuid;

/// Result of the 90-day frequency check
#[derive(Debug, Clone)]
pub struct FrequencyResult {
    /// Frequency sub-score: 1.0 if claims_90d <= 3, 0.0 if > 3
    pub score: f64,
    /// True if the worker has exceeded the 90-day claim velocity cap (>3 approved claims)
    pub velocity_cap_exceeded: bool,
    /// Number of approved claims in the prior 90-day window
    pub claims_90d: i64,
}

/// Checks how many approved claims the worker has submitted in the prior 90-day window.
///
/// - claims_90d <= 3 → score 1.0, velocity_cap_exceeded = false
/// - claims_90d > 3  → score 0.0, velocity_cap_exceeded = true (routes to FRAUD_QUEUE)
///
/// On DB error, returns a conservative score of 0.5 and logs the error.
pub async fn check_frequency(pool: &PgPool, worker_id: Uuid) -> Result<FrequencyResult> {
    let result = run_frequency_query(pool, worker_id).await;

    match result {
        Ok(r) => Ok(r),
        Err(e) => {
            error!(
                error = %e,
                %worker_id,
                "PostgreSQL frequency query failed — using conservative default score 0.5"
            );
            Ok(FrequencyResult {
                score: 0.5,
                velocity_cap_exceeded: false,
                claims_90d: 0,
            })
        }
    }
}

async fn run_frequency_query(pool: &PgPool, worker_id: Uuid) -> Result<FrequencyResult> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM claims
        WHERE worker_id = $1
          AND status IN ('auto_approved', 'approved')
          AND submitted_at > NOW() - INTERVAL '90 days'
        "#,
    )
    .bind(worker_id)
    .fetch_one(pool)
    .await?;

    let claims_90d = count;
    let velocity_cap_exceeded = claims_90d > 3;
    let score = if velocity_cap_exceeded { 0.0 } else { 1.0 };

    info!(
        %worker_id,
        claims_90d,
        velocity_cap_exceeded,
        "Frequency check complete"
    );

    Ok(FrequencyResult {
        score,
        velocity_cap_exceeded,
        claims_90d,
    })
}
