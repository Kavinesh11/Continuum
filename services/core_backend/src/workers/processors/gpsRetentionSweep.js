'use strict';

const db = require('../../db');

const GPS_RETENTION_DAYS = parseInt(process.env.GPS_RETENTION_DAYS || '60', 10);

/**
 * BullMQ repeatable job processor: hard-deletes GPS rows older than the retention window.
 * Runs daily; scheduled in workers/index.js.
 */
async function processGpsRetentionSweep(job) {
  const cutoff = new Date(Date.now() - GPS_RETENTION_DAYS * 24 * 60 * 60 * 1000);

  const gpsResult = await db.query(
    'DELETE FROM gps_activity WHERE recorded_at < $1',
    [cutoff]
  );

  const proximityResult = await db.query(
    'DELETE FROM device_proximity_log WHERE recorded_at < $1',
    [cutoff]
  );

  const summary = {
    gps_rows_deleted: gpsResult.rowCount || 0,
    proximity_rows_deleted: proximityResult.rowCount || 0,
    cutoff: cutoff.toISOString(),
    retention_days: GPS_RETENTION_DAYS,
  };

  console.log('[gps-retention-sweep]', summary);
  return summary;
}

module.exports = { processGpsRetentionSweep };
