// Feature: continuum-ml-pipelines
// Unit tests for JWT auth middleware and RBAC middleware
// Requirements: 6.2, 6.3, 6.4

'use strict';

process.env.JWT_SECRET = 'test-secret-key-for-unit-tests';
process.env.DB_HOST = 'localhost';

const { signToken, verifyToken } = require('../src/utils/jwt');
const { authenticate } = require('../src/middleware/auth');
const { requireRole } = require('../src/middleware/rbac');

// Helper to create mock req/res/next
function mockReqResNext(headers = {}, user = null) {
  const req = { headers, user };
  const res = {
    _status: null,
    _body: null,
    status(code) { this._status = code; return this; },
    json(body) { this._body = body; return this; },
  };
  const next = jest.fn();
  return { req, res, next };
}

// ─── JWT utils ────────────────────────────────────────────────────────────────

describe('jwt utils', () => {
  test('signToken produces a verifiable token', () => {
    const payload = { worker_id: 'w1', role: 'worker' };
    const token = signToken(payload);
    const decoded = verifyToken(token);
    expect(decoded.worker_id).toBe('w1');
    expect(decoded.role).toBe('worker');
  });

  test('verifyToken throws on tampered token', () => {
    const token = signToken({ worker_id: 'w1', role: 'worker' });
    expect(() => verifyToken(token + 'tampered')).toThrow();
  });

  test('verifyToken throws on expired token', () => {
    const jwt = require('jsonwebtoken');
    // Sign with -1s expiry (already expired)
    const expired = jwt.sign({ worker_id: 'w1', role: 'worker' }, process.env.JWT_SECRET, { expiresIn: -1 });
    expect(() => verifyToken(expired)).toThrow();
  });
});

// ─── authenticate middleware ───────────────────────────────────────────────────

describe('authenticate middleware', () => {
  test('passes with valid token and attaches req.user', () => {
    const token = signToken({ worker_id: 'w1', role: 'worker' });
    const { req, res, next } = mockReqResNext({ authorization: `Bearer ${token}` });
    authenticate(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(req.user.worker_id).toBe('w1');
  });

  test('returns 401 when Authorization header is missing', () => {
    const { req, res, next } = mockReqResNext({});
    authenticate(req, res, next);
    expect(res._status).toBe(401);
    expect(res._body).toEqual({ error: 'invalid_token' });
    expect(next).not.toHaveBeenCalled();
  });

  test('returns 401 when token is invalid', () => {
    const { req, res, next } = mockReqResNext({ authorization: 'Bearer not.a.valid.token' });
    authenticate(req, res, next);
    expect(res._status).toBe(401);
    expect(res._body).toEqual({ error: 'invalid_token' });
  });

  test('returns 401 when token is expired (jwt expiry)', () => {
    const jwt = require('jsonwebtoken');
    const expired = jwt.sign({ worker_id: 'w1', role: 'worker' }, process.env.JWT_SECRET, { expiresIn: -1 });
    const { req, res, next } = mockReqResNext({ authorization: `Bearer ${expired}` });
    authenticate(req, res, next);
    expect(res._status).toBe(401);
    expect(res._body).toEqual({ error: 'invalid_token' });
  });

  test('returns 401 when token iat exceeds 24-hour max lifetime', () => {
    const jwt = require('jsonwebtoken');
    // Manually craft a token with iat > 24h ago (no expiry set so jwt.verify passes)
    const oldIat = Math.floor(Date.now() / 1000) - 86401; // 24h + 1s ago
    const token = jwt.sign(
      { worker_id: 'w1', role: 'worker', iat: oldIat },
      process.env.JWT_SECRET,
      { expiresIn: '48h' } // long expiry so jwt itself doesn't reject
    );
    const { req, res, next } = mockReqResNext({ authorization: `Bearer ${token}` });
    authenticate(req, res, next);
    expect(res._status).toBe(401);
    expect(res._body).toEqual({ error: 'invalid_token' });
  });

  test('returns 401 when Authorization header does not start with Bearer', () => {
    const token = signToken({ worker_id: 'w1', role: 'worker' });
    const { req, res, next } = mockReqResNext({ authorization: `Token ${token}` });
    authenticate(req, res, next);
    expect(res._status).toBe(401);
    expect(res._body).toEqual({ error: 'invalid_token' });
  });
});

// ─── requireRole middleware ────────────────────────────────────────────────────

describe('requireRole middleware', () => {
  test('passes when user has an allowed role', () => {
    const { req, res, next } = mockReqResNext({}, { role: 'worker' });
    requireRole('worker', 'admin')(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('returns 403 when user role is not in allowed list', () => {
    const { req, res, next } = mockReqResNext({}, { role: 'worker' });
    requireRole('admin', 'insurer')(req, res, next);
    expect(res._status).toBe(403);
    expect(res._body).toEqual({ error: 'insufficient_role' });
    expect(next).not.toHaveBeenCalled();
  });

  test('returns 403 when req.user is missing', () => {
    const { req, res, next } = mockReqResNext({}, null);
    requireRole('worker')(req, res, next);
    expect(res._status).toBe(403);
    expect(res._body).toEqual({ error: 'insufficient_role' });
  });

  test('admin role passes admin-only route', () => {
    const { req, res, next } = mockReqResNext({}, { role: 'admin' });
    requireRole('admin')(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('insurer role passes insurer-only route', () => {
    const { req, res, next } = mockReqResNext({}, { role: 'insurer' });
    requireRole('insurer')(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('worker role is rejected from insurer-only route', () => {
    const { req, res, next } = mockReqResNext({}, { role: 'worker' });
    requireRole('insurer')(req, res, next);
    expect(res._status).toBe(403);
    expect(res._body).toEqual({ error: 'insufficient_role' });
  });
});
