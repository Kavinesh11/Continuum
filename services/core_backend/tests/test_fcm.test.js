// Feature: continuum-ml-pipelines
// Unit tests for FCM service and PUT /workers/fcm-token endpoint
// Requirements: 2.5, 15.5

'use strict';

// ── Mock firebase-admin before any require of the FCM service ──────────────
jest.mock('firebase-admin', () => {
  const mockSend = jest.fn();
  const mockMessaging = jest.fn(() => ({ send: mockSend }));
  const mockCert = jest.fn(sa => ({ type: 'cert', sa }));
  const mockApplicationDefault = jest.fn(() => ({ type: 'adc' }));

  return {
    apps: [],
    initializeApp: jest.fn(() => ({})),
    messaging: mockMessaging,
    credential: {
      cert: mockCert,
      applicationDefault: mockApplicationDefault,
    },
    _mockSend: mockSend,
    _mockMessaging: mockMessaging,
  };
});

// ── Mock db ────────────────────────────────────────────────────────────────
jest.mock('../src/db', () => ({
  query: jest.fn(),
}));

const request = require('supertest');
const app = require('../src/app');
const db = require('../src/db');
const admin = require('firebase-admin');
const { signToken } = require('../src/utils/jwt');

// Helper: create a valid worker JWT
function workerToken(workerId = 'worker-uuid-1') {
  process.env.JWT_SECRET = 'test-secret';
  return signToken({ worker_id: workerId, role: 'worker' });
}

// ── PUT /workers/fcm-token ─────────────────────────────────────────────────

