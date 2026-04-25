// Feature: continuum-ml-pipelines
// Unit tests for policy management endpoints
// Requirements: 6.1, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10

'use strict';

process.env.JWT_SECRET = 'test-secret-key-for-policy-tests';
process.env.DB_HOST = 'localhost';

const request = require('supertest');
const { signToken } = require('../src/utils/jwt');

// ─── Mock DB ──────────────────────────────────────────────────────────────────
// db.connect() is used by policies.js for transactions (BEGIN/COMMIT).
// The client mock uses a separate jest.fn() so transaction queries don't
// interfere with the per-test mockResolvedValueOnce queue on db.query.
jest.mock('../src/db', () => {
  const mockQuery = jest.fn();
  const mockClientQuery = jest.fn().mockResolvedValue({ rows: [] });
  const mockRelease = jest.fn();
  const mockConnect = jest.fn().mockResolvedValue({
    query: mockClientQuery,
    release: mockRelease,
  });
  return { query: mockQuery, connect: mockConnect };
});

// ─── Mock Kafka ───────────────────────────────────────────────────────────────
jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));

const db = require('../src/db');
const kafka = require('../src/services/kafka');
const app = require('../src/app');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function workerToken(workerId = 'worker-123', platform = 'swiggy', tier = 'silver') {
  return signToken({ worker_id: workerId, role: 'worker', platform, tier });
}

function adminToken() {
  return signToken({ worker_id: 'admin-1', role: 'admin' });
}

const ACTIVATION_DELAY_MS = 72 * 60 * 60 * 1000;
const BILLING_CYCLE_MS = 7 * 24 * 60 * 60 * 1000;
const TIER_UPGRADE_DELAY_MS = 5 * 24 * 60 * 60 * 1000;

// ─── POST /policies ───────────────────────────────────────────────────────────

describe('POST /policies', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('creates policy with 72-hour activation delay and returns 201', async () => {
    db.query.mockResolvedValueOnce({ rows: [] }); // zone lock check

    const before = Date.now();
    const res = await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({
        worker_id: 'worker-123',
        tier: 'silver',
        zone_id: 'MUM_ANDHERI_W',
        coverage_cap: 5000,
        weekly_premium: 149,
        aadhaar_hash: 'aadh_test_123',
        device_fingerprint: 'fp_test_456',
      });
    const after = Date.now();

    expect(res.status).toBe(201);
    expect(res.body.policy_id).toBeDefined();
    expect(res.body.worker_id).toBe('worker-123');
    expect(res.body.tier).toBe('silver');
    expect(res.body.status).toBe('pending');

    // Verify 72-hour activation delay (Requirement 6.5)
    const effectiveDate = new Date(res.body.effective_date).getTime();
    const claimEligibleFrom = new Date(res.body.claim_eligible_from).getTime();
    const delay = claimEligibleFrom - effectiveDate;
    expect(delay).toBeGreaterThanOrEqual(ACTIVATION_DELAY_MS - 1000); // allow 1s tolerance
    expect(delay).toBeLessThanOrEqual(ACTIVATION_DELAY_MS + 1000);

    // Verify billing cycle is 7 days
    const billingStart = new Date(res.body.billing_cycle_start).getTime();
    const billingEnd = new Date(res.body.billing_cycle_end).getTime();
    expect(billingEnd - billingStart).toBeGreaterThanOrEqual(BILLING_CYCLE_MS - 1000);
    expect(billingEnd - billingStart).toBeLessThanOrEqual(BILLING_CYCLE_MS + 1000);
  });

  test('publishes worker_onboarding and policy_lifecycle events to Kafka', async () => {
    db.query.mockResolvedValueOnce({ rows: [] }); // zone lock check

    await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({
        worker_id: 'worker-123',
        tier: 'gold',
        zone_id: 'MUM_ANDHERI_W',
        coverage_cap: 10000,
        weekly_premium: 299,
        aadhaar_hash: 'aadh_test_abc',
        device_fingerprint: 'fp_test_def',
      });

    // Kafka should have been called for worker_onboarding and policy_lifecycle
    const calls = kafka.publishEvent.mock.calls;
    const topics = calls.map(c => c[0]);
    expect(topics).toContain('worker_onboarding');
    expect(topics).toContain('policy_lifecycle');

    const onboardingCall = calls.find(c => c[0] === 'worker_onboarding');
    expect(onboardingCall[1].worker_id).toBe('worker-123');
    expect(onboardingCall[1].tier).toBe('gold');
    expect(onboardingCall[1].zone_id).toBe('MUM_ANDHERI_W');
  });

  test('returns 400 when required fields are missing', async () => {
    const res = await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ worker_id: 'worker-123', tier: 'silver' }); // missing zone_id, coverage_cap, weekly_premium

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('missing_fields');
  });

  test('returns 400 for invalid tier', async () => {
    const res = await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({
        worker_id: 'worker-123',
        tier: 'diamond', // invalid
        zone_id: 'MUM_ANDHERI_W',
        coverage_cap: 5000,
        weekly_premium: 149,
        aadhaar_hash: 'aadh_test_123',
        device_fingerprint: 'fp_test_456',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_tier');
  });

  test('returns 403 when worker_id in body does not match JWT', async () => {
    const res = await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({
        worker_id: 'different-worker',
        tier: 'silver',
        zone_id: 'MUM_ANDHERI_W',
        coverage_cap: 5000,
        weekly_premium: 149,
        aadhaar_hash: 'aadh_test_123',
        device_fingerprint: 'fp_test_456',
      });

    expect(res.status).toBe(403);
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/policies')
      .send({
        worker_id: 'worker-123',
        tier: 'silver',
        zone_id: 'MUM_ANDHERI_W',
        coverage_cap: 5000,
        weekly_premium: 149,
      });

    expect(res.status).toBe(401);
  });

  test('continues even if Kafka publish fails (non-fatal)', async () => {
    db.query.mockResolvedValueOnce({ rows: [] }); // zone lock check
    kafka.publishEvent.mockRejectedValue(new Error('Kafka unavailable'));

    const res = await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({
        worker_id: 'worker-123',
        tier: 'silver',
        zone_id: 'MUM_ANDHERI_W',
        coverage_cap: 5000,
        weekly_premium: 149,
        aadhaar_hash: 'aadh_test_123',
        device_fingerprint: 'fp_test_456',
      });

    // Should still succeed despite Kafka failure
    expect(res.status).toBe(201);
  });
});

