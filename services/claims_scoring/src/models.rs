use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// GPS history point for soak period check
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpsPoint {
    pub lat: f64,
    pub lon: f64,
    pub ts: DateTime<Utc>,
}

/// Incoming claim scoring request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScoreRequest {
    pub claim_id: Uuid,
    pub worker_id: Uuid,
    /// Policy UUID — required for Convergence Freeze population check (Req 17.1)
    pub policy_id: Option<Uuid>,
    pub event_type: String,
    pub event_timestamp: DateTime<Utc>,
    /// [lat, lon]
    pub gps_coordinates: [f64; 2],
    pub zone_id: String,
    pub device_attestation_token: String,
    /// Optional Cell-ID coordinates for divergence check [lat, lon]
    pub cell_id_coordinates: Option<[f64; 2]>,
    /// GPS history for soak period check
    pub gps_history: Option<Vec<GpsPoint>>,
    /// 6-dimensional feature vector for Isolation Forest
    pub claim_feature_vector: Option<[f64; 6]>,
    /// Device identifier for Bluetooth/WiFi proximity co-location check (Req 17.3)
    pub device_id: Option<String>,
}

/// Claim decision status
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ClaimStatus {
    AutoApproved,
    FraudQueue,
    DeviceNotAttested,
    PlatformActivityVeto,
}

impl std::fmt::Display for ClaimStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ClaimStatus::AutoApproved => write!(f, "AUTO_APPROVED"),
            ClaimStatus::FraudQueue => write!(f, "FRAUD_QUEUE"),
            ClaimStatus::DeviceNotAttested => write!(f, "DEVICE_NOT_ATTESTED"),
            ClaimStatus::PlatformActivityVeto => write!(f, "PLATFORM_ACTIVITY_VETO"),
        }
    }
}

/// Scoring response returned to caller
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScoreResponse {
    pub claim_id: Uuid,
    pub status: ClaimStatus,
    pub fraud_score: f64,
    pub spatial_score: f64,
    pub frequency_score: f64,
    pub isolation_forest_score: f64,
    /// Optional flags (e.g. LOCATION_MISMATCH, STATIC_LOCK)
    pub flags: Vec<String>,
    pub estimated_payout: f64,
    pub decided_at: DateTime<Utc>,
}

/// Kafka claim_decision event payload
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClaimDecisionEvent {
    pub claim_id: Uuid,
    pub worker_id: Uuid,
    pub status: String,
    pub fraud_score: f64,
    pub decided_at: DateTime<Utc>,
}
