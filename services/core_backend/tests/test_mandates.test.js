// Tests for /mandates routes
// Invariants covered:
//   V44 — missing policy_id, upi_id, or max_amount → HTTP 400 missing_fields
//   V45 — webhook without x-payu-signature → HTTP 401
//   V46 — webhook with wrong HMAC signature → HTTP 403 invalid_signature

'use strict';

process.env.JWT_SECRET = 'test-secret-mandate';
process.env.DB_HOST = 'localhost';
process.env.PAYU_WEBHOOK_SECRET = 'test-webhook-secret';

jest.mock('../src/db', () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));

jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../src/services/upi_mandate', () => ({
  createMandate: jest.fn(),
  handleMandateWebhook: jest.fn(),
  getMandateByPolicy: jest.fn(),
}));

const crypto = require('crypto');
const request = require('supertest');
const app = require('../src/app');
const { signToken } = require('../src/utils/jwt');
const upiMandate = require('../src/services/upi_mandate');

function workerToken(workerId = 'worker-m1') {
  return signToken({ worker_id: workerId, role: 'worker', platform: 'swiggy', tier: 'silver' });
}

function adminToken() {
  return signToken({ worker_id: 'admin-1', role: 'admin' });
}

function makeWebhookSignature(body, secret = 'test-webhook-secret') {
  return crypto.createHmac('sha256', secret).update(JSON.stringify(body)).digest('hex');
}

beforeEach(() => jest.clearAllMocks());

// ─── POST /mandates ──────────────────────────────────────────────────────────

describe('POST /mandates', () => {
  test('V44: missing policy_id returns 400 missing_fields', async () => {
    const res = await request(app)
      .post('/mandates')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ upi_id: 'worker@upi', max_amount: 500 });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('missing_fields');
  });

  test('V44: missing upi_id returns 400 missing_fields', async () => {
    const res = await request(app)
      .post('/mandates')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ policy_id: 'policy-1', max_amount: 500 });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('missing_fields');
  });

  test('V44: missing max_amount returns 400 missing_fields', async () => {
    const res = await request(app)
      .post('/mandates')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ policy_id: 'policy-1', upi_id: 'worker@upi' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('missing_fields');
  });

  test('V44: empty body returns 400 missing_fields', async () => {
    const res = await request(app)
      .post('/mandates')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('missing_fields');
  });

  test('valid request calls createMandate and returns 201', async () => {
    upiMandate.createMandate.mockResolvedValue({
      mandate_id: 'mandate-1',
      worker_id: 'worker-m1',
      policy_id: 'policy-1',
      status: 'created',
      provider_ref: 'pref-123',
    });

    const res = await request(app)
      .post('/mandates')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ policy_id: 'policy-1', upi_id: 'worker@upi', max_amount: 500 });

    expect(res.status).toBe(201);
    expect(res.body.mandate_id).toBeDefined();
    expect(res.body.status).toBe('created');
    expect(upiMandate.createMandate).toHaveBeenCalledWith(
      'worker-m1', 'policy-1', 'worker@upi', 500
    );
  });

  test('unauthenticated request returns 401', async () => {
    const res = await request(app)
      .post('/mandates')
      .send({ policy_id: 'policy-1', upi_id: 'worker@upi', max_amount: 500 });

    expect(res.status).toBe(401);
  });
});

// ─── GET /mandates/policy/:policyId ──────────────────────────────────────────

describe('GET /mandates/policy/:policyId', () => {
  test('returns 200 with mandate when found', async () => {
    upiMandate.getMandateByPolicy.mockResolvedValue({
      mandate_id: 'mandate-1',
      policy_id: 'policy-1',
      status: 'active',
    });

    const res = await request(app)
      .get('/mandates/policy/policy-1')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.mandate_id).toBe('mandate-1');
  });

  test('returns 404 when no mandate found', async () => {
    upiMandate.getMandateByPolicy.mockResolvedValue(null);

    const res = await request(app)
      .get('/mandates/policy/policy-999')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('no_active_mandate');
  });

  test('admin role can access mandate', async () => {
    upiMandate.getMandateByPolicy.mockResolvedValue({ mandate_id: 'x', status: 'active' });

    const res = await request(app)
      .get('/mandates/policy/policy-1')
      .set('Authorization', `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
  });
});

// ─── POST /mandates/webhook ───────────────────────────────────────────────────

describe('POST /mandates/webhook', () => {
  const webhookBody = { mandate_id: 'mandate-1', status: 'APPROVED' };

  test('V45: missing x-payu-signature header returns 401', async () => {
    const res = await request(app)
      .post('/mandates/webhook')
      .send(webhookBody);

    expect(res.status).toBe(401);
    expect(res.body.error).toBe('missing_signature');
  });

  test('V46: wrong HMAC signature returns 403 invalid_signature', async () => {
    const res = await request(app)
      .post('/mandates/webhook')
      .set('x-payu-signature', 'wrong-signature-value')
      .send(webhookBody);

    expect(res.status).toBe(403);
    expect(res.body.error).toBe('invalid_signature');
  });

  test('correct HMAC signature returns 200 and calls handleMandateWebhook', async () => {
    upiMandate.handleMandateWebhook.mockResolvedValue({ mandate_id: 'mandate-1', status: 'approved' });
    const sig = makeWebhookSignature(webhookBody);

    const res = await request(app)
      .post('/mandates/webhook')
      .set('x-payu-signature', sig)
      .send(webhookBody);

    expect(res.status).toBe(200);
    expect(upiMandate.handleMandateWebhook).toHaveBeenCalledWith(webhookBody);
  });

  test('V46: signature computed with different secret is rejected', async () => {
    const sig = makeWebhookSignature(webhookBody, 'wrong-secret');

    const res = await request(app)
      .post('/mandates/webhook')
      .set('x-payu-signature', sig)
      .send(webhookBody);

    expect(res.status).toBe(403);
  });

  test('V46: signature computed over different body is rejected', async () => {
    const sig = makeWebhookSignature({ mandate_id: 'other', status: 'APPROVED' });

    const res = await request(app)
      .post('/mandates/webhook')
      .set('x-payu-signature', sig)
      .send(webhookBody);

    expect(res.status).toBe(403);
  });

  test('handleMandateWebhook error propagates as 500', async () => {
    upiMandate.handleMandateWebhook.mockRejectedValue(new Error('db error'));
    const sig = makeWebhookSignature(webhookBody);

    const res = await request(app)
      .post('/mandates/webhook')
      .set('x-payu-signature', sig)
      .send(webhookBody);

    expect(res.status).toBe(500);
  });
});
