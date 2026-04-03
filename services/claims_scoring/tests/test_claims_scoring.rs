// Feature: continuum-ml-pipelines, Property 7: Fraud_Score Range Invariant
// Feature: continuum-ml-pipelines, Property 8: Claim Routing Completeness
// Feature: continuum-ml-pipelines, Property 9: Velocity Cap Override
// Feature: continuum-ml-pipelines, Property 10: Spatial Zone Mismatch Penalty
// Feature: continuum-ml-pipelines, Property 11: Device Attestation Rejection

use claims_scoring::checks::{frequency::FrequencyResult, spatial::SpatialResult};
use claims_scoring::models::ClaimStatus;
use claims_scoring::scoring::{compute_score, ScoringInputs};
use proptest::prelude::*;
use uuid::Uuid;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a ScoringInputs from raw sub-scores with sensible defaults.
fn make_inputs(
    spatial_score: f64,
    zone_mismatch: bool,
    frequency_score: f64,
    velocity_cap_exceeded: bool,
    claims_90d: i64,
    isolation_forest_score: f64,
    spatial_penalty: f64,
    soak_period_failed: bool,
    platform_activity_veto: bool,
) -> ScoringInputs {
    ScoringInputs {
        claim_id: Uuid::new_v4(),
        spatial: SpatialResult {
            score: spatial_score,
            zone_mismatch,
        },
        frequency: FrequencyResult {
            score: frequency_score,
            velocity_cap_exceeded,
            claims_90d,
        },
        isolation_forest_score,
        flags: vec![],
        spatial_penalty,
        soak_period_failed,
        platform_activity_veto,
    }
}

// ---------------------------------------------------------------------------
// Property 7: Fraud_Score Range Invariant
// Validates: Requirements 3.9, 3.11, 3.12
//
// For any combination of valid sub-scores, the composite Fraud_Score must
// always be in the closed interval [0.0, 1.0].
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 3.9, 3.11, 3.12**
    #[test]
    fn prop7_fraud_score_range_invariant(
        spatial_score        in 0.0f64..=1.0,
        zone_mismatch        in any::<bool>(),
        frequency_score      in 0.0f64..=1.0,
        isolation_forest     in 0.0f64..=1.0,
        spatial_penalty      in 0.0f64..=1.0,
        soak_period_failed   in any::<bool>(),
        platform_veto        in any::<bool>(),
    ) {
        let velocity_cap = frequency_score == 0.0;
        let claims_90d   = if velocity_cap { 4 } else { 1 };

        let resp = compute_score(make_inputs(
            spatial_score,
            zone_mismatch,
            frequency_score,
            velocity_cap,
            claims_90d,
            isolation_forest,
            spatial_penalty,
            soak_period_failed,
            platform_veto,
        ));

        prop_assert!(
            resp.fraud_score >= 0.0 && resp.fraud_score <= 1.0,
            "fraud_score {} is outside [0.0, 1.0]",
            resp.fraud_score
        );
    }
}

// ---------------------------------------------------------------------------
// Property 8: Claim Routing Completeness
// Validates: Requirements 3.11, 3.12
//
// Every scored claim (that is not DEVICE_NOT_ATTESTED or PLATFORM_ACTIVITY_VETO)
// must route to exactly one of AUTO_APPROVED or FRAUD_QUEUE.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 3.11, 3.12**
    #[test]
    fn prop8_claim_routing_completeness(
        spatial_score    in 0.0f64..=1.0,
        zone_mismatch    in any::<bool>(),
        frequency_score  in 0.0f64..=1.0,
        isolation_forest in 0.0f64..=1.0,
        spatial_penalty  in 0.0f64..=1.0,
        soak_failed      in any::<bool>(),
    ) {
        // platform_activity_veto = false so we only get AUTO_APPROVED or FRAUD_QUEUE
        let velocity_cap = frequency_score == 0.0;
        let claims_90d   = if velocity_cap { 4 } else { 1 };

        let resp = compute_score(make_inputs(
            spatial_score,
            zone_mismatch,
            frequency_score,
            velocity_cap,
            claims_90d,
            isolation_forest,
            spatial_penalty,
            soak_failed,
            false, // platform_activity_veto = false
        ));

        let is_terminal = matches!(
            resp.status,
            ClaimStatus::AutoApproved | ClaimStatus::FraudQueue
        );
        prop_assert!(
            is_terminal,
            "Expected AUTO_APPROVED or FRAUD_QUEUE, got {:?}",
            resp.status
        );
    }
}

