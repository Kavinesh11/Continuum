'use strict';

const db = require('../../db');

const SEVERITY_TTL_HOURS = {
  red: 72,
  orange: 48,
  yellow: 24,
};
const DEFAULT_TTL_HOURS = 72;

/**
 * Handle an `adverse_selection_lock` (enrollment_lock) Kafka event.
 * Upserts zone_enrollment_locks with TTL based on forecast severity.
 */
async function handleEnrollmentLock(event) {
  const { event_id, zone_id, event_type, forecast_data, locked_at, expires_at } = event;

  const severity = (forecast_data && forecast_data.severity) || null;
  const ttlHours = severity ? (SEVERITY_TTL_HOURS[severity] || DEFAULT_TTL_HOURS) : DEFAULT_TTL_HOURS;

  const computedExpiry = expires_at || new Date(
    new Date(locked_at).getTime() + ttlHours * 3600 * 1000
  ).toISOString();

  await db.query(
    `INSERT INTO zone_enrollment_locks (zone_id, event_type, locked_at, expires_at, forecast_data)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (zone_id, event_type) DO UPDATE SET
       locked_at = EXCLUDED.locked_at,
       expires_at = EXCLUDED.expires_at,
       forecast_data = EXCLUDED.forecast_data`,
    [zone_id, event_type, locked_at, computedExpiry, JSON.stringify(forecast_data || {})]
  );

  console.log(
    `[enrollment-lock] Zone ${zone_id} locked for ${event_type} until ${computedExpiry} (severity: ${severity || 'default'})`
  );

  return { zone_id, event_type, expires_at: computedExpiry, severity };
}

module.exports = { handleEnrollmentLock, SEVERITY_TTL_HOURS };