// ─── GET /policies/:id ────────────────────────────────────────────────────────

describe('GET /policies/:id', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockPolicy = {
    policy_id: 'policy-abc',
    worker_id: 'worker-123',
    tier: 'silver',
    coverage_cap: '5000.00',
    weekly_premium: '149.00',
    effective_date: new Date('2024-01-01T00:00:00Z'),
    claim_eligible_from: new Date('2024-01-04T00:00:00Z'),
    status: 'active',
    billing_cycle_start: new Date('2024-01-01T00:00:00Z'),
    billing_cycle_end: new Date('2024-01-08T00:00:00Z'),
    cancelled_at: null,
  };

  test('returns policy for the owning worker', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockPolicy] });

    const res = await request(app)
      .get('/policies/policy-abc')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);
    expect(res.body.policy_id).toBe('policy-abc');
    expect(res.body.worker_id).toBe('worker-123');
    expect(res.body.tier).toBe('silver');
    expect(res.body.status).toBe('active');
  });

  test('returns 404 when policy does not exist', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .get('/policies/nonexistent-id')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('not_found');
  });

  test('returns 403 when worker tries to access another worker\'s policy', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockPolicy] }); // policy belongs to worker-123

    const res = await request(app)
      .get('/policies/policy-abc')
      .set('Authorization', `Bearer ${workerToken('different-worker')}`); // different worker

    expect(res.status).toBe(403);
  });

  test('admin can access any policy', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockPolicy] });

    const res = await request(app)
      .get('/policies/policy-abc')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.policy_id).toBe('policy-abc');
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app).get('/policies/policy-abc');
    expect(res.status).toBe(401);
  });
});

// ─── DELETE /policies/:id ─────────────────────────────────────────────────────

