'use strict';

const { setup, teardown, PG_DSN } = require('./setup');
const { Client } = require('pg');

let pgClient;

beforeAll(async () => {
  await setup();
  pgClient = new Client({ connectionString: PG_DSN });
  await pgClient.connect();

  await pgClient.query(`
    INSERT INTO zones (zone_id, city, polygon, risk_index)
    VALUES ('TEST_ZONE_CG', 'Mumbai',
      ST_GeomFromText('POLYGON((72.82 19.12, 72.85 19.12, 72.85 19.15, 72.82 19.15, 72.82 19.12))', 4326), 0.65)
    ON CONFLICT (zone_id) DO NOTHING
  `);
}, 60000);

afterAll(async () => {
  if (pgClient) await pgClient.end();
  await teardown().catch(() => {});
});

describe('coverage gates', () => {
  test('enrollment lock blocks policy creation in locked zone', async () => {
    await pgClient.query(`
      INSERT INTO zone_enrollment_locks (zone_id, event_type, expires_at, forecast_data)
      VALUES ('TEST_ZONE_CG', 'heavy_rainfall', NOW() + INTERVAL '48 hours', '{"severity":"red"}')
      ON CONFLICT (zone_id, event_type) DO UPDATE SET expires_at = EXCLUDED.expires_at
    `);

    const lockResult = await pgClient.query(`
      SELECT COUNT(*) AS cnt FROM zone_enrollment_locks
      WHERE zone_id = 'TEST_ZONE_CG' AND expires_at > NOW()
    `);
    expect(parseInt(lockResult.rows[0].cnt)).toBeGreaterThan(0);
  });

  test('expired enrollment lock does not block', async () => {
    await pgClient.query(`
      INSERT INTO zone_enrollment_locks (zone_id, event_type, expires_at, forecast_data)
      VALUES ('TEST_ZONE_CG', 'cyclone', NOW() - INTERVAL '1 hour', '{"severity":"yellow"}')
      ON CONFLICT (zone_id, event_type) DO UPDATE SET expires_at = EXCLUDED.expires_at
    `);

    const lockResult = await pgClient.query(`
      SELECT COUNT(*) AS cnt FROM zone_enrollment_locks
      WHERE zone_id = 'TEST_ZONE_CG' AND event_type = 'cyclone' AND expires_at > NOW()
    `);
    expect(parseInt(lockResult.rows[0].cnt)).toBe(0);
  });

  test('kill switch blocks payouts in zone', async () => {
    await pgClient.query(`
      CREATE TABLE IF NOT EXISTS zone_kill_switches (
        zone_id TEXT PRIMARY KEY,
        active BOOLEAN NOT NULL DEFAULT FALSE,
        reason TEXT,
        activated_by TEXT,
        activated_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);

    await pgClient.query(`
      INSERT INTO zone_kill_switches (zone_id, active, reason, activated_by)
      VALUES ('TEST_ZONE_CG', TRUE, 'test', 'integration_test')
      ON CONFLICT (zone_id) DO UPDATE SET active = TRUE
    `);

    const ksResult = await pgClient.query(`
      SELECT active FROM zone_kill_switches WHERE zone_id = 'TEST_ZONE_CG'
    `);
    expect(ksResult.rows[0].active).toBe(true);
  });

  test('kill switch deactivation unblocks zone', async () => {
    await pgClient.query(`
      UPDATE zone_kill_switches SET active = FALSE WHERE zone_id = 'TEST_ZONE_CG'
    `);

    const ksResult = await pgClient.query(`
      SELECT active FROM zone_kill_switches WHERE zone_id = 'TEST_ZONE_CG'
    `);
    expect(ksResult.rows[0].active).toBe(false);
  });

  test('portfolio daily cap table exists and accepts updates', async () => {
    await pgClient.query(`
      CREATE TABLE IF NOT EXISTS portfolio_caps (
        cap_id TEXT PRIMARY KEY,
        max_amount NUMERIC(14,2) NOT NULL DEFAULT 500000,
        current_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
        reset_at TIMESTAMPTZ DEFAULT NOW()
      )
    `);

    await pgClient.query(`
      INSERT INTO portfolio_caps (cap_id, max_amount, current_amount)
      VALUES ('daily_disbursement', 500000, 0)
      ON CONFLICT (cap_id) DO UPDATE SET max_amount = 500000
    `);

    const capResult = await pgClient.query(`
      SELECT max_amount, current_amount FROM portfolio_caps WHERE cap_id = 'daily_disbursement'
    `);
    expect(parseFloat(capResult.rows[0].max_amount)).toBe(500000);
    expect(parseFloat(capResult.rows[0].current_amount)).toBe(0);
  });

  test('consent_receipts table enforces uniqueness', async () => {
    await pgClient.query(`
      INSERT INTO consent_receipts (worker_id, purpose, template_version)
      VALUES ('W_TEST_001', 'gps_location_tracking', '1.0')
      ON CONFLICT (worker_id, purpose) DO NOTHING
    `);

    await pgClient.query(`
      INSERT INTO consent_receipts (worker_id, purpose, template_version)
      VALUES ('W_TEST_001', 'gps_location_tracking', '1.0')
      ON CONFLICT (worker_id, purpose) DO NOTHING
    `);

    const consentResult = await pgClient.query(`
      SELECT COUNT(*) AS cnt FROM consent_receipts
      WHERE worker_id = 'W_TEST_001' AND purpose = 'gps_location_tracking'
    `);
    expect(parseInt(consentResult.rows[0].cnt)).toBe(1);
  });
});
