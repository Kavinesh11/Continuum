use crate::models::{ClaimDecisionEvent, ClaimStatus};
use anyhow::Result;
use rdkafka::config::ClientConfig;
use rdkafka::producer::{FutureProducer, FutureRecord};
use std::time::Duration;
use tracing::{error, info};

/// Publishes a `claim_decision` event to Kafka.
///
/// On AUTO_APPROVED, also publishes a `payout_authorized` event.
/// On FRAUD_QUEUE, also publishes a `fraud_alert` event.
pub async fn publish_claim_decision(event: &ClaimDecisionEvent, status: &ClaimStatus) -> Result<()> {
    let brokers = std::env::var("KAFKA_BROKERS").unwrap_or_else(|_| "localhost:9092".to_string());

    let producer: FutureProducer = ClientConfig::new()
        .set("bootstrap.servers", &brokers)
        .set("message.timeout.ms", "5000")
        .create()?;

    // Publish claim_decision event
    let payload = serde_json::to_string(event)?;
    let key = event.claim_id.to_string();

    let delivery_result = producer
        .send(
            FutureRecord::to("claim_decision")
                .payload(&payload)
                .key(&key),
            Duration::from_secs(5),
        )
        .await;

    match delivery_result {
        Ok((partition, offset)) => {
            info!(
                claim_id = %event.claim_id,
                partition,
                offset,
                "Published claim_decision to Kafka"
            );
        }
        Err((e, _)) => {
            error!(
                claim_id = %event.claim_id,
                error = %e,
                "Failed to publish claim_decision to Kafka"
            );
            return Err(anyhow::anyhow!("Kafka publish failed: {e}"));
        }
    }

    // Publish secondary event based on routing decision
    match status {
        ClaimStatus::AutoApproved => {
            publish_payout_authorized(&producer, event).await?;
        }
        ClaimStatus::FraudQueue => {
            publish_fraud_alert(&producer, event).await?;
        }
        _ => {
            // DEVICE_NOT_ATTESTED and PLATFORM_ACTIVITY_VETO do not trigger secondary events
        }
    }

    Ok(())
}

async fn publish_payout_authorized(producer: &FutureProducer, event: &ClaimDecisionEvent) -> Result<()> {
    let payload = serde_json::json!({
        "claim_id": event.claim_id,
        "worker_id": event.worker_id,
        "fraud_score": event.fraud_score,
        "authorized_at": event.decided_at,
    });

    let payload_str = serde_json::to_string(&payload)?;
    let key = event.claim_id.to_string();

    let delivery_result = producer
        .send(
            FutureRecord::to("payout_authorized")
                .payload(&payload_str)
                .key(&key),
            Duration::from_secs(5),
        )
        .await;

    match delivery_result {
        Ok((partition, offset)) => {
            info!(
                claim_id = %event.claim_id,
                partition,
                offset,
                "Published payout_authorized to Kafka"
            );
            Ok(())
        }
        Err((e, _)) => {
            error!(
                claim_id = %event.claim_id,
                error = %e,
                "Failed to publish payout_authorized to Kafka"
            );
            Err(anyhow::anyhow!("Kafka publish failed: {e}"))
        }
    }
}

async fn publish_fraud_alert(producer: &FutureProducer, event: &ClaimDecisionEvent) -> Result<()> {
    let payload = serde_json::json!({
        "alert_type": "fraud_queue_routing",
        "claim_id": event.claim_id,
        "worker_id": event.worker_id,
        "fraud_score": event.fraud_score,
        "triggered_at": event.decided_at,
    });

    let payload_str = serde_json::to_string(&payload)?;
    let key = event.claim_id.to_string();

    let delivery_result = producer
        .send(
            FutureRecord::to("fraud_alert")
                .payload(&payload_str)
                .key(&key),
            Duration::from_secs(5),
        )
        .await;

    match delivery_result {
        Ok((partition, offset)) => {
            info!(
                claim_id = %event.claim_id,
                partition,
                offset,
                "Published fraud_alert to Kafka"
            );
            Ok(())
        }
        Err((e, _)) => {
            error!(
                claim_id = %event.claim_id,
                error = %e,
                "Failed to publish fraud_alert to Kafka"
            );
            Err(anyhow::anyhow!("Kafka publish failed: {e}"))
        }
    }
}
