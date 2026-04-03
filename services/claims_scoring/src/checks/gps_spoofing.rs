// Feature: continuum-ml-pipelines
// GPS Spoofing Prevention Checks
// Requirements: 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10

use crate::models::GpsPoint;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use tracing::warn;
use uuid::Uuid;

/// Result of all GPS spoofing prevention checks
#[derive(Debug, Clone)]
pub struct GpsSpoofingResult {
    /// 0.3 if LOCATION_MISMATCH (Cell-ID vs GPS divergence > 2km), else 0.0
    pub spatial_penalty: f64,
    /// True if the 45-minute soak period requirement was not met
    pub soak_period_failed: bool,
    /// True if the platform API reports completed orders during the disruption window
    pub platform_activity_veto: bool,
    /// True if all GPS samples are identical (velocity = 0 for full window)
    pub static_lock_detected: bool,
    /// Accumulated flags, e.g. ["LOCATION_MISMATCH", "STATIC_LOCK", "PLATFORM_ACTIVITY_VETO"]
    pub flags: Vec<String>,
}

/// Runs all four GPS spoofing prevention checks and returns a consolidated result.
///
/// Checks performed:
/// 1. Cell-ID vs GPS divergence (Req 4.3, 4.4)
/// 2. 45-minute soak period (Req 4.5, 4.6)
/// 3. Platform API order cross-reference (Req 4.7, 4.8)
/// 4. Static-lock detection (Req 4.9, 4.10)
pub async fn run_gps_spoofing_checks(
    pool: &PgPool,
    claim_id: Uuid,
    worker_id: Uuid,
    gps_coordinates: [f64; 2],
    cell_id_coordinates: Option<[f64; 2]>,
    gps_history: Option<&[GpsPoint]>,
    event_timestamp: DateTime<Utc>,
    zone_id: &str,
) -> GpsSpoofingResult {
    let mut flags: Vec<String> = Vec::new();
    let mut spatial_penalty = 0.0f64;
    let mut soak_period_failed = false;
    let mut platform_activity_veto = false;
    let mut static_lock_detected = false;

    // ── Check 1: Cell-ID vs GPS divergence (Req 4.3, 4.4) ──
    if let Some(cell_coords) = cell_id_coordinates {
        let divergence_km = haversine_km(
            gps_coordinates[0],
            gps_coordinates[1],
            cell_coords[0],
            cell_coords[1],
        );
        if divergence_km > 2.0 {
            warn!(
                %claim_id,
                divergence_km,
                "Cell-ID vs GPS divergence exceeds 2km — LOCATION_MISMATCH"
            );
            flags.push("LOCATION_MISMATCH".to_string());
            spatial_penalty = 0.3;
        }
    }

    // ── Check 2: 45-minute soak period (Req 4.5, 4.6) ──
    if let Some(history) = gps_history {
        if !check_soak_period(history, &event_timestamp, zone_id, pool).await {
            warn!(%claim_id, "Soak period not met — routing to FRAUD_QUEUE");
            soak_period_failed = true;
        }
    }

    // ── Check 3: Platform API order cross-reference (Req 4.7, 4.8) ──
    if check_platform_orders(claim_id, worker_id, event_timestamp).await {
        warn!(%claim_id, "Platform API reports orders during disruption window — PLATFORM_ACTIVITY_VETO");
        platform_activity_veto = true;
        flags.push("PLATFORM_ACTIVITY_VETO".to_string());
    }

    // ── Check 4: Static-lock detection (Req 4.9, 4.10) ──
    if let Some(history) = gps_history {
        if is_static_lock(history) {
            warn!(%claim_id, "Static-lock detected — flagging for elevated review");
            static_lock_detected = true;
            flags.push("STATIC_LOCK".to_string());
        }
    }

    GpsSpoofingResult {
        spatial_penalty,
        soak_period_failed,
        platform_activity_veto,
        static_lock_detected,
        flags,
    }
}

/// Checks whether the worker's GPS history shows continuous presence within the zone
/// for at least 45 minutes before the event_timestamp.
///
/// Returns true if the soak period is met, false otherwise.
async fn check_soak_period(
    gps_history: &[GpsPoint],
    event_timestamp: &DateTime<Utc>,
    zone_id: &str,
    pool: &PgPool,
) -> bool {
    let soak_start = *event_timestamp - chrono::Duration::minutes(45);

    // Filter history points within the soak window
    let window_points: Vec<_> = gps_history
        .iter()
        .filter(|p| p.ts >= soak_start && p.ts <= *event_timestamp)
        .collect();

    if window_points.is_empty() {
        warn!("No GPS history points in 45-minute soak window");
        return false;
    }

    // Check that the earliest point covers the full 45-minute window
    let earliest = window_points.iter().map(|p| p.ts).min().unwrap();
    let coverage_minutes = (*event_timestamp - earliest).num_minutes();

    if coverage_minutes < 45 {
        warn!(
            coverage_minutes,
            "GPS history does not cover full 45-minute soak period"
        );
        return false;
    }

    // Verify all points are within the zone polygon using PostGIS ST_Contains
    for point in &window_points {
        let in_zone: Option<bool> = sqlx::query_scalar(
            r#"
            SELECT ST_Contains(z.polygon, ST_SetSRID(ST_Point($1, $2), 4326))
            FROM zones z
            WHERE z.zone_id = $3
            "#,
        )
        .bind(point.lon)
        .bind(point.lat)
        .bind(zone_id)
        .fetch_optional(pool)
        .await
        .unwrap_or(None)
        .flatten();

        if !in_zone.unwrap_or(false) {
            warn!(
                lat = point.lat,
                lon = point.lon,
                "GPS history point outside zone during soak period"
            );
            return false;
        }
    }

    true
}

