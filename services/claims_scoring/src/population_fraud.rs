/// Population-level fraud detection module.
///
/// Implements two population-level checks per Requirements 17.1–17.6:
///
/// 1. **Convergence Freeze** (Req 17.1, 17.2, 17.6):
///    Counts distinct policy IDs submitting claims for the same zone in the
///    last 5 minutes. If ≥ 50, triggers a Convergence Freeze and publishes a
///    `fraud_alert` event to Kafka.
///
/// 2. **Device Proximity Co-location** (Req 17.3, 17.4):
///    Queries `device_proximity_log` for devices co-located with the current
///    device within the prior 7 days. If cluster size ≥ 5, flags for elevated
///    manual review.
///
/// Migration note:
/// ```sql
/// -- device_proximity_log table (add to schema migrations)
/// CREATE TABLE device_proximity_log (
///     device_id_a  TEXT        NOT NULL,
///     device_id_b  TEXT        NOT NULL,
///     recorded_at  TIMESTAMPTZ NOT NULL
/// );
/// CREATE INDEX ON device_proximity_log (device_id_a, recorded_at DESC);
/// CREATE INDEX ON device_proximity_log (device_id_b, recorded_at DESC);
/// ```
use chrono::{DateTime, Utc};
#[cfg(feature = "kafka")]
use rdkafka::config::ClientConfig;
#[cfg(feature = "kafka")]
use rdkafka::producer::{FutureProducer, FutureRecord};
use sqlx::PgPool;
#[cfg(feature = "kafka")]
use std::time::Duration;
use tracing::{error, info};
use uuid::Uuid;

/// Threshold for Convergence Freeze (Req 17.2)
pub const CONVERGENCE_FREEZE_THRESHOLD: usize = 50;

/// Threshold for device proximity cluster flagging (Req 17.4)
pub const DEVICE_CLUSTER_THRESHOLD: usize = 5;

/// Result of the population-level fraud checks.
#[derive(Debug, Clone)]
pub struct PopulationFraudResult {
    /// True when ≥ 50 unique policy IDs submitted claims for the same zone
    /// within the last 5 minutes (Req 17.2).
    pub convergence_freeze: bool,
    /// True when ≥ 5 devices were co-located with this device within 7 days
    /// (Req 17.4).
    pub device_cluster_flagged: bool,
    /// Number of distinct policy IDs in the 5-minute window for this zone.
    pub claim_count_5min: usize,
    /// Number of distinct devices co-located with this device in 7 days.
    pub cluster_size: usize,
}

/// Runs both population-level fraud checks and optionally publishes a
/// `fraud_alert` Kafka event on Convergence Freeze.
///
/// # Arguments
/// * `pool`         – PostgreSQL connection pool
/// * `zone_id`      – Zone identifier for the submitted claim
/// * `policy_id`    – Policy UUID of the submitting worker
/// * `worker_id`    – Worker UUID (unused in queries but kept for future audit)
/// * `device_id`    – Device identifier for proximity check
/// * `submitted_at` – Timestamp of the claim submission
pub async fn check_population_fraud(
    pool: &PgPool,
    zone_id: &str,
    policy_id: Uuid,
    worker_id: Uuid,
    device_id: &str,
    submitted_at: DateTime<Utc>,
) -> PopulationFraudResult {
    let _ = (policy_id, worker_id, submitted_at); // kept for signature / future use

    // ── Check 1: Convergence Freeze ──────────────────────────────────────────
    let claim_count_5min = query_zone_claim_count(pool, zone_id).await;
    let convergence_freeze = claim_count_5min >= CONVERGENCE_FREEZE_THRESHOLD;

    if convergence_freeze {
        info!(
            zone_id,
            claim_count = claim_count_5min,
            "Convergence Freeze triggered"
        );
        #[cfg(feature = "kafka")]
        publish_convergence_freeze_alert(zone_id, claim_count_5min).await;
    }

    // ── Check 2: Device proximity co-location ────────────────────────────────
    let cluster_size = query_device_cluster_size(pool, device_id).await;
    let device_cluster_flagged = cluster_size >= DEVICE_CLUSTER_THRESHOLD;

    if device_cluster_flagged {
        info!(
            device_id,
            cluster_size,
            "Device proximity cluster flagged for elevated review"
        );
    }

    PopulationFraudResult {
        convergence_freeze,
        device_cluster_flagged,
        claim_count_5min,
        cluster_size,
    }
}

// ── Internal helpers ─────────────────────────────────────────────────────────

/// Counts distinct policy IDs that submitted claims for `zone_id` in the last
/// 5 minutes (Req 17.1).
async fn query_zone_claim_count(pool: &PgPool, zone_id: &str) -> usize {
    let result = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(DISTINCT policy_id)
        FROM   claims
        WHERE  zone_id     = $1
          AND  submitted_at > NOW() - INTERVAL '5 minutes'
        "#,
    )
    .bind(zone_id)
    .fetch_one(pool)
    .await;

    match result {
        Ok(count) => count.max(0) as usize,
        Err(e) => {
            error!(zone_id, error = %e, "Failed to query zone claim count");
            0
        }
    }
}

