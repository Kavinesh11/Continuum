// Feature: continuum-ml-pipelines
// Unit tests for payout history, claim status endpoints, and OCC helper
// Requirements: 6.1, 9.5

'use strict';

process.env.JWT_SECRET = 'test-secret-key-for-payout-tests';
process.env.DB_HOST = 'localhost';

// ─── Mocks ────────────────────────────────────────────────────────────────────

jest.mock('../src/db', () => {
  const mockQuery = jest.fn();
  const mockConnect = jest.fn();
  return { query: mockQuery, connect: mockConnect };
});

jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));

const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');
const { signToken } = require('../src/utils/jwt');
const { createPayoutWithOCC } = require('../src/routes/payouts');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function workerToken(workerId = 'worker-123') {
  return signToken({ worker_id: workerId, role: 'worker', platform: 'swiggy', tier: 'silver' });
}

function adminToken() {
  return signToken({ worker_id: 'admin-1', role: 'admin' });
}

/** Build a mock pg client for transaction tests */
function mockPgClient(overrides = {}) {
  return {
    query: jest.fn(),
    release: jest.fn(),
    ...overrides,
  };
}

// ─── GET /payouts ─────────────────────────────────────────────────────────────

describe('GET /payouts', () => {
  beforeEach(() => jest.clearAllMocks());

  const mockPayouts = [
    {
      payout_id:    'payout-1',
      worker_id:    'worker-123',
      claim_id:     'claim-1',
      policy_id:    'policy-1',
      amount:       '500.00',
      oracle_votes: [{ oracle: 'imd', vote: 'affirm' }],
      zone_id:      'MUM_ANDHERI_W',
      tier:         'silver',
      payu_txn_ref: 'PAYU_TXN_001',
      status:       'disbursed',
      disbursed_at: new Date('2024-01-10T12:00:00Z'),
      created_at:   new Date('2024-01-10T11:55:00Z'),
    },
    {
      payout_id:    'payout-2',
      worker_id:    'worker-123',
      claim_id:     'claim-2',
      policy_id:    'policy-1',
      amount:       '300.00',
      oracle_votes: [],
      zone_id:      'MUM_ANDHERI_W',
      tier:         'silver',
      payu_txn_ref: null,
      status:       'pending',
      disbursed_at: null,
      created_at:   new Date('2024-01-15T09:00:00Z'),
    },
  ];

  test('returns worker\'s own payout history with HTTP 200', async () => {
    db.query.mockResolvedValueOnce({ rows: mockPayouts });

    const res = await request(app)
      .get('/payouts')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(2);
    expect(res.body[0].payout_id).toBe('payout-1');
    expect(res.body[0].amount).toBe(500);
    expect(res.body[0].status).toBe('disbursed');
    expect(res.body[1].payout_id).toBe('payout-2');
    expect(res.body[1].payu_txn_ref).toBeNull();
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app).get('/payouts');
    expect(res.status).toBe(401);
  });

  test('returns empty array when worker has no payouts', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .get('/payouts')
      .set('Authorization', `Bearer ${workerToken('worker-no-payouts')}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });

  test('query uses authenticated worker_id from JWT (not a query param)', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    await request(app)
      .get('/payouts')
      .set('Authorization', `Bearer ${workerToken('worker-abc')}`);

    const queryCall = db.query.mock.calls[0];
    // The worker_id bound in the query must come from the JWT
    expect(queryCall[1]).toEqual(['worker-abc']);
  });

  test('returns 403 for admin role (payouts endpoint is worker-only)', async () => {
    const res = await request(app)
      .get('/payouts')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(403);
  });
});

// ─── GET /claims/:id/status ───────────────────────────────────────────────────

describe('GET /claims/:id/status', () => {
  beforeEach(() => jest.clearAllMocks());

  const mockClaim = {
    claim_id:         'claim-abc',
    worker_id:        'worker-123',
    policy_id:        'policy-1',
    event_type:       'heavy_rainfall',
    event_timestamp:  new Date('2024-01-22T08:15:00Z'),
    gps_lat:          '19.1136',
    gps_lon:          '72.8697',
    zone_id:          'MUM_ANDHERI_W',
    status:           'auto_approved',
    fraud_score:      '0.82',
    estimated_payout: '500.00',
    submitted_at:     new Date('2024-01-22T08:14:00Z'),
    decided_at:       new Date('2024-01-22T08:15:02Z'),
  };

  test('returns claim with fraud_score for the owning worker', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockClaim] });

    const res = await request(app)
      .get('/claims/claim-abc/status')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);
    expect(res.body.claim_id).toBe('claim-abc');
    expect(res.body.status).toBe('auto_approved');
    expect(res.body.fraud_score).toBe(0.82);
    expect(res.body.estimated_payout).toBe(500);
    expect(res.body.zone_id).toBe('MUM_ANDHERI_W');
    expect(res.body.decided_at).toBeDefined();
  });

  test('returns 404 for unknown claim id', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .get('/claims/nonexistent-claim/status')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('not_found');
  });

  test('returns 403 when worker accesses another worker\'s claim', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockClaim] }); // claim belongs to worker-123

    const res = await request(app)
      .get('/claims/claim-abc/status')
      .set('Authorization', `Bearer ${workerToken('different-worker')}`);

    expect(res.status).toBe(403);
    expect(res.body.error).toBe('insufficient_role');
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app).get('/claims/claim-abc/status');
    expect(res.status).toBe(401);
  });

  test('admin can access any claim', async () => {
    db.query.mockResolvedValueOnce({ rows: [mockClaim] });

    const res = await request(app)
      .get('/claims/claim-abc/status')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.claim_id).toBe('claim-abc');
  });

  test('fraud_score is returned as a float', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ ...mockClaim, fraud_score: '0.55' }] });

    const res = await request(app)
      .get('/claims/claim-abc/status')
      .set('Authorization', `Bearer ${workerToken('worker-123')}`);

    expect(res.status).toBe(200);
    expect(typeof res.body.fraud_score).toBe('number');
    expect(res.body.fraud_score).toBe(0.55);
  });
});

// ─── createPayoutWithOCC ──────────────────────────────────────────────────────

describe('createPayoutWithOCC', () => {
  beforeEach(() => jest.clearAllMocks());

  const basePayoutData = {
    worker_id:   'worker-123',
    claim_id:    'claim-xyz',
    policy_id:   'policy-1',
    amount:      500,
    oracle_votes: [{ oracle: 'imd', vote: 'affirm' }],
    zone_id:     'MUM_ANDHERI_W',
    tier:        'silver',
    payu_txn_ref: null,
  };

  test('returns null (409 signal) when duplicate payout exists in 7-day window', async () => {
    const client = mockPgClient();
    db.connect.mockResolvedValueOnce(client);

    // BEGIN succeeds
    client.query.mockResolvedValueOnce({});
    // SELECT FOR UPDATE finds existing row
    client.query.mockResolvedValueOnce({ rows: [{ payout_id: 'existing-payout' }] });
    // ROLLBACK
    client.query.mockResolvedValueOnce({});

    const result = await createPayoutWithOCC(basePayoutData);

    expect(result).toBeNull();
    // Verify ROLLBACK was called
    const calls = client.query.mock.calls.map(c => c[0]);
    expect(calls).toContain('ROLLBACK');
    expect(client.release).toHaveBeenCalled();
  });

  test('inserts and returns payout row when no duplicate exists', async () => {
    const client = mockPgClient();
    db.connect.mockResolvedValueOnce(client);

    const insertedRow = {
      payout_id:    'new-payout-id',
      worker_id:    'worker-123',
      claim_id:     'claim-xyz',
      policy_id:    'policy-1',
      amount:       '500.00',
      oracle_votes: [{ oracle: 'imd', vote: 'affirm' }],
      zone_id:      'MUM_ANDHERI_W',
      tier:         'silver',
      payu_txn_ref: null,
      status:       'pending',
      created_at:   new Date(),
    };

    client.query
      .mockResolvedValueOnce({})                        // BEGIN
      .mockResolvedValueOnce({ rows: [] })              // SELECT FOR UPDATE — no duplicate
      .mockResolvedValueOnce({ rows: [insertedRow] })   // INSERT RETURNING
      .mockResolvedValueOnce({});                       // COMMIT

    const result = await createPayoutWithOCC(basePayoutData);

    expect(result).not.toBeNull();
    expect(result.payout_id).toBe('new-payout-id');
    expect(result.worker_id).toBe('worker-123');

    // Verify COMMIT was called
    const calls = client.query.mock.calls.map(c => c[0]);
    expect(calls).toContain('COMMIT');
    expect(client.release).toHaveBeenCalled();
  });

  test('rolls back and rethrows on unexpected DB error', async () => {
    const client = mockPgClient();
    db.connect.mockResolvedValueOnce(client);

    client.query
      .mockResolvedValueOnce({})                          // BEGIN
      .mockRejectedValueOnce(new Error('DB connection lost')); // SELECT throws

    await expect(createPayoutWithOCC(basePayoutData)).rejects.toThrow('DB connection lost');

    const calls = client.query.mock.calls.map(c => c[0]);
    expect(calls).toContain('ROLLBACK');
    expect(client.release).toHaveBeenCalled();
  });

  test('SELECT FOR UPDATE uses the correct worker_id and claim_id parameters', async () => {
    const client = mockPgClient();
    db.connect.mockResolvedValueOnce(client);

    client.query
      .mockResolvedValueOnce({})                        // BEGIN
      .mockResolvedValueOnce({ rows: [] })              // SELECT FOR UPDATE
      .mockResolvedValueOnce({ rows: [{ payout_id: 'p1', worker_id: 'worker-123', claim_id: 'claim-xyz', policy_id: 'policy-1', amount: '500', oracle_votes: [], zone_id: 'MUM_ANDHERI_W', tier: 'silver', payu_txn_ref: null, status: 'pending', created_at: new Date() }] })
      .mockResolvedValueOnce({});                       // COMMIT

    await createPayoutWithOCC(basePayoutData);

    // Second call is the SELECT FOR UPDATE
    const selectCall = client.query.mock.calls[1];
    expect(selectCall[1][0]).toBe('worker-123');  // $1 = worker_id
    expect(selectCall[1][1]).toBe('claim-xyz');   // $2 = claim_id
  });
});