/// Calls the platform API (Swiggy/Zomato) to check if the worker completed any orders
/// during the disruption window (event_timestamp ± 2 hours).
///
/// Returns true if orders were found (veto the claim).
/// On HTTP error or timeout: logs a warning and returns false (don't veto on API failure).
async fn check_platform_orders(
    claim_id: Uuid,
    worker_id: Uuid,
    event_timestamp: DateTime<Utc>,
) -> bool {
    let platform_api_url = std::env::var("PLATFORM_API_URL")
        .unwrap_or_else(|_| "http://localhost:9000".to_string());

    let event_start = event_timestamp - chrono::Duration::hours(2);
    let event_end = event_timestamp + chrono::Duration::hours(2);

    let url = format!(
        "{}/workers/{}/orders?from={}&to={}",
        platform_api_url,
        worker_id,
        event_start.to_rfc3339(),
        event_end.to_rfc3339(),
    );

    let client = match reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            warn!(%claim_id, error = %e, "Failed to build HTTP client for platform API check — skipping");
            return false;
        }
    };

    match client.get(&url).send().await {
        Ok(resp) => {
            if !resp.status().is_success() {
                warn!(
                    %claim_id,
                    status = %resp.status(),
                    "Platform API returned non-success status — skipping veto check"
                );
                return false;
            }
            match resp.json::<serde_json::Value>().await {
                Ok(body) => {
                    let orders = body
                        .get("orders")
                        .and_then(|v| v.as_array())
                        .map(|arr| arr.len())
                        .unwrap_or(0);
                    orders > 0
                }
                Err(e) => {
                    warn!(%claim_id, error = %e, "Failed to parse platform API response — skipping veto check");
                    false
                }
            }
        }
        Err(e) => {
            warn!(%claim_id, error = %e, "Platform API request failed — skipping veto check");
            false
        }
    }
}

/// Detects static-lock fraud: all GPS samples have identical coordinates (velocity = 0).
/// Requires at least 3 points.
fn is_static_lock(gps_history: &[GpsPoint]) -> bool {
    if gps_history.len() < 3 {
        return false;
    }
    let first = &gps_history[0];
    gps_history
        .iter()
        .all(|p| (p.lat - first.lat).abs() < 1e-7 && (p.lon - first.lon).abs() < 1e-7)
}

/// Haversine distance in kilometres between two GPS coordinates.
pub fn haversine_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    const EARTH_RADIUS_KM: f64 = 6371.0;

    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();

    let a = (dlat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (dlon / 2.0).sin().powi(2);

    let c = 2.0 * a.sqrt().asin();
    EARTH_RADIUS_KM * c
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn test_haversine_same_point() {
        let d = haversine_km(19.1136, 72.8697, 19.1136, 72.8697);
        assert!(d < 1e-9);
    }

    #[test]
    fn test_haversine_known_distance() {
        // Mumbai Andheri to Bandra: roughly ~7km
        let d = haversine_km(19.1136, 72.8697, 19.0544, 72.8405);
        assert!(d > 5.0 && d < 10.0, "Expected ~7km, got {d}");
    }

    #[test]
    fn test_haversine_exceeds_2km() {
        // Points ~3km apart should exceed the 2km threshold
        let d = haversine_km(19.1136, 72.8697, 19.1400, 72.8900);
        assert!(d > 2.0, "Expected > 2km, got {d}");
    }

    #[test]
    fn test_haversine_within_2km() {
        // Points ~0.5km apart should be within the 2km threshold
        let d = haversine_km(19.1136, 72.8697, 19.1160, 72.8720);
        assert!(d < 2.0, "Expected < 2km, got {d}");
    }

    #[test]
    fn test_static_lock_detected() {
        let ts = Utc::now();
        let history = vec![
            GpsPoint { lat: 19.1136, lon: 72.8697, ts },
            GpsPoint { lat: 19.1136, lon: 72.8697, ts },
            GpsPoint { lat: 19.1136, lon: 72.8697, ts },
        ];
        assert!(is_static_lock(&history));
    }

    #[test]
    fn test_static_lock_not_detected_with_movement() {
        let ts = Utc::now();
        let history = vec![
            GpsPoint { lat: 19.1136, lon: 72.8697, ts },
            GpsPoint { lat: 19.1140, lon: 72.8700, ts },
            GpsPoint { lat: 19.1145, lon: 72.8705, ts },
        ];
        assert!(!is_static_lock(&history));
    }

    #[test]
    fn test_static_lock_requires_min_3_points() {
        let ts = Utc::now();
        let history = vec![
            GpsPoint { lat: 19.1136, lon: 72.8697, ts },
            GpsPoint { lat: 19.1136, lon: 72.8697, ts },
        ];
        assert!(!is_static_lock(&history));
    }

    #[test]
    fn test_static_lock_not_detected_with_tiny_movement() {
        // Movement larger than 1e-7 tolerance should not be static lock
        let ts = Utc::now();
        let history = vec![
            GpsPoint { lat: 19.1136000, lon: 72.8697000, ts },
            GpsPoint { lat: 19.1136002, lon: 72.8697000, ts },
            GpsPoint { lat: 19.1136000, lon: 72.8697000, ts },
        ];
        assert!(!is_static_lock(&history));
    }
}