describe('DELETE /policies/:id', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockActivePolicy = {
    policy_id: 'policy-abc',
    worker_id: 'worker-123',
    status: 'active',
    billing_cycle_end: new Date('2024-01-08T00:00:00Z'),
    cancelled_at: null,
  };

  test('cancels policy and defers to billing cycle end (Requirement 6.10)', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [mockActivePolicy] }) // SELECT
      .mockResolvedValueOnce({ rows: [] });                // UPDATE

    const res = await request(app)
      .delete('/policies/policy-abc')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);
    expect(res.body.cancelled_at).toBeDefined();
    expect(res.body.effective_cancellation).toBeDefined();

    // effective_cancellation should be the billing_cycle_end
    expect(res.body.effective_cancellation).toBe(mockActivePolicy.billing_cycle_end.toISOString());

    // Verify the UPDATE was called (not a status change, just cancelled_at)
    const updateCall = db.query.mock.calls[1];
    expect(updateCall[0]).toContain('UPDATE policies SET cancelled_at');
  });

  test('publishes policy_cancelled event to Kafka', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [mockActivePolicy] })
      .mockResolvedValueOnce({ rows: [] });

    await request(app)
      .delete('/policies/policy-abc')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    const calls = kafka.publishEvent.mock.calls;
    const lifecycleCall = calls.find(c => c[0] === 'policy_lifecycle');
    expect(lifecycleCall).toBeDefined();
    expect(lifecycleCall[1].event).toBe('policy_cancelled');
    expect(lifecycleCall[1].policy_id).toBe('policy-abc');
  });

  test('returns 404 when policy does not exist', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .delete('/policies/nonexistent')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('not_found');
  });

  test('returns 403 when worker tries to cancel another worker\'s policy', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockActivePolicy] }); // belongs to worker-123

    const res = await request(app)
      .delete('/policies/policy-abc')
      .set('Authorization', `Bearer ${workerToken('different-worker')}`);

    expect(res.status).toBe(403);
  });

  test('returns 409 when policy is already cancelled', async () => {
    db.query.mockResolvedValueOnce({
      rows: [{
        ...mockActivePolicy,
        status: 'cancelled',
        cancelled_at: new Date(),
      }],
    });

    const res = await request(app)
      .delete('/policies/policy-abc')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(409);
    expect(res.body.error).toBe('already_cancelled');
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app).delete('/policies/policy-abc');
    expect(res.status).toBe(401);
  });
});

// ─── PUT /policies/:id/tier ───────────────────────────────────────────────────

describe('PUT /policies/:id/tier', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  const mockPolicy = {
    policy_id: 'policy-abc',
    worker_id: 'worker-123',
    tier: 'silver',
    status: 'active',
  };

  test('upgrades tier with 5-day claim eligibility delay (Requirement 6.6)', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [mockPolicy] }) // SELECT
      .mockResolvedValueOnce({ rows: [] });           // UPDATE

    const before = Date.now();
    const res = await request(app)
      .put('/policies/policy-abc/tier')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ tier: 'gold' });
    const after = Date.now();

    expect(res.status).toBe(200);
    expect(res.body.policy_id).toBe('policy-abc');
    expect(res.body.new_tier).toBe('gold');
    expect(res.body.claim_eligible_from).toBeDefined();

    // Verify 5-day delay (Requirement 6.6)
    const claimEligibleFrom = new Date(res.body.claim_eligible_from).getTime();
    expect(claimEligibleFrom).toBeGreaterThanOrEqual(before + TIER_UPGRADE_DELAY_MS - 1000);
    expect(claimEligibleFrom).toBeLessThanOrEqual(after + TIER_UPGRADE_DELAY_MS + 1000);
  });

  test('returns 400 for invalid tier', async () => {
    const res = await request(app)
      .put('/policies/policy-abc/tier')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ tier: 'diamond' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_tier');
  });

  test('returns 404 when policy does not exist', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .put('/policies/nonexistent/tier')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ tier: 'gold' });

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('not_found');
  });

  test('returns 403 when worker tries to upgrade another worker\'s policy', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockPolicy] }); // belongs to worker-123

    const res = await request(app)
      .put('/policies/policy-abc/tier')
      .set('Authorization', `Bearer ${workerToken('different-worker')}`)
      .send({ tier: 'gold' });

    expect(res.status).toBe(403);
  });
});

// ─── POST /policies/payout-check ─────────────────────────────────────────────

