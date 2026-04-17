'use strict';

const { setup, teardown, PG_DSN } = require('./setup');
const { Client } = require('pg');

let pgClient;

beforeAll(async () => {
  await setup();
  pgClient = new Client({ connectionString: PG_DSN });
  await pgClient.connect();
}, 60000);

afterAll(async () => {
  if (pgClient) await pgClient.end();
  await teardown().catch(() => {});
});

describe('trigger-to-payout integration', () => {
  test('seed data: zones exist with WGS84 polygons', async () => {
    const result = await pgClient.query('SELECT zone_id, city FROM zones ORDER BY zone_id');
    expect(result.rows.length).toBeGreaterThanOrEqual(3);
    expect(result.rows.map(r => r.zone_id)).toContain('MUM_ANDHERI_W');
  });

  test('seed data: workers exist with identity columns', async () => {
    const result = await pgClient.query(
      'SELECT worker_id, aadhaar_hash, device_fingerprint FROM workers'
    );
    expect(result.rows.length).toBeGreaterThanOrEqual(2);
    expect(result.rows[0].aadhaar_hash).toBeTruthy();
  });

  test('seed data: weather_events hypertable has ≥24 months of data', async () => {
    const result = await pgClient.query(
      `SELECT COUNT(*) AS cnt FROM weather_events
       WHERE recorded_at > NOW() - INTERVAL '24 months'`
    );
    expect(parseInt(result.rows[0].cnt)).toBeGreaterThan(100);
  });

  test('zone_enrollment_locks table exists and accepts upserts', async () => {
    await pgClient.query(
      `INSERT INTO zone_enrollment_locks (zone_id, event_type, expires_at, forecast_data)
       VALUES ('MUM_ANDHERI_W', 'heavy_rainfall', NOW() + INTERVAL '48 hours', '{"severity":"red"}')
       ON CONFLICT (zone_id, event_type) DO UPDATE SET expires_at = EXCLUDED.expires_at`
    );
    const result = await pgClient.query(
      `SELECT * FROM zone_enrollment_locks WHERE zone_id = 'MUM_ANDHERI_W'`
    );
    expect(result.rows.length).toBe(1);
  });

  test('spatial query: ST_Contains returns true for point inside zone polygon', async () => {
    const result = await pgClient.query(
      `SELECT ST_Contains(polygon, ST_SetSRID(ST_Point(72.835, 19.135), 4326)) AS inside
       FROM zones WHERE zone_id = 'MUM_ANDHERI_W'`
    );
    expect(result.rows[0].inside).toBe(true);
  });
});
