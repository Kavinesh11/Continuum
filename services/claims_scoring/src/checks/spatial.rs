use anyhow::Result;
use sqlx::PgPool;
use tracing::{error, info};

/// Result of the spatial zone check
#[derive(Debug, Clone)]
pub struct SpatialResult {
    /// Spatial sub-score: 1.0 within zone, 0.7 within 2km buffer, 0.5 adjacency, 0.0 otherwise
    pub score: f64,
    /// True if GPS is outside the zone polygon (zone mismatch)
    pub zone_mismatch: bool,
    /// True if GPS falls in an adjacent (ST_Touches) zone — adjacency grace applies
    pub adjacency_grace: bool,
    /// The adjacent zone_id if adjacency_grace is true
    pub adjacent_zone_id: Option<String>,
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
            Ok(SpatialResult {
                score: 0.5,
                zone_mismatch: false,
                adjacency_grace: false,
                adjacent_zone_id: None,
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
                adjacency_grace: false,
                adjacent_zone_id: None,
            })
        }
        Some(r) => {
            let within_zone = r.within_zone.unwrap_or(false);
            let within_buffer = r.within_buffer.unwrap_or(false);

            if within_zone {
                info!(zone_id, lat, lon, "GPS within zone polygon");
                Ok(SpatialResult {
                    score: 1.0,
                    zone_mismatch: false,
                    adjacency_grace: false,
                    adjacent_zone_id: None,
                })
            } else if within_buffer {
                info!(zone_id, lat, lon, "GPS within 2km buffer of zone");
                Ok(SpatialResult {
                    score: 0.7,
                    zone_mismatch: false,
                    adjacency_grace: false,
                    adjacent_zone_id: None,
                })
            } else {
                // Check adjacency grace — is the worker in a neighboring zone?
                let adj = check_adjacency(pool, zone_id, lat, lon).await;
                match adj {
                    Some(adj_zone) => {
                        info!(zone_id, lat, lon, adjacent = %adj_zone, "GPS in adjacent zone — adjacency grace");
                        Ok(SpatialResult {
                            score: 0.5,
                            zone_mismatch: false,
                            adjacency_grace: true,
                            adjacent_zone_id: Some(adj_zone),
                        })
                    }
                    None => {
                        info!(zone_id, lat, lon, "GPS outside zone, buffer, and adjacency — zone mismatch");
                        Ok(SpatialResult {
                            score: 0.0,
                            zone_mismatch: true,
                            adjacency_grace: false,
                            adjacent_zone_id: None,
                        })
                    }
                }
            }
        }
    }
}

/// Check if the GPS point falls inside a zone that is adjacent (ST_Touches) to the claimed zone.
/// Returns the adjacent zone_id if found, None otherwise.
async fn check_adjacency(pool: &PgPool, zone_id: &str, lat: f64, lon: f64) -> Option<String> {
    let result: Option<(String,)> = sqlx::query_as(
        r#"
        SELECT neighbor.zone_id
        FROM zones neighbor
        JOIN zones claimed ON claimed.zone_id = $3
        WHERE ST_Touches(claimed.polygon, neighbor.polygon)
          AND neighbor.zone_id != $3
          AND ST_Contains(neighbor.polygon, ST_SetSRID(ST_Point($1, $2), 4326))
        LIMIT 1
        "#,
    )
    .bind(lon)
    .bind(lat)
    .bind(zone_id)
    .fetch_optional(pool)
    .await
    .ok()
    .flatten();

    result.map(|r| r.0)
}
