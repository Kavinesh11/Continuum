// Feature: continuum-ml-pipelines
// Payout endpoints with optimistic concurrency control
// Requirements: 6.1, 9.5

'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');
const { incrementPayoutsDisbursed } = require('../services/metrics');
const { generateTxRef, generateTxHash, generateSalt } = require('../utils/txIntegrity');

const router = express.Router();

const PAYOUT_DEDUP_WINDOW_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

/**
 * createPayoutWithOCC — Insert a payout record using optimistic concurrency control.
 *
 * Pattern (Requirements 9.5):
 *   1. Begin transaction
 *   2. SELECT existing payout for worker+claim in 7-day window FOR UPDATE
 *   3. If exists → ROLLBACK → return null (caller returns HTTP 409)
 *   4. INSERT new payout record
 *   5. COMMIT
 *
 * @param {object} payoutData
 * @param {string} payoutData.worker_id
 * @param {string} payoutData.claim_id
 * @param {string} payoutData.policy_id
 * @param {number} payoutData.amount
 * @param {object} payoutData.oracle_votes  - JSONB
 * @param {string} payoutData.zone_id
 * @param {string} payoutData.tier
 * @param {string|null} [payoutData.payu_txn_ref]
 * @param {string} [payoutData.status]      - defaults to 'pending'
 * @returns {Promise<object|null>} inserted payout row, or null on duplicate
 */
async function createPayoutWithOCC(payoutData) {
  const client = await db.connect();
  try {
    await client.query('BEGIN');

    const windowStart = new Date(Date.now() - PAYOUT_DEDUP_WINDOW_MS);

    // Check for existing payout in 7-day window (SELECT ... FOR UPDATE)
    const existing = await client.query(
      `SELECT payout_id FROM payouts
       WHERE worker_id = $1
         AND claim_id  = $2
         AND created_at >= $3
       FOR UPDATE`,
      [payoutData.worker_id, payoutData.claim_id, windowStart]
    );

    if (existing.rows.length > 0) {
      await client.query('ROLLBACK');
      return null; // caller returns HTTP 409
    }

    const payoutId = uuidv4();
    const status = payoutData.status || 'pending';

    // Generate human-readable reference shown to the user, plus a salted HMAC
    // for DB-level tamper detection. Salt is random per payout; hash covers all
    // financial fields so any post-insert modification is detectable.
    const txRef = generateTxRef();
    const txSalt = generateSalt();
    const txHash = generateTxHash(
      {
        worker_id: payoutData.worker_id,
        claim_id: payoutData.claim_id,
        policy_id: payoutData.policy_id,
        amount: payoutData.amount,
        zone_id: payoutData.zone_id,
        tier: payoutData.tier,
        tx_ref: txRef,
      },
      txSalt
    );

    const result = await client.query(
      `INSERT INTO payouts
        (payout_id, worker_id, claim_id, policy_id, amount,
        oracle_votes, zone_id, tier, payu_txn_ref, status,
        tx_ref, tx_salt, tx_hash, disbursed_at, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
            CASE WHEN $10 = 'disbursed' THEN NOW() ELSE NULL END,
            NOW())
      RETURNING *`,
      [
        payoutId,
        payoutData.worker_id,
        payoutData.claim_id,
        payoutData.policy_id,
        payoutData.amount,
        JSON.stringify(payoutData.oracle_votes || []),
        payoutData.zone_id,
        payoutData.tier,
        payoutData.payu_txn_ref || null,
        status,
        txRef,
        txSalt,
        txHash,
      ]
    );

    await client.query('COMMIT');

    // Track disbursed payouts metric (Requirements 16.4)
    if (result.rows[0].status === 'disbursed') {
      incrementPayoutsDisbursed();
    }

    return result.rows[0];
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/**
 * GET /payouts
 * Returns payout history for the authenticated worker (own records only).
 * Requirements: 6.1
 */
router.get('/', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { worker_id } = req.user;

    const result = await db.query(
      `SELECT payout_id, worker_id, claim_id, policy_id, amount,
              oracle_votes, zone_id, tier, payu_txn_ref,
              status, tx_ref, disbursed_at, created_at
       FROM payouts
       WHERE worker_id = $1
       ORDER BY created_at DESC`,
      [worker_id]
    );

    // tx_salt and tx_hash are internal integrity fields — never expose them to clients.
    const payouts = result.rows.map(row => ({
      payout_id:    row.payout_id,
      worker_id:    row.worker_id,
      claim_id:     row.claim_id,
      policy_id:    row.policy_id,
      amount:       parseFloat(row.amount),
      oracle_votes: row.oracle_votes,
      zone_id:      row.zone_id,
      tier:         row.tier,
      payu_txn_ref: row.payu_txn_ref || null,
      status:       row.status,
      tx_ref:       row.tx_ref || null,
      disbursed_at: row.disbursed_at
        ? (row.disbursed_at instanceof Date
          ? row.disbursed_at.toISOString()
          : row.disbursed_at)
        : null,
      created_at: row.created_at instanceof Date
        ? row.created_at.toISOString()
        : row.created_at,
    }));

    return res.status(200).json(payouts);
  } catch (err) {
    next(err);
  }
});

router.post('/', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const {
      worker_id,
      claim_id,
      policy_id,
      amount,
      oracle_votes,
      zone_id,
      tier,
      payu_txn_ref,
      status
    } = req.body;

    if (!worker_id || !claim_id || !policy_id || amount == null || !zone_id || !tier) {
      return res.status(400).json({ error: 'missing_fields' });
    }

    if (req.user.role === 'worker' && req.user.worker_id !== worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    const created = await createPayoutWithOCC({
      worker_id, claim_id, policy_id, amount, oracle_votes, zone_id, tier, payu_txn_ref, status
    });

    if (!created) return res.status(409).json({ error: 'duplicate_payout' });
    return res.status(201).json(created);
  } catch (err) {
    next(err);
  }
});

router.put('/:id', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, payu_txn_ref } = req.body;

    const existing = await db.query(`SELECT worker_id FROM payouts WHERE payout_id = $1`, [id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not_found' });
    if (req.user.role === 'worker' && existing.rows[0].worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    await db.query(
      `UPDATE payouts
       SET status = COALESCE($1, status),
           payu_txn_ref = COALESCE($2, payu_txn_ref),
           disbursed_at = CASE WHEN COALESCE($1, status) = 'disbursed' THEN NOW() ELSE disbursed_at END
       WHERE payout_id = $3`,
      [status, payu_txn_ref, id]
    );

    return res.status(200).json({ updated: true, payout_id: id });
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const existing = await db.query(`SELECT worker_id FROM payouts WHERE payout_id = $1`, [id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not_found' });
    if (req.user.role === 'worker' && existing.rows[0].worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    await db.query(`DELETE FROM payouts WHERE payout_id = $1`, [id]);
    return res.status(200).json({ deleted: true, payout_id: id });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
module.exports.createPayoutWithOCC = createPayoutWithOCC;
