'use strict';

const crypto = require('crypto');

/**
 * Generate a human-readable transaction reference shown to the user.
 * Format: CTX-YYYYMMDD-XXXXXX  (6 uppercase hex chars = 16M combinations per day)
 */
function generateTxRef() {
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const suffix = crypto.randomBytes(3).toString('hex').toUpperCase();
  return `CTX-${date}-${suffix}`;
}

/**
 * Build the canonical payload string used for HMAC signing.
 * Field order is fixed — changing it breaks existing hashes.
 */
function _buildPayload(fields) {
  return [
    fields.worker_id,
    fields.claim_id,
    fields.policy_id,
    String(fields.amount),
    fields.zone_id,
    fields.tier,
    fields.tx_ref,
    fields.salt,
  ].join('|');
}

/**
 * Generate a per-transaction HMAC-SHA-256 integrity hash.
 * The salt is a random 32-byte hex string generated at payout creation time.
 * The TRANSACTION_HMAC_SECRET env var is the server-side signing key.
 *
 * @param {{worker_id, claim_id, policy_id, amount, zone_id, tier, tx_ref}} payoutFields
 * @param {string} salt — crypto.randomBytes(32).toString('hex')
 * @returns {string} hex-encoded HMAC
 */
function generateTxHash(payoutFields, salt) {
  const secret = process.env.TRANSACTION_HMAC_SECRET;
  if (!secret) throw new Error('TRANSACTION_HMAC_SECRET env var is not set');

  const payload = _buildPayload({ ...payoutFields, salt });
  return crypto.createHmac('sha256', secret).update(payload).digest('hex');
}

/**
 * Verify a stored transaction hash.
 * Uses timing-safe comparison to prevent timing attacks.
 *
 * @returns {boolean} true if the hash matches (record is untampered)
 */
function verifyTxHash(payoutFields, salt, storedHash) {
  const computed = generateTxHash(payoutFields, salt);
  try {
    return crypto.timingSafeEqual(
      Buffer.from(computed, 'hex'),
      Buffer.from(storedHash, 'hex')
    );
  } catch {
    return false;
  }
}

/**
 * Generate a fresh salt (call once per payout at creation time, store result in DB).
 */
function generateSalt() {
  return crypto.randomBytes(32).toString('hex');
}

module.exports = { generateTxRef, generateTxHash, verifyTxHash, generateSalt };
