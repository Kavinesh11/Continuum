// Tests for /reserves routes
// Invariants covered:
//   V47 — runway_sufficient: false when runway_days < 90
//   V48 — POST /reserves/credit with amount <= 0 → HTTP 400
//   V49 — POST /reserves/credit with no reference_id → HTTP 400

'use strict';

process.env.JWT_SECRET = 'test-secret-reserves';
process.env.DB_HOST = 'localhost';

jest.mock('../src/db', () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));

jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../src/services/ledger', () => ({
  creditReserve: jest.fn(),
  debitReserve: jest.fn(),
}));

const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');
const ledger = require('../src/services/ledger');
const { signToken } = require('../src/utils/jwt');

function adminToken() {
  return signToken({ worker_id: 'admin-1', role: 'admin' });
}

function insurerToken() {
  return signToken({ worker_id: 'insurer-1', role: 'insurer' });
}

function workerToken() {
  return signToken({ worker_id: 'worker-1', role: 'worker', platform: 'swiggy', tier: 'silver' });
}

beforeEach(() => jest.clearAllMocks());

// ─── GET /reserves/balance ────────────────────────────────────────────────────

describe('GET /reserves/balance', () => {
  function mockBalanceDb(reserveBalance, dailyAvg) {
    db.query
      .mockResolvedValueOnce({
        rows: [
          { account_id: 'RESERVE_MAIN', balance: String(reserveBalance) },
          { account_id: 'PREMIUM_INCOME', balance: '50000' },
          { account_id: 'PAYOUT_EXPENSE', balance: '40000' },
        ],
      })
      .mockResolvedValueOnce({
        rows: [{ daily_avg: String(dailyAvg) }],
      });
  }

  test('V47: runway_sufficient is false when runway_days < 90', async () => {
    // 88 days of runway: reserve=8800, daily=100
    mockBalanceDb(8800, 100);

    const res = await request(app)
      .get('/reserves/balance')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.runway_days).toBe(88);
    expect(res.body.runway_sufficient).toBe(false);
  });

  test('V47: runway_sufficient is true when runway_days >= 90', async () => {
    // 90 days exactly: reserve=9000, daily=100
    mockBalanceDb(9000, 100);

    const res = await request(app)
      .get('/reserves/balance')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.runway_days).toBe(90);
    expect(res.body.runway_sufficient).toBe(true);
  });

  test('runway_sufficient is true when daily_avg is zero (no payouts yet)', async () => {
    mockBalanceDb(100000, 0);

    const res = await request(app)
      .get('/reserves/balance')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.runway_days).toBeNull();
    expect(res.body.runway_sufficient).toBe(true);
  });

  test('returns correct account balances in response', async () => {
    mockBalanceDb(500000, 5000);

    const res = await request(app)
      .get('/reserves/balance')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.reserve_balance).toBe(500000);
    expect(res.body.premium_income_total).toBe(50000);
    expect(res.body.payout_expense_total).toBe(40000);
    expect(res.body.checked_at).toBeDefined();
  });

  test('insurer role can access balance', async () => {
    mockBalanceDb(100000, 1000);

    const res = await request(app)
      .get('/reserves/balance')
      .set('Authorization', `Bearer ${insurerToken()}`);

    expect(res.status).toBe(200);
  });

  test('worker role is denied (403)', async () => {
    const res = await request(app)
      .get('/reserves/balance')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(403);
  });

  test('unauthenticated request returns 401', async () => {
    const res = await request(app).get('/reserves/balance');
    expect(res.status).toBe(401);
  });
});

// ─── GET /reserves/ledger ─────────────────────────────────────────────────────

describe('GET /reserves/ledger', () => {
  test('returns ledger entries for admin', async () => {
    const entries = [
      {
        entry_id: 'e1',
        debit_account: 'RESERVE_MAIN',
        credit_account: 'PAYOUT_EXPENSE',
        amount: '500.00',
        reference_type: 'payout',
        reference_id: 'p1',
        description: 'payout',
        created_at: new Date(),
      },
    ];
    db.query.mockResolvedValue({ rows: entries });

    const res = await request(app)
      .get('/reserves/ledger')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.entries).toHaveLength(1);
    expect(res.body.entries[0].amount).toBe(500.0);
  });

  test('respects limit query param (max 500)', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app)
      .get('/reserves/ledger?limit=200')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(db.query).toHaveBeenCalledWith(
      expect.any(String),
      [200, 0]
    );
  });

  test('clamps limit to 500', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app)
      .get('/reserves/ledger?limit=9999')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(db.query).toHaveBeenCalledWith(
      expect.any(String),
      [500, 0]
    );
  });
});

// ─── POST /reserves/credit ────────────────────────────────────────────────────

describe('POST /reserves/credit', () => {
  test('V48: amount <= 0 returns 400', async () => {
    const res = await request(app)
      .post('/reserves/credit')
      .set('Authorization', `Bearer ${adminToken()}`)
      .send({ amount: 0, reference_id: 'ref-1' });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('amount');
  });

  test('V48: negative amount returns 400', async () => {
    const res = await request(app)
      .post('/reserves/credit')
      .set('Authorization', `Bearer ${adminToken()}`)
      .send({ amount: -500, reference_id: 'ref-1' });

    expect(res.status).toBe(400);
  });

  test('V49: missing reference_id returns 400', async () => {
    const res = await request(app)
      .post('/reserves/credit')
      .set('Authorization', `Bearer ${adminToken()}`)
      .send({ amount: 1000 });

    expect(res.status).toBe(400);
    expect(res.body.error).toContain('reference_id');
  });

  test('valid credit returns 200 with new_balance', async () => {
    ledger.creditReserve.mockResolvedValue(600000);

    const res = await request(app)
      .post('/reserves/credit')
      .set('Authorization', `Bearer ${adminToken()}`)
      .send({ amount: 100000, reference_id: 'capital-injection-1', description: 'test credit' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('credited');
    expect(res.body.amount).toBe(100000);
    expect(res.body.new_balance).toBe(600000);
    expect(ledger.creditReserve).toHaveBeenCalledWith(100000, 'capital-injection-1');
  });

  test('worker and insurer roles cannot credit reserve', async () => {
    const workerRes = await request(app)
      .post('/reserves/credit')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ amount: 1000, reference_id: 'ref-1' });

    expect(workerRes.status).toBe(403);

    const insurerRes = await request(app)
      .post('/reserves/credit')
      .set('Authorization', `Bearer ${insurerToken()}`)
      .send({ amount: 1000, reference_id: 'ref-1' });

    expect(insurerRes.status).toBe(403);
  });
});