/// Counts distinct devices co-located with `device_id` within the last 7 days
/// (Req 17.3).
async fn query_device_cluster_size(pool: &PgPool, device_id: &str) -> usize {
    let result = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(DISTINCT
               CASE WHEN device_id_a = $1 THEN device_id_b
                    ELSE device_id_a
               END)
        FROM   device_proximity_log
        WHERE  (device_id_a = $1 OR device_id_b = $1)
          AND  recorded_at > NOW() - INTERVAL '7 days'
        "#,
    )
    .bind(device_id)
    .fetch_one(pool)
    .await;

    match result {
        Ok(count) => count.max(0) as usize,
        Err(e) => {
            error!(device_id, error = %e, "Failed to query device cluster size");
            0
        }
    }
}

/// Publishes a `fraud_alert` event to Kafka for a Convergence Freeze (Req 17.6).
/// On Kafka error, logs the error but does not fail the check.
#[cfg(feature = "kafka")]
async fn publish_convergence_freeze_alert(zone_id: &str, claim_count: usize) {
    let brokers =
        std::env::var("KAFKA_BROKERS").unwrap_or_else(|_| "localhost:9092".to_string());

    let producer: FutureProducer = match ClientConfig::new()
        .set("bootstrap.servers", &brokers)
        .set("message.timeout.ms", "5000")
        .create()
    {
        Ok(p) => p,
        Err(e) => {
            error!(error = %e, "Failed to create Kafka producer for fraud_alert");
            return;
        }
    };

    let payload = serde_json::json!({
        "alert_type": "convergence_freeze",
        "zone_id":    zone_id,
        "claim_count": claim_count,
        "triggered_at": Utc::now().to_rfc3339(),
    });

    let payload_str = match serde_json::to_string(&payload) {
        Ok(s) => s,
        Err(e) => {
            error!(error = %e, "Failed to serialise fraud_alert payload");
            return;
        }
    };

    let delivery = producer
        .send(
            FutureRecord::to("fraud_alert")
                .payload(&payload_str)
                .key(zone_id),
            Duration::from_secs(5),
        )
        .await;

    match delivery {
        Ok((partition, offset)) => {
            info!(
                zone_id,
                partition,
                offset,
                "Published convergence_freeze fraud_alert to Kafka"
            );
        }
        Err((e, _)) => {
            error!(
                zone_id,
                error = %e,
                "Failed to publish convergence_freeze fraud_alert to Kafka (non-fatal)"
            );
        }
    }
}

// ── Pure-function helpers exposed for unit testing ───────────────────────────

/// Returns `true` when `count` meets or exceeds the Convergence Freeze threshold.
#[inline]
pub fn is_convergence_freeze(count: usize) -> bool {
    count >= CONVERGENCE_FREEZE_THRESHOLD
}

/// Returns `true` when `size` meets or exceeds the device cluster threshold.
#[inline]
pub fn is_device_cluster_flagged(size: usize) -> bool {
    size >= DEVICE_CLUSTER_THRESHOLD
}

// ── Unit tests ────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── Convergence Freeze threshold tests ────────────────────────────────────

    #[test]
    fn convergence_freeze_not_triggered_below_threshold() {
        assert!(!is_convergence_freeze(0));
        assert!(!is_convergence_freeze(1));
        assert!(!is_convergence_freeze(49));
    }

    #[test]
    fn convergence_freeze_triggered_at_threshold() {
        assert!(is_convergence_freeze(50));
    }

    #[test]
    fn convergence_freeze_triggered_above_threshold() {
        assert!(is_convergence_freeze(51));
        assert!(is_convergence_freeze(1000));
    }

    // ── Device cluster threshold tests ────────────────────────────────────────

    #[test]
    fn device_cluster_not_flagged_below_threshold() {
        assert!(!is_device_cluster_flagged(0));
        assert!(!is_device_cluster_flagged(1));
        assert!(!is_device_cluster_flagged(4));
    }

    #[test]
    fn device_cluster_flagged_at_threshold() {
        assert!(is_device_cluster_flagged(5));
    }

    #[test]
    fn device_cluster_flagged_above_threshold() {
        assert!(is_device_cluster_flagged(6));
        assert!(is_device_cluster_flagged(100));
    }

    // ── PopulationFraudResult construction ────────────────────────────────────

    #[test]
    fn result_reflects_threshold_logic() {
        let result = PopulationFraudResult {
            convergence_freeze: is_convergence_freeze(50),
            device_cluster_flagged: is_device_cluster_flagged(5),
            claim_count_5min: 50,
            cluster_size: 5,
        };
        assert!(result.convergence_freeze);
        assert!(result.device_cluster_flagged);
    }

    #[test]
    fn result_no_flags_below_thresholds() {
        let result = PopulationFraudResult {
            convergence_freeze: is_convergence_freeze(49),
            device_cluster_flagged: is_device_cluster_flagged(4),
            claim_count_5min: 49,
            cluster_size: 4,
        };
        assert!(!result.convergence_freeze);
        assert!(!result.device_cluster_flagged);
    }
}
