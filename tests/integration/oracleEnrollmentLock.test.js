// Integration tests — Oracle Enrollment Lock (adverse selection control)
// Invariants covered:
//   V31 — zone_enrollment_locks active row blocks policy creation (HTTP 423 in code, 409 in spec)
//   C9  — Enrollment blocked when zone_enrollment_lock active
//
// Note: policies.js returns HTTP 423 (Locked) when a lock is active.
// V31 in SPEC.md states 409; actual code uses the more semantically correct 423.
//
// These tests exercise the DB-layer invariant directly (same query the app runs).
// Requires PostgreSQL (TEST_PG_DSN). Skips gracefully if DB unreachable.

'use strict';

const { setup, teardown, PG_DSN } = require('./setup');
const { Client } = require('pg');
const { v4: uuidv4 } = require('uuid');

let pgClient;
let dbAvailable = false;

const ZONE_ID = 'MUM_ANDHERI_W'; // seeded in seed.sql

beforeAll(async () => {
  try {
    await setup();
    pgClient = new Client({ connectionString: PG_DSN });
    await pgClient.connect();
    dbAvailable = true;
  } catch (err) {
    console.warn('[oracleEnrollmentLock] DB unavailable — skipping integration tests:', err.message);
  }
}, 60000);

afterAll(async () => {
  if (pgClient) await pgClient.end().catch(() => {});
  if (dbAvailable) await teardown().catch(() => {});
});

function skipIfNoDb() {
  return !dbAvailable;
}

// Helper that runs the exact query policies.js uses to check for an active lock
async function queryActiveLock(zoneId) {
  return pgClient.query(
    `SELECT zone_id, event_type, expires_at
     FROM zone_enrollment_locks
     WHERE zone_id = $1 AND expires_at > NOW()
     LIMIT 1`,
    [zoneId]
  );
}

// ---------------------------------------------------------------------------
// V31 / C9 — active lock blocks enrollment
// ---------------------------------------------------------------------------

describe('V31/C9 — zone enrollment lock blocks policy creation', () => {
  beforeEach(async () => {
    if (!dbAvailable) return;
    // Clean up any stray locks for the test zone
    await pgClient.query(
      `DELETE FROM zone_enrollment_locks WHERE zone_id = $1`,
      [ZONE_ID]
    );
  });

  afterEach(async () => {
    if (!dbAvailable) return;
    await pgClient.query(
      `DELETE FROM zone_enrollment_locks WHERE zone_id = $1`,
      [ZONE_ID]
    );
  });

  test('active lock row is visible via the eligibility query', async () => {
    if (skipIfNoDb()) return;

    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000); // +48h

    await pgClient.query(
      `INSERT INTO zone_enrollment_locks
         (zone_id, event_type, locked_at, expires_at, forecast_data)
       VALUES ($1, $2, NOW(), $3, $4)
       ON CONFLICT (zone_id, event_type) DO UPDATE
         SET expires_at = EXCLUDED.expires_at, locked_at = NOW()`,
      [ZONE_ID, 'adverse_selection_lock', expiresAt.toISOString(), JSON.stringify({ severity: 'red', probability: 0.9 })]
    );

    const result = await queryActiveLock(ZONE_ID);

    // Application code: if rows.length > 0 → enrollment blocked
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].zone_id).toBe(ZONE_ID);
    expect(result.rows[0].event_type).toBe('adverse_selection_lock');
    expect(new Date(result.rows[0].expires_at).getTime()).toBeGreaterThan(Date.now());
  });

  test('no lock inserted → eligibility query returns empty (enrollment allowed)', async () => {
    if (skipIfNoDb()) return;

    const result = await queryActiveLock(ZONE_ID);

    // No rows → core_backend allows enrollment
    expect(result.rows).toHaveLength(0);
  });

  test('C9: expired lock is NOT returned by the eligibility query', async () => {
    if (skipIfNoDb()) return;

    // Insert a lock that already expired
    const expiresAt = new Date(Date.now() - 1000); // 1 second in the past

    await pgClient.query(
      `INSERT INTO zone_enrollment_locks
         (zone_id, event_type, locked_at, expires_at)
       VALUES ($1, $2, NOW() - INTERVAL '49 hours', $3)
       ON CONFLICT (zone_id, event_type) DO UPDATE
         SET expires_at = EXCLUDED.expires_at`,
      [ZONE_ID, 'adverse_selection_lock', expiresAt.toISOString()]
    );

    const result = await queryActiveLock(ZONE_ID);

    // Expired lock → rows = 0 → enrollment proceeds
    expect(result.rows).toHaveLength(0);
  });

  test('lock for one zone does not block another zone', async () => {
    if (skipIfNoDb()) return;

    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000);

    await pgClient.query(
      `INSERT INTO zone_enrollment_locks
         (zone_id, event_type, locked_at, expires_at)
       VALUES ($1, $2, NOW(), $3)
       ON CONFLICT (zone_id, event_type) DO UPDATE
         SET expires_at = EXCLUDED.expires_at`,
      [ZONE_ID, 'adverse_selection_lock', expiresAt.toISOString()]
    );

    // Check a DIFFERENT zone — must not be blocked
    const result = await queryActiveLock('MUM_BANDRA_W');
    expect(result.rows).toHaveLength(0);
  });

  test('V31: lock expiry unlocks enrollment (simulate lock expiry by updating expires_at)', async () => {
    if (skipIfNoDb()) return;

    // Insert active lock
    const expiresAt = new Date(Date.now() + 48 * 60 * 60 * 1000);
    await pgClient.query(
      `INSERT INTO zone_enrollment_locks
         (zone_id, event_type, locked_at, expires_at)
       VALUES ($1, $2, NOW(), $3)
       ON CONFLICT (zone_id, event_type) DO UPDATE
         SET expires_at = EXCLUDED.expires_at`,
      [ZONE_ID, 'adverse_selection_lock', expiresAt.toISOString()]
    );

    // Verify locked
    const lockedResult = await queryActiveLock(ZONE_ID);
    expect(lockedResult.rows).toHaveLength(1);

    // Simulate expiry (set expires_at to past)
    await pgClient.query(
      `UPDATE zone_enrollment_locks
       SET expires_at = NOW() - INTERVAL '1 second'
       WHERE zone_id = $1`,
      [ZONE_ID]
    );

    // Verify unlocked
    const unlockedResult = await queryActiveLock(ZONE_ID);
    expect(unlockedResult.rows).toHaveLength(0);
  });
});
