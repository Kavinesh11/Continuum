use anyhow::Result;
use sqlx::PgPool;
use tracing::{error, info};

/// Result of the spatial zone check
#[derive(Debug, Clone)]
pub struct SpatialResult {
    /// Spatial sub-score: 1.0 within zone, 0.7 within 2km buffer, 0.0 otherwise
    pub score: f64,
    /// True if GPS is outside the zone polygon (zone mismatch)
    pub zone_mismatch: bool,
}

/// Checks whether the GPS coordinates fall within the claimed zone polygon.
///
/// Uses PostGIS:
///   - ST_Contains(zone_polygon, point) → score 1.0
///   - ST_DWithin(zone_polygon, point, 2000m) → score 0.7
///   - Otherwise → score 0.0, zone_mismatch = true
///
/// On DB error, returns a conservative score of 0.5 and logs the error.
pub async fn check_spatial(
    pool: &PgPool,
    zone_id: &str,
    lat: f64,
    lon: f64,
) -> Result<SpatialResult> {
    let result = run_spatial_query(pool, zone_id, lat, lon).await;

    match result {
        Ok(r) => Ok(r),
        Err(e) => {
            error!(
                error = %e,
                zone_id,
                lat,
                lon,
                "PostGIS spatial query failed — using conservative default score 0.5"
            );
            // Conservative default on DB error (treat as partial match)
            Ok(SpatialResult {
                score: 0.5,
                zone_mismatch: false,
            })
        }
    }
}

async fn run_spatial_query(pool: &PgPool, zone_id: &str, lat: f64, lon: f64) -> Result<SpatialResult> {
    #[derive(sqlx::FromRow)]
    struct SpatialRow {
        within_zone: Option<bool>,
        within_buffer: Option<bool>,
    }

    let row: Option<SpatialRow> = sqlx::query_as(
        r#"
        SELECT
            ST_Contains(z.polygon, ST_SetSRID(ST_Point($1, $2), 4326)) AS within_zone,
            ST_DWithin(
                z.polygon::geography,
                ST_SetSRID(ST_Point($1, $2), 4326)::geography,
                2000
            ) AS within_buffer
        FROM zones z
        WHERE z.zone_id = $3
        "#,
    )
    .bind(lon)
    .bind(lat)
    .bind(zone_id)
    .fetch_optional(pool)
    .await?;

    match row {
        None => {
            error!(zone_id, "Zone not found in PostGIS — treating as mismatch");
            Ok(SpatialResult {
                score: 0.0,
                zone_mismatch: true,
            })
        }
        Some(r) => {
            let within_zone = r.within_zone.unwrap_or(false);
            let within_buffer = r.within_buffer.unwrap_or(false);

            let (score, zone_mismatch) = if within_zone {
                info!(zone_id, lat, lon, "GPS within zone polygon");
                (1.0, false)
            } else if within_buffer {
                info!(zone_id, lat, lon, "GPS within 2km buffer of zone");
                (0.7, false)
            } else {
                info!(zone_id, lat, lon, "GPS outside zone and buffer — zone mismatch");
                (0.0, true)
            };

            Ok(SpatialResult {
                score,
                zone_mismatch,
            })
        }
    }
}
