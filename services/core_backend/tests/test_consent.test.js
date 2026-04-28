// Tests for /consent routes (DPDP Act compliance)
// Invariants covered:
//   V41 — unknown purpose → HTTP 400 invalid_purpose with list of invalid values
//   V42 — empty purpose list → HTTP 400 invalid_purpose
//   V43 — revoke non-existent/already-revoked consent → HTTP 404

'use strict';

process.env.JWT_SECRET = 'test-secret-consent';
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

const VALID_PURPOSES = [
  'gps_location_tracking',
  'biometric_liveness',
  'proximity_detection',
  'aadhaar_verification',
  'upi_mandate',
  'push_notifications',
];

function workerToken(workerId = 'worker-c1') {
  return signToken({ worker_id: workerId, role: 'worker', platform: 'swiggy', tier: 'silver' });
}

beforeEach(() => jest.clearAllMocks());

// ─── POST /consent ────────────────────────────────────────────────────────────

describe('POST /consent', () => {
  test('V42: empty purposes array returns 400 invalid_purpose', async () => {
    const res = await request(app)
      .post('/consent')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ purposes: [] });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_purpose');
  });

  test('V42: body with neither purpose nor purposes returns 400', async () => {
    const res = await request(app)
      .post('/consent')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_purpose');
  });

  test('V41: unknown single purpose returns 400 with invalid_purposes list', async () => {
    const res = await request(app)
      .post('/consent')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ purpose: 'sell_data_to_advertisers' });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_purpose');
    expect(res.body.invalid_purposes).toContain('sell_data_to_advertisers');
    expect(res.body.valid_purposes).toEqual(expect.arrayContaining(VALID_PURPOSES));
  });

  test('V41: mix of valid and invalid purposes returns 400', async () => {
    const res = await request(app)
      .post('/consent')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ purposes: ['gps_location_tracking', 'not_a_valid_purpose'] });

    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_purpose');
    expect(res.body.invalid_purposes).toContain('not_a_valid_purpose');
    expect(res.body.invalid_purposes).not.toContain('gps_location_tracking');
  });

  test.each(VALID_PURPOSES)(
    'valid purpose "%s" returns 201 and calls DB insert',
    async (purpose) => {
      const fakeRow = {
        worker_id: 'worker-c1',
        purpose,
        template_version: 'v1',
        granted_at: new Date().toISOString(),
        revoked_at: null,
      };
      db.query.mockResolvedValue({ rows: [fakeRow] });

      const res = await request(app)
        .post('/consent')
        .set('Authorization', `Bearer ${workerToken()}`)
        .send({ purpose });

      expect(res.status).toBe(201);
      expect(db.query).toHaveBeenCalledWith(
        expect.stringContaining('INSERT INTO consent_receipts'),
        expect.arrayContaining(['worker-c1', purpose])
      );
    }
  );

  test('granting multiple valid purposes returns array of receipts', async () => {
    const purposes = ['gps_location_tracking', 'push_notifications'];
    db.query
      .mockResolvedValueOnce({ rows: [{ purpose: 'gps_location_tracking' }] })
      .mockResolvedValueOnce({ rows: [{ purpose: 'push_notifications' }] });

    const res = await request(app)
      .post('/consent')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ purposes });

    expect(res.status).toBe(201);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(2);
  });

  test('single purpose returns object, not array', async () => {
    db.query.mockResolvedValue({ rows: [{ purpose: 'upi_mandate', worker_id: 'w1' }] });

    const res = await request(app)
      .post('/consent')
      .set('Authorization', `Bearer ${workerToken()}`)
      .send({ purpose: 'upi_mandate' });

    expect(res.status).toBe(201);
    expect(Array.isArray(res.body)).toBe(false);
    expect(res.body.purpose).toBe('upi_mandate');
  });

  test('unauthenticated request returns 401', async () => {
    const res = await request(app)
      .post('/consent')
      .send({ purpose: 'gps_location_tracking' });

    expect(res.status).toBe(401);
  });
});

// ─── DELETE /consent/:purpose ─────────────────────────────────────────────────

describe('DELETE /consent/:purpose', () => {
  test('V43: revoke non-existent consent returns 404', async () => {
    db.query.mockResolvedValue({ rows: [] });

    const res = await request(app)
      .delete('/consent/gps_location_tracking')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('consent_not_found_or_already_revoked');
  });

  test('V43: revoke already-revoked consent returns 404', async () => {
    // UPDATE returns zero rows when revoked_at is already set
    db.query.mockResolvedValue({ rows: [] });

    const res = await request(app)
      .delete('/consent/biometric_liveness')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(404);
    expect(res.body.error).toBe('consent_not_found_or_already_revoked');
  });

  test('valid revocation returns 200 with revoked receipt', async () => {
    const revokedRow = {
      worker_id: 'worker-c1',
      purpose: 'gps_location_tracking',
      revoked_at: new Date().toISOString(),
    };
    db.query.mockResolvedValue({ rows: [revokedRow] });

    const res = await request(app)
      .delete('/consent/gps_location_tracking')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.revoked_at).toBeDefined();
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('revoked_at = NOW()'),
      expect.arrayContaining(['worker-c1', 'gps_location_tracking'])
    );
  });

  test('worker can only revoke their own consent (worker_id from token)', async () => {
    db.query.mockResolvedValue({ rows: [{ purpose: 'upi_mandate', revoked_at: new Date() }] });

    const res = await request(app)
      .delete('/consent/upi_mandate')
      .set('Authorization', `Bearer ${workerToken('worker-specific')}`);

    expect(res.status).toBe(200);
    // Verify the DB query used the token's worker_id, not a body field
    expect(db.query).toHaveBeenCalledWith(
      expect.any(String),
      expect.arrayContaining(['worker-specific', 'upi_mandate'])
    );
  });
});

// ─── GET /consent ─────────────────────────────────────────────────────────────

describe('GET /consent', () => {
  test('returns list of consent receipts for authenticated worker', async () => {
    const receipts = [
      { purpose: 'gps_location_tracking', granted_at: new Date().toISOString(), revoked_at: null },
      { purpose: 'upi_mandate', granted_at: new Date().toISOString(), revoked_at: null },
    ];
    db.query.mockResolvedValue({ rows: receipts });

    const res = await request(app)
      .get('/consent')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body).toHaveLength(2);
  });

  test('returns empty array when no consents granted', async () => {
    db.query.mockResolvedValue({ rows: [] });

    const res = await request(app)
      .get('/consent')
      .set('Authorization', `Bearer ${workerToken()}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});