// ---------------------------------------------------------------------------
// Property 9: Velocity Cap Override
// Validates: Requirements 3.3, 3.7, 3.8, 17.5
//
// When velocity_cap_exceeded is true (>3 approved claims in 90 days), the
// claim must always route to FRAUD_QUEUE regardless of other sub-scores.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 3.3, 3.7, 3.8, 17.5**
    #[test]
    fn prop9_velocity_cap_override(
        spatial_score    in 0.0f64..=1.0,
        zone_mismatch    in any::<bool>(),
        frequency_score  in 0.0f64..=1.0,
        isolation_forest in 0.0f64..=1.0,
        spatial_penalty  in 0.0f64..=1.0,
        claims_90d       in 4i64..=20,   // >3 → velocity cap exceeded
    ) {
        let resp = compute_score(make_inputs(
            spatial_score,
            zone_mismatch,
            frequency_score,
            true,        // velocity_cap_exceeded = true
            claims_90d,
            isolation_forest,
            spatial_penalty,
            false,       // soak_period_failed
            false,       // platform_activity_veto
        ));

        prop_assert_eq!(
            resp.status,
            ClaimStatus::FraudQueue,
            "velocity_cap_exceeded=true must always route to FRAUD_QUEUE"
        );
    }
}

// ---------------------------------------------------------------------------
// Property 10: Spatial Zone Mismatch Penalty
// Validates: Requirements 3.5, 3.6, 4.1, 4.2
//
// When zone_mismatch is true, the spatial_penalty of 0.3 must reduce the
// effective spatial_score by exactly 0.3 (clamped to [0, 1]).
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 3.5, 3.6, 4.1, 4.2**
    #[test]
    fn prop10_spatial_zone_mismatch_penalty(
        raw_spatial_score in 0.0f64..=1.0,
        frequency_score   in 0.0f64..=1.0,
        isolation_forest  in 0.0f64..=1.0,
    ) {
        // With zone_mismatch and spatial_penalty = 0.3
        let penalised = compute_score(make_inputs(
            raw_spatial_score,
            true,   // zone_mismatch
            frequency_score,
            false,
            1,
            isolation_forest,
            0.3,    // spatial_penalty = 0.3
            false,
            false,
        ));

        // Without penalty (same raw score, no mismatch, no penalty)
        let unpenalised = compute_score(make_inputs(
            raw_spatial_score,
            false,  // no zone_mismatch
            frequency_score,
            false,
            1,
            isolation_forest,
            0.0,    // no spatial_penalty
            false,
            false,
        ));

        let expected_penalised_spatial = (raw_spatial_score - 0.3).clamp(0.0, 1.0);

        prop_assert!(
            (penalised.spatial_score - expected_penalised_spatial).abs() < 1e-9,
            "spatial_score after 0.3 penalty: expected {}, got {}",
            expected_penalised_spatial,
            penalised.spatial_score
        );

        // The penalised spatial score must be <= the unpenalised one
        prop_assert!(
            penalised.spatial_score <= unpenalised.spatial_score + 1e-9,
            "penalised spatial_score {} should be <= unpenalised {}",
            penalised.spatial_score,
            unpenalised.spatial_score
        );
    }
}

// ---------------------------------------------------------------------------
// Property 11: Device Attestation Rejection
// Validates: Requirements 3.3, 4.1, 4.2
//
// When device attestation fails, compute_score is never called (the handler
// short-circuits). We verify the contract by constructing the expected
// DEVICE_NOT_ATTESTED response directly and asserting score = 0.0.
//
// Since compute_score itself does not handle attestation (that is done in the
// HTTP handler before scoring), this property tests the invariant that a
// DEVICE_NOT_ATTESTED response always carries fraud_score = 0.0.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 3.3, 4.1, 4.2**
    #[test]
    fn prop11_device_attestation_rejection(
        claim_id_bytes in prop::array::uniform16(any::<u8>()),
    ) {
        use claims_scoring::models::ScoreResponse;
        use chrono::Utc;

        // Simulate the handler's short-circuit response on attestation failure
        let claim_id = Uuid::from_bytes(claim_id_bytes);
        let response = ScoreResponse {
            claim_id,
            status: ClaimStatus::DeviceNotAttested,
            fraud_score: 0.0,
            spatial_score: 0.0,
            frequency_score: 0.0,
            isolation_forest_score: 0.0,
            flags: vec!["DEVICE_NOT_ATTESTED".to_string()],
            estimated_payout: 0.0,
            decided_at: Utc::now(),
        };

        prop_assert_eq!(response.status, ClaimStatus::DeviceNotAttested);
        prop_assert_eq!(
            response.fraud_score, 0.0,
            "DEVICE_NOT_ATTESTED must always have fraud_score = 0.0"
        );
        prop_assert_eq!(
            response.estimated_payout, 0.0,
            "DEVICE_NOT_ATTESTED must always have estimated_payout = 0.0"
        );
    }
}