describe('POST /policies/payout-check', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns 200 eligible when no payout in current 7-day cycle', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ count: '0' }] });

    const res = await request(app)
      .post('/policies/payout-check')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ worker_id: 'worker-123', policy_id: 'policy-abc' });

    expect(res.status).toBe(200);
    expect(res.body.eligible).toBe(true);
  });

  test('returns 409 payout_cycle_cap_exceeded when payout already exists in 7-day cycle (Requirement 6.9)', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ count: '1' }] });

    const res = await request(app)
      .post('/policies/payout-check')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ worker_id: 'worker-123', policy_id: 'policy-abc' });

    expect(res.status).toBe(409);
    expect(res.body.error).toBe('payout_cycle_cap_exceeded');
  });

  test('returns 400 when required fields are missing', async () => {
    const res = await request(app)
      .post('/policies/payout-check')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ worker_id: 'worker-123' }); // missing policy_id

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('missing_fields');
  });

  test('returns 403 when worker checks another worker\'s payout cap', async () => {
    const res = await request(app)
      .post('/policies/payout-check')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({ worker_id: 'different-worker', policy_id: 'policy-abc' });

    expect(res.status).toBe(403);
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app)
      .post('/policies/payout-check')
      .send({ worker_id: 'worker-123', policy_id: 'policy-abc' });

    expect(res.status).toBe(401);
  });
});

// ─── Business Rule: 72-hour activation delay ─────────────────────────────────

describe('Business Rule: 72-hour activation delay (Requirement 6.5)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('claim_eligible_from is exactly 72 hours after effective_date', async () => {
    db.query.mockResolvedValueOnce({ rows: [] }); // zone lock check

    const res = await request(app)
      .post('/policies')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`)
      .send({
        worker_id: 'worker-123',
        tier: 'platinum',
        zone_id: 'DEL_CONNAUGHT',
        coverage_cap: 20000,
        weekly_premium: 499,
        aadhaar_hash: 'aadh_test_789',
        device_fingerprint: 'fp_test_789',
      });

    expect(res.status).toBe(201);

    const effectiveDate = new Date(res.body.effective_date).getTime();
    const claimEligibleFrom = new Date(res.body.claim_eligible_from).getTime();
    const actualDelay = claimEligibleFrom - effectiveDate;

    // Should be within 1 second of exactly 72 hours
    expect(Math.abs(actualDelay - ACTIVATION_DELAY_MS)).toBeLessThan(1000);
  });
});

// ─── GET /policies/content (V67) ─────────────────────────────────────────────

describe('GET /policies/content', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns hero + sections shape for worker (V67)', async () => {
    const res = await request(app)
      .get('/policies/content')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);
    expect(res.body.hero).toBeDefined();
    expect(res.body.hero.badge).toBeDefined();
    expect(res.body.hero.title).toBeDefined();
    expect(res.body.hero.subtitle).toBeDefined();
    expect(Array.isArray(res.body.sections)).toBe(true);
    expect(res.body.sections.length).toBeGreaterThan(0);
    expect(res.body.sections[0].title).toBeDefined();
    expect(res.body.sections[0].body).toBeDefined();
    expect(res.body.sections[0].icon_key).toBeDefined();
  });

  test('returns 200 for admin role', async () => {
    const res = await request(app)
      .get('/policies/content')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app).get('/policies/content');
    expect(res.status).toBe(401);
  });
});

// ─── Business Rule: Cancellation deferred to billing cycle end ───────────────

describe('Business Rule: Cancellation deferred to billing cycle end (Requirement 6.10)', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('DELETE does not change status to cancelled immediately', async () => {
    const billingEnd = new Date('2024-02-15T00:00:00Z');
    db.query
      .mockResolvedValueOnce({
        rows: [{
          policy_id: 'policy-xyz',
          worker_id: 'worker-123',
          status: 'active',
          billing_cycle_end: billingEnd,
          cancelled_at: null,
        }],
      })
      .mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .delete('/policies/policy-xyz')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);

    // The UPDATE query should only set cancelled_at, not change status
    const updateCall = db.query.mock.calls[1];
    expect(updateCall[0]).toContain('cancelled_at');
    expect(updateCall[0]).not.toContain('status');

    // effective_cancellation should be billing_cycle_end
    expect(res.body.effective_cancellation).toBe(billingEnd.toISOString());
  });
});
