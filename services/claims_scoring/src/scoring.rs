use crate::checks::{frequency::FrequencyResult, spatial::SpatialResult};
use crate::models::{ClaimStatus, ScoreResponse};
use chrono::Utc;
use uuid::Uuid;

/// Weights for the composite Fraud_Score
const SPATIAL_WEIGHT: f64 = 0.4;
const FREQUENCY_WEIGHT: f64 = 0.2;
const ISOLATION_FOREST_WEIGHT: f64 = 0.4;

/// Threshold above which a claim is AUTO_APPROVED
const AUTO_APPROVE_THRESHOLD: f64 = 0.7;

/// Inputs to the composite scoring function
pub struct ScoringInputs {
    pub claim_id: Uuid,
    pub spatial: SpatialResult,
    pub frequency: FrequencyResult,
    pub isolation_forest_score: f64,
    /// Accumulated flags from pre-checks (e.g. LOCATION_MISMATCH)
    pub flags: Vec<String>,
    /// Spatial score penalty from Cell-ID divergence check (-0.3 if LOCATION_MISMATCH)
    pub spatial_penalty: f64,
    /// True if soak period was not met (forces FRAUD_QUEUE)
    pub soak_period_failed: bool,
    /// True if platform API vetoed the claim (forces PLATFORM_ACTIVITY_VETO)
    pub platform_activity_veto: bool,
    /// Policy tier coverage cap (INR). Used to compute estimated_payout.
    pub coverage_cap: f64,
    /// Oracle consensus payout cap factor (0.0–1.0).
    pub payout_cap: f64,
    /// Adjacency factor: 1.0 exact, 0.7 buffer, 0.5 touch.
    pub adjacency_factor: f64,
}

/// Computes the composite Fraud_Score and routing decision.
///
/// Formula:
///   Fraud_Score = 0.4 × spatial_score + 0.2 × frequency_score + 0.4 × isolation_forest_score
///
/// Routing:
///   - velocity_cap_exceeded → FRAUD_QUEUE (regardless of score)
///   - soak_period_failed    → FRAUD_QUEUE
///   - platform_activity_veto → PLATFORM_ACTIVITY_VETO
///   - Fraud_Score >= 0.7    → AUTO_APPROVED
///   - Fraud_Score < 0.7     → FRAUD_QUEUE
pub fn compute_score(inputs: ScoringInputs) -> ScoreResponse {
    // Apply spatial penalty (e.g. from LOCATION_MISMATCH Cell-ID divergence)
    let adjusted_spatial = (inputs.spatial.score - inputs.spatial_penalty).clamp(0.0, 1.0);

    let fraud_score = (SPATIAL_WEIGHT * adjusted_spatial
        + FREQUENCY_WEIGHT * inputs.frequency.score
        + ISOLATION_FOREST_WEIGHT * inputs.isolation_forest_score)
        .clamp(0.0, 1.0);

    let mut flags = inputs.flags;

    // Add zone_mismatch flag if applicable
    if inputs.spatial.zone_mismatch {
        if !flags.contains(&"ZONE_MISMATCH".to_string()) {
            flags.push("ZONE_MISMATCH".to_string());
        }
    }

    // Determine routing status
    let status = if inputs.platform_activity_veto {
        ClaimStatus::PlatformActivityVeto
    } else if inputs.frequency.velocity_cap_exceeded || inputs.soak_period_failed {
        ClaimStatus::FraudQueue
    } else if fraud_score >= AUTO_APPROVE_THRESHOLD {
        ClaimStatus::AutoApproved
    } else {
        ClaimStatus::FraudQueue
    };

    let estimated_payout = if status == ClaimStatus::AutoApproved {
        inputs.coverage_cap * inputs.payout_cap * inputs.adjacency_factor
    } else {
        0.0
    };

    ScoreResponse {
        claim_id: inputs.claim_id,
        status,
        fraud_score,
        spatial_score: adjusted_spatial,
        frequency_score: inputs.frequency.score,
        isolation_forest_score: inputs.isolation_forest_score,
        flags,
        estimated_payout,
        decided_at: Utc::now(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::checks::{frequency::FrequencyResult, spatial::SpatialResult};

    fn make_inputs(spatial_score: f64, frequency_score: f64, if_score: f64) -> ScoringInputs {
        ScoringInputs {
            claim_id: Uuid::new_v4(),
            spatial: SpatialResult {
                score: spatial_score,
                zone_mismatch: spatial_score < 1.0,
            },
            frequency: FrequencyResult {
                score: frequency_score,
                velocity_cap_exceeded: frequency_score == 0.0,
                claims_90d: if frequency_score == 0.0 { 4 } else { 1 },
            },
            isolation_forest_score: if_score,
            flags: vec![],
            spatial_penalty: 0.0,
            soak_period_failed: false,
            platform_activity_veto: false,
            coverage_cap: 1000.0,
            payout_cap: 0.75,
            adjacency_factor: 1.0,
        }
    }

    #[test]
    fn test_auto_approved_at_threshold() {
        // 0.4*1.0 + 0.2*1.0 + 0.4*0.75 = 0.4 + 0.2 + 0.3 = 0.9
        let resp = compute_score(make_inputs(1.0, 1.0, 0.75));
        assert_eq!(resp.status, ClaimStatus::AutoApproved);
        assert!(resp.fraud_score >= 0.7);
    }

    #[test]
    fn test_fraud_queue_below_threshold() {
        // 0.4*0.0 + 0.2*1.0 + 0.4*0.5 = 0.0 + 0.2 + 0.2 = 0.4
        let resp = compute_score(make_inputs(0.0, 1.0, 0.5));
        assert_eq!(resp.status, ClaimStatus::FraudQueue);
        assert!(resp.fraud_score < 0.7);
    }

    #[test]
    fn test_velocity_cap_forces_fraud_queue() {
        // Even with perfect scores, velocity cap overrides
        let mut inputs = make_inputs(1.0, 0.0, 1.0);
        inputs.frequency.velocity_cap_exceeded = true;
        let resp = compute_score(inputs);
        assert_eq!(resp.status, ClaimStatus::FraudQueue);
    }

    #[test]
    fn test_soak_period_failure_forces_fraud_queue() {
        let mut inputs = make_inputs(1.0, 1.0, 1.0);
        inputs.soak_period_failed = true;
        let resp = compute_score(inputs);
        assert_eq!(resp.status, ClaimStatus::FraudQueue);
    }

    #[test]
    fn test_platform_activity_veto() {
        let mut inputs = make_inputs(1.0, 1.0, 1.0);
        inputs.platform_activity_veto = true;
        let resp = compute_score(inputs);
        assert_eq!(resp.status, ClaimStatus::PlatformActivityVeto);
    }

    #[test]
    fn test_spatial_penalty_applied() {
        // spatial_score=1.0, penalty=0.3 → adjusted=0.7
        // 0.4*0.7 + 0.2*1.0 + 0.4*1.0 = 0.28 + 0.2 + 0.4 = 0.88
        let mut inputs = make_inputs(1.0, 1.0, 1.0);
        inputs.spatial.zone_mismatch = false;
        inputs.spatial_penalty = 0.3;
        let resp = compute_score(inputs);
        assert!((resp.spatial_score - 0.7).abs() < 1e-9);
    }

    #[test]
    fn test_fraud_score_clamped_to_unit_interval() {
        let resp = compute_score(make_inputs(1.0, 1.0, 1.0));
        assert!(resp.fraud_score >= 0.0 && resp.fraud_score <= 1.0);
    }
}