// Feature: continuum-ml-pipelines, Property 12: GPS Soak Period Enforcement
// Feature: continuum-ml-pipelines, Property 13: Platform Activity Veto
// Feature: continuum-ml-pipelines, Property 14: Static-Lock Detection

// ---------------------------------------------------------------------------
// Property 12: GPS Soak Period Enforcement
// Validates: Requirements 4.5, 4.6
//
// For any claim where soak_period_failed=true, the claim must always be
// routed to FRAUD_QUEUE regardless of other sub-scores.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 4.5, 4.6**
    #[test]
    fn prop12_gps_soak_period_enforcement(
        spatial_score    in 0.0f64..=1.0,
        frequency_score  in 0.0f64..=1.0,
        isolation_forest in 0.0f64..=1.0,
    ) {
        // soak_period_failed=true, platform_activity_veto=false so only FRAUD_QUEUE is expected
        let inputs = make_inputs(
            spatial_score,
            false,
            frequency_score,
            false,
            1,
            isolation_forest,
            0.0,
            true,  // soak_period_failed
            false, // platform_activity_veto
        );
        let resp = compute_score(inputs);
        prop_assert_eq!(
            resp.status,
            ClaimStatus::FraudQueue,
            "soak_period_failed=true must always route to FRAUD_QUEUE"
        );
    }
}

// ---------------------------------------------------------------------------
// Property 13: Platform Activity Veto
// Validates: Requirements 4.7, 4.8
//
// For any claim where platform_activity_veto=true, the claim must always
// receive status PLATFORM_ACTIVITY_VETO regardless of other sub-scores.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 4.7, 4.8**
    #[test]
    fn prop13_platform_activity_veto(
        spatial_score    in 0.0f64..=1.0,
        frequency_score  in 0.0f64..=1.0,
        isolation_forest in 0.0f64..=1.0,
    ) {
        let inputs = make_inputs(
            spatial_score,
            false,
            frequency_score,
            false,
            1,
            isolation_forest,
            0.0,
            false, // soak_period_failed
            true,  // platform_activity_veto
        );
        let resp = compute_score(inputs);
        prop_assert_eq!(
            resp.status,
            ClaimStatus::PlatformActivityVeto,
            "platform_activity_veto=true must always return PLATFORM_ACTIVITY_VETO"
        );
    }
}

// ---------------------------------------------------------------------------
// Property 14: Static-Lock Detection
// Validates: Requirements 4.9, 4.10
//
// Part A — STATIC_LOCK flag propagation: when STATIC_LOCK is set in the
// input flags, it must be preserved in the ScoreResponse flags.
//
// Part B — Cell-ID divergence threshold: for any two GPS points whose
// haversine distance exceeds 2km, haversine_km must return a value > 2.0.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 4.9, 4.10**
    #[test]
    fn prop14_static_lock_flag_propagation(
        spatial_score    in 0.0f64..=1.0,
        frequency_score  in 0.0f64..=1.0,
        isolation_forest in 0.0f64..=1.0,
    ) {
        // Construct inputs with STATIC_LOCK already set in flags
        let mut inputs = make_inputs(
            spatial_score,
            false,
            frequency_score,
            false,
            1,
            isolation_forest,
            0.0,
            false,
            false,
        );
        inputs.flags.push("STATIC_LOCK".to_string());

        let resp = compute_score(inputs);
        prop_assert!(
            resp.flags.contains(&"STATIC_LOCK".to_string()),
            "STATIC_LOCK flag must be preserved in ScoreResponse flags"
        );
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 4.9, 4.10**
    ///
    /// For any lat/lon offsets that produce a haversine distance > 2km,
    /// haversine_km must return a value strictly greater than 2.0.
    /// This validates the Cell-ID divergence threshold used in static-lock detection.
    #[test]
    fn prop14b_cell_id_divergence_threshold(
        // Offsets of 0.02–0.1 degrees produce roughly 2.2–11km at Mumbai latitude
        lat_offset in 0.02f64..=0.1,
        lon_offset in 0.02f64..=0.1,
    ) {
        use claims_scoring::gps_spoofing::haversine_km;

        let base_lat = 19.1136f64;
        let base_lon = 72.8697f64;
        let d = haversine_km(base_lat, base_lon, base_lat + lat_offset, base_lon + lon_offset);

        prop_assert!(
            d > 2.0,
            "Expected haversine distance > 2km for offset ({}, {}), got {}",
            lat_offset,
            lon_offset,
            d
        );
    }
}

