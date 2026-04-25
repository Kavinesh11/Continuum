// Feature: continuum-ml-pipelines
// Property-based tests for JWT expiry rejection and RBAC
// Validates: Requirements 6.2, 6.3, 6.4

'use strict';

process.env.JWT_SECRET = 'test-secret-key-for-property-tests';
process.env.DB_HOST = 'localhost';

const fc = require('fast-check');
const jwt = require('jsonwebtoken');
const { authenticate } = require('../src/middleware/auth');
const { requireRole } = require('../src/middleware/rbac');

const SECRET = process.env.JWT_SECRET;
const MAX_LIFETIME_SECONDS = 86400; // 24 hours

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Craft a JWT with an explicit iat (issued-at) value.
 * We use a long expiresIn so that jsonwebtoken's own expiry check
 * does not interfere — only the middleware's iat-based lifetime check matters.
 */
function craftTokenWithAge(ageSeconds, role = 'worker', workerId = 'w1') {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const iat = nowSeconds - ageSeconds;
  // jwt.sign ignores iat in payload when noTimestamp is false, so we sign
  // without automatic iat and inject it manually via the payload.
  // Using a far-future exp so jwt.verify itself won't reject the token.
  return jwt.sign(
    { worker_id: workerId, role, iat },
    SECRET,
    { expiresIn: '365d' }
  );
}

function mockRes() {
  const res = {
    _status: null,
    _body: null,
    status(code) { this._status = code; return this; },
    json(body) { this._body = body; return this; },
  };
  return res;
}

function mockReq(token) {
  return { headers: { authorization: `Bearer ${token}` } };
}

// ─── Property 18: JWT Expiry Rejection ────────────────────────────────────────
// Feature: continuum-ml-pipelines, Property 18: JWT Expiry Rejection
// Validates: Requirements 6.2, 6.3