describe('PUT /workers/fcm-token', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.JWT_SECRET = 'test-secret';
  });

  test('returns 200 and upserts token for authenticated worker', async () => {
    db.query.mockResolvedValueOnce({ rows: [], rowCount: 1 });

    const token = workerToken('worker-abc');
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${token}`)
      .send({ fcm_token: 'device-token-xyz' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ updated: true });

    // Verify DB was called with correct args
    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE workers SET fcm_token'),
      ['device-token-xyz', 'worker-abc']
    );
  });

  test('returns 401 without auth token', async () => {
    const res = await request(app)
      .put('/workers/fcm-token')
      .send({ fcm_token: 'device-token-xyz' });

    expect(res.status).toBe(401);
  });

  test('returns 400 when fcm_token is missing', async () => {
    const token = workerToken();
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/fcm_token/i);
  });

  test('returns 400 when fcm_token is empty string', async () => {
    const token = workerToken();
    const res = await request(app)
      .put('/workers/fcm-token')
      .set('Authorization', `Bearer ${token}`)
      .send({ fcm_token: '   ' });

    expect(res.status).toBe(400);
  });
});

// ── sendPremiumChangeNotification ──────────────────────────────────────────

describe('sendPremiumChangeNotification', () => {
  let sendPremiumChangeNotification;

  beforeEach(() => {
    jest.clearAllMocks();
    jest.resetModules();

    // Re-mock firebase-admin for each test to reset apps array
    jest.mock('firebase-admin', () => {
      const mockSend = jest.fn().mockResolvedValue('msg-id-123');
      const mockMessaging = jest.fn(() => ({ send: mockSend }));
      return {
        apps: [],
        initializeApp: jest.fn(() => ({})),
        messaging: mockMessaging,
        credential: {
          cert: jest.fn(sa => ({ type: 'cert', sa })),
          applicationDefault: jest.fn(() => ({ type: 'adc' })),
        },
        _mockSend: mockSend,
      };
    });

    jest.mock('../src/db', () => ({ query: jest.fn() }));

    process.env.JWT_SECRET = 'test-secret';
    process.env.FIREBASE_SERVICE_ACCOUNT_JSON = JSON.stringify({
      type: 'service_account',
      project_id: 'test',
      private_key_id: 'key-id',
      private_key: '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4PAtEsHAFOCMFCNFBMBBFMBBFMB\n-----END RSA PRIVATE KEY-----\n',
      client_email: 'test@test.iam.gserviceaccount.com',
      client_id: '123',
      auth_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_uri: 'https://oauth2.googleapis.com/token',
    });

    ({ sendPremiumChangeNotification } = require('../src/services/fcm'));
  });

  afterEach(() => {
    jest.resetModules();
  });

  test('sends notification when effectiveDate >= 7 days from now', async () => {
    const dbModule = require('../src/db');
    dbModule.query.mockResolvedValueOnce({
      rows: [{ fcm_token: 'worker-device-token' }],
    });

    const adminModule = require('firebase-admin');
    adminModule._mockSend.mockResolvedValueOnce('msg-id-ok');

    const futureDate = new Date(Date.now() + 8 * 24 * 60 * 60 * 1000); // 8 days from now
    const result = await sendPremiumChangeNotification('worker-1', 199, futureDate);

    expect(result).toBe('msg-id-ok');
    expect(adminModule.messaging).toHaveBeenCalled();
    const sentMessage = adminModule._mockSend.mock.calls[0][0];
    expect(sentMessage.notification.title).toBe('Premium Update');
    expect(sentMessage.notification.body).toContain('₹199');
    expect(sentMessage.token).toBe('worker-device-token');
  });

  test('does NOT send notification when effectiveDate < 7 days from now', async () => {
    const dbModule = require('../src/db');
    const adminModule = require('firebase-admin');

    const nearDate = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // 3 days from now
    const result = await sendPremiumChangeNotification('worker-1', 199, nearDate);

    expect(result).toBeNull();
    expect(dbModule.query).not.toHaveBeenCalled();
    expect(adminModule._mockSend).not.toHaveBeenCalled();
  });

  test('handles missing fcm_token gracefully (worker not found)', async () => {
    const dbModule = require('../src/db');
    dbModule.query.mockResolvedValueOnce({ rows: [] }); // worker not found

    const adminModule = require('firebase-admin');

    const futureDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000);
    const result = await sendPremiumChangeNotification('unknown-worker', 199, futureDate);

    expect(result).toBeNull();
    expect(adminModule._mockSend).not.toHaveBeenCalled();
  });

  test('handles worker with null fcm_token gracefully', async () => {
    const dbModule = require('../src/db');
    dbModule.query.mockResolvedValueOnce({ rows: [{ fcm_token: null }] });

    const adminModule = require('firebase-admin');

    const futureDate = new Date(Date.now() + 10 * 24 * 60 * 60 * 1000);
    const result = await sendPremiumChangeNotification('worker-no-token', 199, futureDate);

    expect(result).toBeNull();
    expect(adminModule._mockSend).not.toHaveBeenCalled();
  });
});

// ── sendNotification error handling ───────────────────────────────────────

describe('sendNotification', () => {
  let sendNotification;

  beforeEach(() => {
    jest.clearAllMocks();
    jest.resetModules();

    jest.mock('firebase-admin', () => {
      const mockSend = jest.fn();
      const mockMessaging = jest.fn(() => ({ send: mockSend }));
      return {
        apps: [],
        initializeApp: jest.fn(() => ({})),
        messaging: mockMessaging,
        credential: {
          cert: jest.fn(() => ({ type: 'cert' })),
          applicationDefault: jest.fn(() => ({ type: 'adc' })),
        },
        _mockSend: mockSend,
      };
    });

    jest.mock('../src/db', () => ({ query: jest.fn() }));

    process.env.FIREBASE_SERVICE_ACCOUNT_JSON = JSON.stringify({
      type: 'service_account',
      project_id: 'test',
    });

    ({ sendNotification } = require('../src/services/fcm'));
  });

  afterEach(() => {
    jest.resetModules();
  });

  test('handles FCM error gracefully — logs and returns null, does not throw', async () => {
    const adminModule = require('firebase-admin');
    adminModule._mockSend.mockRejectedValueOnce(new Error('FCM quota exceeded'));

    const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

    const result = await sendNotification('bad-token', 'Title', 'Body', {});

    expect(result).toBeNull();
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('[FCM]'),
      expect.stringContaining('FCM quota exceeded')
    );

    consoleSpy.mockRestore();
  });
});