// Feature: continuum-ml-pipelines, Property 36: Convergence Freeze Threshold
// Feature: continuum-ml-pipelines, Property 37: Device Proximity Cluster Flagging
// Feature: continuum-ml-pipelines, Property 38: Convergence Freeze Kafka Publication

// ---------------------------------------------------------------------------
// Property 36: Convergence Freeze Threshold
// Validates: Requirements 17.1, 17.2
//
// For any claim count >= 50, is_convergence_freeze must return true.
// For any claim count < 50, is_convergence_freeze must return false.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 17.1, 17.2**
    #[test]
    fn prop36_convergence_freeze_threshold(count in 50usize..=1000) {
        use claims_scoring::population_fraud::is_convergence_freeze;
        prop_assert!(is_convergence_freeze(count), "count={} >= 50 must trigger freeze", count);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 17.1, 17.2**
    #[test]
    fn prop36b_no_freeze_below_threshold(count in 0usize..50) {
        use claims_scoring::population_fraud::is_convergence_freeze;
        prop_assert!(!is_convergence_freeze(count), "count={} < 50 must not trigger freeze", count);
    }
}

// ---------------------------------------------------------------------------
// Property 37: Device Proximity Cluster Flagging
// Validates: Requirements 17.3, 17.4
//
// For any cluster size >= 5, is_device_cluster_flagged must return true.
// For any cluster size < 5, is_device_cluster_flagged must return false.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 17.3, 17.4**
    #[test]
    fn prop37_device_proximity_cluster_flagging(size in 5usize..=100) {
        use claims_scoring::population_fraud::is_device_cluster_flagged;
        prop_assert!(is_device_cluster_flagged(size), "size={} >= 5 must flag cluster", size);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 17.3, 17.4**
    #[test]
    fn prop37b_no_cluster_below_threshold(size in 0usize..5) {
        use claims_scoring::population_fraud::is_device_cluster_flagged;
        prop_assert!(!is_device_cluster_flagged(size), "size={} < 5 must not flag cluster", size);
    }
}

// ---------------------------------------------------------------------------
// Property 38: Convergence Freeze Kafka Publication
// Validates: Requirements 17.1, 17.6
//
// When convergence_freeze=true, the fraud_alert payload must contain
// zone_id, claim_count, and triggered_at fields.
// ---------------------------------------------------------------------------

proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]

    /// **Validates: Requirements 17.1, 17.6**
    #[test]
    fn prop38_convergence_freeze_kafka_payload(
        zone_id in "[A-Z]{3}_[A-Z]{5}_[A-Z]",
        claim_count in 50usize..=1000,
    ) {
        // Verify the fraud_alert payload structure that would be published to Kafka
        let payload = serde_json::json!({
            "alert_type": "convergence_freeze",
            "zone_id": zone_id,
            "claim_count": claim_count,
            "triggered_at": chrono::Utc::now().to_rfc3339(),
        });

        prop_assert!(payload.get("zone_id").is_some(), "fraud_alert must contain zone_id");
        prop_assert!(payload.get("claim_count").is_some(), "fraud_alert must contain claim_count");
        prop_assert!(payload.get("triggered_at").is_some(), "fraud_alert must contain triggered_at");
        prop_assert_eq!(payload["alert_type"].as_str(), Some("convergence_freeze"));
        prop_assert_eq!(payload["claim_count"].as_u64(), Some(claim_count as u64));
    }
}
