// Feature: continuum-ml-pipelines
// JWT verification middleware — Requirements 6.2, 6.3

const { verifyToken } = require('../utils/jwt');

const MAX_TOKEN_LIFETIME_SECONDS = 86400; // 24 hours

/**
 * JWT authentication middleware.
 * Verifies Bearer token from Authorization header.
 * Enforces 24-hour max token lifetime.
 * Attaches decoded payload to req.user on success.
 */
function authenticate(req, res, next) {
  const authHeader = req.headers['authorization'];

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'invalid_token' });
  }

  const token = authHeader.slice(7); // Remove "Bearer " prefix

  let payload;
  try {
    payload = verifyToken(token);
  } catch (err) {
    return res.status(401).json({ error: 'invalid_token' });
  }

  // Enforce 24-hour max token lifetime based on iat claim
  if (!payload.iat || (Date.now() / 1000 - payload.iat) > MAX_TOKEN_LIFETIME_SECONDS) {
    return res.status(401).json({ error: 'invalid_token' });
  }

  req.user = payload;
  next();
}

module.exports = { authenticate };