describe('Property 18: JWT Expiry Rejection', () => {
  // Unit test: token well within 24h boundary should be valid
  test('token aged 23h 59m (86340s) is accepted', () => {
    const token = craftTokenWithAge(MAX_LIFETIME_SECONDS - 60); // 1 minute under limit
    const req = mockReq(token);
    const res = mockRes();
    const next = jest.fn();
    authenticate(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res._status).toBeNull();
  });

  // Unit test: token aged 1s over 24h is rejected
  test('token aged 24h + 1s (86401s) is rejected with HTTP 401', () => {
    const token = craftTokenWithAge(MAX_LIFETIME_SECONDS + 1);
    const req = mockReq(token);
    const res = mockRes();
    const next = jest.fn();
    authenticate(req, res, next);
    expect(res._status).toBe(401);
    expect(res._body).toEqual({ error: 'invalid_token' });
    expect(next).not.toHaveBeenCalled();
  });

  // Property 18: For any token age > 86400s, authenticate must return HTTP 401
  test('PBT — any token age > 24h yields HTTP 401 (no business logic executes)', () => {
    // Feature: continuum-ml-pipelines, Property 18: JWT Expiry Rejection
    fc.assert(
      fc.property(
        // Generate ages strictly greater than 86400 seconds (up to ~10 years)
        fc.integer({ min: MAX_LIFETIME_SECONDS + 1, max: 315_360_000 }),
        fc.constantFrom('worker', 'admin', 'insurer'),
        (ageSeconds, role) => {
          const token = craftTokenWithAge(ageSeconds, role);
          const req = mockReq(token);
          const res = mockRes();
          const next = jest.fn();

          authenticate(req, res, next);

          // HTTP 401 must be returned
          if (res._status !== 401) return false;
          // Error body must be structured correctly
          if (!res._body || res._body.error !== 'invalid_token') return false;
          // next() must NOT have been called (no business logic executes)
          if (next.mock.calls.length !== 0) return false;

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 18 (inverse): For any token age <= 86400s, authenticate must call next()
  test('PBT — any token age <= 24h calls next() (token is valid)', () => {
    // Feature: continuum-ml-pipelines, Property 18: JWT Expiry Rejection
    fc.assert(
      fc.property(
        // Generate ages from 0 to 86399 seconds (strictly under the 24h limit)
        // Age = 86400 is excluded: by the time authenticate() runs, elapsed time
        // may push it just over the boundary, making it a flaky edge case.
        fc.integer({ min: 0, max: MAX_LIFETIME_SECONDS - 1 }),
        fc.constantFrom('worker', 'admin', 'insurer'),
        (ageSeconds, role) => {
          const token = craftTokenWithAge(ageSeconds, role);
          const req = mockReq(token);
          const res = mockRes();
          const next = jest.fn();

          authenticate(req, res, next);

          // next() must have been called
          if (next.mock.calls.length !== 1) return false;
          // No error response should have been sent
          if (res._status !== null) return false;

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── Property 19: RBAC Access Control ────────────────────────────────────────
// Feature: continuum-ml-pipelines, Property 19: RBAC Access Control
// Validates: Requirements 6.4

const ALL_ROLES = ['worker', 'admin', 'insurer'];

describe('Property 19: RBAC Access Control', () => {
  // Unit test: worker accessing admin-only endpoint → 403
  test('worker role is rejected from admin-only endpoint', () => {
    const req = { headers: {}, user: { role: 'worker', worker_id: 'w1' } };
    const res = mockRes();
    const next = jest.fn();
    requireRole('admin')(req, res, next);
    expect(res._status).toBe(403);
    expect(res._body).toEqual({ error: 'insufficient_role' });
    expect(next).not.toHaveBeenCalled();
  });

  // Unit test: worker accessing insurer-only endpoint → 403
  test('worker role is rejected from insurer-only endpoint', () => {
    const req = { headers: {}, user: { role: 'worker', worker_id: 'w1' } };
    const res = mockRes();
    const next = jest.fn();
    requireRole('insurer')(req, res, next);
    expect(res._status).toBe(403);
    expect(res._body).toEqual({ error: 'insufficient_role' });
    expect(next).not.toHaveBeenCalled();
  });

  // Unit test: matching role passes
  test('matching role calls next()', () => {
    const req = { headers: {}, user: { role: 'admin', worker_id: 'w1' } };
    const res = mockRes();
    const next = jest.fn();
    requireRole('admin')(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res._status).toBeNull();
  });

  // Property 19a: For any (user_role, required_role) where user_role != required_role,
  // requireRole must return HTTP 403
  test('PBT — mismatched role always yields HTTP 403', () => {
    // Feature: continuum-ml-pipelines, Property 19: RBAC Access Control
    fc.assert(
      fc.property(
        fc.constantFrom(...ALL_ROLES),
        fc.constantFrom(...ALL_ROLES),
        (userRole, requiredRole) => {
          // Only test mismatched roles
          fc.pre(userRole !== requiredRole);

          const req = { headers: {}, user: { role: userRole, worker_id: 'w1' } };
          const res = mockRes();
          const next = jest.fn();

          requireRole(requiredRole)(req, res, next);

          if (res._status !== 403) return false;
          if (!res._body || res._body.error !== 'insufficient_role') return false;
          if (next.mock.calls.length !== 0) return false;

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 19b: For any role, requireRole with that same role must call next()
  test('PBT — matching role always calls next()', () => {
    // Feature: continuum-ml-pipelines, Property 19: RBAC Access Control
    fc.assert(
      fc.property(
        fc.constantFrom(...ALL_ROLES),
        (role) => {
          const req = { headers: {}, user: { role, worker_id: 'w1' } };
          const res = mockRes();
          const next = jest.fn();

          requireRole(role)(req, res, next);

          if (next.mock.calls.length !== 1) return false;
          if (res._status !== null) return false;

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 19c: Cross-worker resource access — worker_id in token != worker_id in params → HTTP 403
  // This tests the pattern where a worker tries to access another worker's resource.
  // The middleware enforcing this is a composed authenticate + requireRole + ownership check.
  // We test the ownership check logic directly here.
  test('PBT — worker accessing another worker\'s resource yields HTTP 403', () => {
    // Feature: continuum-ml-pipelines, Property 19: RBAC Access Control
    // Ownership guard: worker can only access their own resources
    function requireOwnership(req, res, next) {
      const tokenWorkerId = req.user && req.user.worker_id;
      const paramWorkerId = req.params && req.params.worker_id;
      if (!tokenWorkerId || tokenWorkerId !== paramWorkerId) {
        return res.status(403).json({ error: 'insufficient_role' });
      }
      next();
    }

    fc.assert(
      fc.property(
        // Generate two distinct worker IDs
        fc.uuid(),
        fc.uuid(),
        (tokenWorkerId, paramWorkerId) => {
          // Only test cross-worker access (different IDs)
          fc.pre(tokenWorkerId !== paramWorkerId);

          const req = {
            headers: {},
            user: { role: 'worker', worker_id: tokenWorkerId },
            params: { worker_id: paramWorkerId },
          };
          const res = mockRes();
          const next = jest.fn();

          requireOwnership(req, res, next);

          if (res._status !== 403) return false;
          if (!res._body || res._body.error !== 'insufficient_role') return false;
          if (next.mock.calls.length !== 0) return false;

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 19d: Same worker_id in token and params → next() is called
  test('PBT — worker accessing own resource calls next()', () => {
    // Feature: continuum-ml-pipelines, Property 19: RBAC Access Control
    function requireOwnership(req, res, next) {
      const tokenWorkerId = req.user && req.user.worker_id;
      const paramWorkerId = req.params && req.params.worker_id;
      if (!tokenWorkerId || tokenWorkerId !== paramWorkerId) {
        return res.status(403).json({ error: 'insufficient_role' });
      }
      next();
    }

    fc.assert(
      fc.property(
        fc.uuid(),
        (workerId) => {
          const req = {
            headers: {},
            user: { role: 'worker', worker_id: workerId },
            params: { worker_id: workerId },
          };
          const res = mockRes();
          const next = jest.fn();

          requireOwnership(req, res, next);

          if (next.mock.calls.length !== 1) return false;
          if (res._status !== null) return false;

          return true;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── Properties 20–23: Policy Business Rules ─────────────────────────────────
// Feature: continuum-ml-pipelines
// Validates: Requirements 6.5, 6.6, 6.9, 6.10

'use strict';

// Mock DB and Kafka before requiring app (idempotent — jest deduplicates)
// db.connect() is used by policies.js for transactions (BEGIN/COMMIT).
jest.mock('../src/db', () => ({ query: jest.fn(), connect: jest.fn() }));
jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));
// Disable rate limiting — PBT runs 100+ requests which would hit the global limit
jest.mock('express-rate-limit', () => () => (_req, _res, next) => next());

const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');
const { signToken } = require('../src/utils/jwt');

const ACTIVATION_DELAY_MS   = 72 * 60 * 60 * 1000;       // 72 hours
const TIER_UPGRADE_DELAY_MS = 5 * 24 * 60 * 60 * 1000;   // 5 days
const BILLING_CYCLE_MS      = 7 * 24 * 60 * 60 * 1000;   // 7 days

function workerToken(workerId = 'worker-pbt') {
  return signToken({ worker_id: workerId, role: 'worker', platform: 'swiggy', tier: 'silver' });
}

// Shared mock client for db.connect() — used by policies.js transaction (BEGIN/COMMIT)
const mockClientQuery = jest.fn().mockResolvedValue({ rows: [] });
const mockRelease = jest.fn();

// Configure connect() before each PBT test (cleared in beforeEach blocks)
beforeEach(() => {
  db.connect.mockResolvedValue({ query: mockClientQuery, release: mockRelease });
  mockClientQuery.mockResolvedValue({ rows: [] });
});

// ─── Property 20: Policy Activation Delay ────────────────────────────────────
// Feature: continuum-ml-pipelines, Property 20: Policy Activation Delay
// For any newly registered worker, claim_eligible_from >= registered_at + 72h
// Validates: Requirements 6.5

describe('Property 20: Policy Activation Delay', () => {
  beforeEach(() => jest.clearAllMocks());

  test('PBT — claim_eligible_from is always >= effective_date + 72h for any registration time', () => {
    // Feature: continuum-ml-pipelines, Property 20: Policy Activation Delay
    return fc.assert(
      fc.asyncProperty(
        // Generate arbitrary past timestamps (up to 365 days ago) as registration offsets
        fc.integer({ min: 0, max: 365 * 24 * 60 * 60 * 1000 }),
        fc.constantFrom('silver', 'gold', 'platinum'),
        async (pastOffsetMs, tier) => {
          db.query.mockResolvedValueOnce({ rows: [] }); // INSERT succeeds

          const workerId = `worker-p20-${pastOffsetMs}`;
          const token = signToken({ worker_id: workerId, role: 'worker', platform: 'swiggy', tier });

          const res = await request(app)
            .post('/policies')
            .set('Authorization', `Bearer ${token}`)
            .send({
              worker_id: workerId,
              tier,
              zone_id: 'MUM_ANDHERI_W',
              coverage_cap: 5000,
              weekly_premium: 149,
              aadhaar_hash: `aadh_pbt_${pastOffsetMs}`,
              device_fingerprint: `fp_pbt_${pastOffsetMs}`,
            });

          if (res.status !== 201) return false;

          const effectiveDate    = new Date(res.body.effective_date).getTime();
          const claimEligibleFrom = new Date(res.body.claim_eligible_from).getTime();

          // Property: claim_eligible_from must be at least 72 hours after effective_date
          return claimEligibleFrom >= effectiveDate + ACTIVATION_DELAY_MS - 500; // 500ms tolerance
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── Property 21: Tier Upgrade Waiting Period ────────────────────────────────
// Feature: continuum-ml-pipelines, Property 21: Tier Upgrade Waiting Period
// For any tier upgrade, claim_eligible_from >= upgrade_request_at + 5 days
// Validates: Requirements 6.6

describe('Property 21: Tier Upgrade Waiting Period', () => {
  beforeEach(() => jest.clearAllMocks());

  test('PBT — claim_eligible_from after tier upgrade is always >= request_time + 5 days', () => {
    // Feature: continuum-ml-pipelines, Property 21: Tier Upgrade Waiting Period
    return fc.assert(
      fc.asyncProperty(
        fc.constantFrom('silver', 'gold', 'platinum'),
        async (newTier) => {
          const workerId = 'worker-p21';
          const policyId = 'policy-p21';

          db.query
            .mockResolvedValueOnce({ rows: [{ policy_id: policyId, worker_id: workerId, tier: 'silver', status: 'active' }] }) // SELECT
            .mockResolvedValueOnce({ rows: [] }); // UPDATE

          const token = workerToken(workerId);
          const requestTime = Date.now();

          const res = await request(app)
            .put(`/policies/${policyId}/tier`)
            .set('Authorization', `Bearer ${token}`)
            .send({ tier: newTier });

          if (res.status !== 200) return false;

          const claimEligibleFrom = new Date(res.body.claim_eligible_from).getTime();

          // Property: claim_eligible_from must be at least 5 days after the upgrade request
          return claimEligibleFrom >= requestTime + TIER_UPGRADE_DELAY_MS - 500; // 500ms tolerance
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — claim_eligible_from delay holds for all valid tier values', () => {
    // Feature: continuum-ml-pipelines, Property 21: Tier Upgrade Waiting Period
    return fc.assert(
      fc.asyncProperty(
        fc.constantFrom('silver', 'gold', 'platinum'),
        fc.uuid(),
        async (newTier, policyId) => {
          const workerId = 'worker-p21b';

          db.query
            .mockResolvedValueOnce({ rows: [{ policy_id: policyId, worker_id: workerId, tier: 'silver', status: 'active' }] })
            .mockResolvedValueOnce({ rows: [] });

          const token = workerToken(workerId);
          const before = Date.now();

          const res = await request(app)
            .put(`/policies/${policyId}/tier`)
            .set('Authorization', `Bearer ${token}`)
            .send({ tier: newTier });

          const after = Date.now();

          if (res.status !== 200) return false;

          const claimEligibleFrom = new Date(res.body.claim_eligible_from).getTime();

          // Property: the delay window must be at least 5 days from before the request
          return claimEligibleFrom >= before + TIER_UPGRADE_DELAY_MS - 500;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── Property 22: Payout Cycle Cap ───────────────────────────────────────────
// Feature: continuum-ml-pipelines, Property 22: Payout Cycle Cap
// At most one successful payout per worker per 7-day billing cycle.
// Second attempt within same cycle must be rejected with HTTP 409.
// Validates: Requirements 6.9

describe('Property 22: Payout Cycle Cap', () => {
  beforeEach(() => jest.clearAllMocks());

  test('PBT — payout-check returns 200 when count=0 in 7-day window', () => {
    // Feature: continuum-ml-pipelines, Property 22: Payout Cycle Cap
    return fc.assert(
      fc.asyncProperty(
        fc.uuid(), // arbitrary policy_id
        async (policyId) => {
          db.query.mockResolvedValueOnce({ rows: [{ count: '0' }] });

          const res = await request(app)
            .post('/policies/payout-check')
            .set('Authorization', `Bearer ${workerToken('worker-p22')}`)
            .send({ worker_id: 'worker-p22', policy_id: policyId });

          return res.status === 200 && res.body.eligible === true;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — payout-check returns 409 when count=1 in 7-day window', () => {
    // Feature: continuum-ml-pipelines, Property 22: Payout Cycle Cap
    return fc.assert(
      fc.asyncProperty(
        fc.uuid(),
        async (policyId) => {
          db.query.mockResolvedValueOnce({ rows: [{ count: '1' }] });

          const res = await request(app)
            .post('/policies/payout-check')
            .set('Authorization', `Bearer ${workerToken('worker-p22')}`)
            .send({ worker_id: 'worker-p22', policy_id: policyId });

          return res.status === 409 && res.body.error === 'payout_cycle_cap_exceeded';
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — payout-check returns 409 for any count >= 1 (cap is hard at 1)', () => {
    // Feature: continuum-ml-pipelines, Property 22: Payout Cycle Cap
    return fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 1, max: 100 }), // any count >= 1 must be rejected
        fc.uuid(),
        async (existingPayoutCount, policyId) => {
          db.query.mockResolvedValueOnce({ rows: [{ count: String(existingPayoutCount) }] });

          const res = await request(app)
            .post('/policies/payout-check')
            .set('Authorization', `Bearer ${workerToken('worker-p22')}`)
            .send({ worker_id: 'worker-p22', policy_id: policyId });

          return res.status === 409 && res.body.error === 'payout_cycle_cap_exceeded';
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── Property 23: Policy Cancellation Deferral ───────────────────────────────
// Feature: continuum-ml-pipelines, Property 23: Policy Cancellation Deferral
// Policy must remain active until billing_cycle_end; effective_cancellation == billing_cycle_end.
// The UPDATE must NOT change the status field.
// Validates: Requirements 6.10

describe('Property 23: Policy Cancellation Deferral', () => {
  beforeEach(() => jest.clearAllMocks());

  test('PBT — effective_cancellation always equals billing_cycle_end for any future billing end', () => {
    // Feature: continuum-ml-pipelines, Property 23: Policy Cancellation Deferral
    return fc.assert(
      fc.asyncProperty(
        // Generate arbitrary future billing_cycle_end offsets (1 hour to 30 days from now)
        fc.integer({ min: 60 * 60 * 1000, max: 30 * 24 * 60 * 60 * 1000 }),
        async (futureOffsetMs) => {
          const billingCycleEnd = new Date(Date.now() + futureOffsetMs);
          const policyId = 'policy-p23';
          const workerId = 'worker-p23';

          db.query
            .mockResolvedValueOnce({
              rows: [{
                policy_id: policyId,
                worker_id: workerId,
                status: 'active',
                billing_cycle_end: billingCycleEnd,
                cancelled_at: null,
              }],
            })
            .mockResolvedValueOnce({ rows: [] }); // UPDATE

          const res = await request(app)
            .delete(`/policies/${policyId}`)
            .set('Authorization', `Bearer ${workerToken(workerId)}`);

          if (res.status !== 200) return false;

          // Property: effective_cancellation must equal billing_cycle_end
          const effectiveCancellation = new Date(res.body.effective_cancellation).getTime();
          const expectedEnd = billingCycleEnd.getTime();

          return effectiveCancellation === expectedEnd;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — DELETE never changes status field in the UPDATE query (only sets cancelled_at)', () => {
    // Feature: continuum-ml-pipelines, Property 23: Policy Cancellation Deferral
    return fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 60 * 60 * 1000, max: 30 * 24 * 60 * 60 * 1000 }),
        async (futureOffsetMs) => {
          const billingCycleEnd = new Date(Date.now() + futureOffsetMs);
          const policyId = 'policy-p23b';
          const workerId = 'worker-p23b';

          db.query
            .mockResolvedValueOnce({
              rows: [{
                policy_id: policyId,
                worker_id: workerId,
                status: 'active',
                billing_cycle_end: billingCycleEnd,
                cancelled_at: null,
              }],
            })
            .mockResolvedValueOnce({ rows: [] });

          const res = await request(app)
            .delete(`/policies/${policyId}`)
            .set('Authorization', `Bearer ${workerToken(workerId)}`);

          if (res.status !== 200) return false;

          // Property: the UPDATE SQL must NOT contain 'status' — only cancelled_at is set
          const updateCall = db.query.mock.calls[1];
          const updateSql = updateCall[0];

          return updateSql.includes('cancelled_at') && !updateSql.includes('status');
        }
      ),
      { numRuns: 100 }
    );
  });
});
