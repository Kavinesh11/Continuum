// Feature: continuum-ml-pipelines
// JWT helper utilities for signing and verifying tokens

const jwt = require('jsonwebtoken');

/**
 * Sign a JWT token with 24-hour expiry.
 * @param {object} payload - Data to encode in the token
 * @returns {string} Signed JWT token
 */
function signToken(payload) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET environment variable is not set');
  }
  return jwt.sign(payload, secret, { expiresIn: '24h' });
}

/**
 * Verify a JWT token and return the decoded payload.
 * Throws on invalid or expired tokens.
 * @param {string} token - JWT token to verify
 * @returns {object} Decoded payload
 */
function verifyToken(token) {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET environment variable is not set');
  }
  return jwt.verify(token, secret);
}

module.exports = { signToken, verifyToken };
