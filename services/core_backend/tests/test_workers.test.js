// Tests for /workers routes
// Covers: FCM token update endpoint (I.api, I.fcm)

'use strict';

process.env.JWT_SECRET = 'test-secret-workers';
process.env.DB_HOST = 'localhost';

jest.mock('../src/db', () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));

jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));

const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');
const { signToken } = require('../src/utils/jwt');

function workerToken(workerId = 'worker-w1') {
  return signToken({ worker_id: workerId, role: 'worker', platform: 'swiggy', tier: 'silver' });
}

beforeEach(() => jest.clearAllMocks());

describe('PUT /workers/fcm-token', () => {
  test('valid token update returns 200 with updated:true', async () => {
    db.query.mockResolvedValue({ rows: [] });

    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ fcm_token: 'valid-fcm-token-abc123' });

    expect(res.status).toBe(200);
    expect(res.body.updated).toBe(true);
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE workers SET fcm_token'),
      ['valid-fcm-token-abc123', 'worker-w1']
    );
  });

  test('missing fcm_token returns 400', async () => {
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/fcm_token/);
  });

  test('empty string fcm_token returns 400', async () => {
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ fcm_token: '' });

    expect(res.status).toBe(400);
  });

  test('whitespace-only fcm_token returns 400', async () => {
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ fcm_token: '   ' });

    expect(res.status).toBe(400);
  });

  test('token is trimmed before storing', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${workerToken('worker-trim')}`)
      .send({ fcm_token: '  trimmed-token  ' });

    expect(db.query).toHaveBeenCalledWith(
      expect.any(String),
      ['trimmed-token', 'worker-trim']
    );
  });

  test('unauthenticated request returns 401', async () => {
    const res = await request(app)
      .put('/workers/fcm-token')
      .send({ fcm_token: 'token-abc' });

    expect(res.status).toBe(401);
  });

  test('non-worker role (admin) is denied 403', async () => {
    const adminToken = signToken({ worker_id: 'admin-1', role: 'admin' });
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ fcm_token: 'token-abc' });

    expect(res.status).toBe(403);
  });

  test('uses worker_id from JWT token, not from body', async () => {
    db.query.mockResolvedValue({ rows: [] });

    await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${workerToken('worker-jwt-id')}`)
      .send({ fcm_token: 'my-token', worker_id: 'injected-id' });

    // Should use JWT worker_id, not any body field
    expect(db.query).toHaveBeenCalledWith(
      expect.any(String),
      ['my-token', 'worker-jwt-id']
    );
  });
});
