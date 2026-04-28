// Feature: continuum-ml-pipelines
// Claim management endpoints
// Requirements: 6.1

'use strict';

const express = require('express');
const { v4: uuidv4 } = require('uuid');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');

const router = express.Router();

function toISO(v) {
  return v instanceof Date ? v.toISOString() : v;
}

function mapStatus(status) {
  if (status === 'approved') return 'Approved';
  if (status === 'rejected') return 'Rejected';
  return 'In Review';
}

function progressPct(status) {
  if (status === 'approved') return 1.0;
  if (status === 'rejected') return 1.0;
  if (status === 'fraud_queue') return 0.5;
  return 0.6;
}

/**
 * GET /claims
 * List all claims for the authenticated worker.
 * Admins and insurers can filter by worker_id query param.
 * Requirements: 6.1
 */
router.get('/', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const workerId = req.user.role === 'worker' ? req.user.worker_id : req.query.worker_id;
    if (!workerId) return res.status(400).json({ error: 'worker_id_required' });

    const result = await db.query(
      `SELECT claim_id, event_type, event_timestamp, estimated_payout, status, verification_message, claim_description
       FROM claims
       WHERE worker_id = $1
       ORDER BY submitted_at DESC`,
      [workerId]
    );

    return res.status(200).json(
      result.rows.map((r) => ({
        claim_id: r.claim_id,
        id: r.claim_id,
        title: r.event_type || 'Claim',
        event_date: toISO(r.event_timestamp),
        date: toISO(r.event_timestamp),
        amount: r.estimated_payout != null ? parseFloat(r.estimated_payout) : 0,
        status: mapStatus(r.status),
        verification_message: r.verification_message,
        verificationMessage: r.verification_message,
        claim_description: r.claim_description,
        progress_pct: progressPct(r.status),
        progressPct: progressPct(r.status)
      }))
    );
  } catch (err) {
    next(err);
  }
});

/**
 * POST /claims
 * Create a new claim with optional fields.
 * Workers can only create claims for themselves.
 * Requirements: 6.1
 */
router.post('/', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const {
      claim_id,
      worker_id,
      policy_id,
      event_type,
      event_timestamp,
      event_date,
      date,
      verification_message,
      claim_description,
      amount,
      estimated_payout,
      expectedPayout,
      gps_coordinates,
      zone_id
    } = req.body;

    const resolvedWorkerId = worker_id || req.user.worker_id;
    const resolvedEventTimestamp = event_timestamp || event_date || date || new Date().toISOString();

    const rawPayout = estimated_payout ?? amount ?? expectedPayout;
    const resolvedEstimatedPayout = rawPayout == null ? null : Number.parseFloat(rawPayout);
    const resolvedVerificationMessage = verification_message ?? null;
    const resolvedClaimDescription = claim_description ?? null;

    if (!claim_id || !resolvedWorkerId || !event_type || !resolvedEventTimestamp || !zone_id) {
      return res.status(400).json({ error: 'missing_fields' });
    }

    if (req.user.role === 'worker' && req.user.worker_id !== resolvedWorkerId) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    await db.query(
      `INSERT INTO claims
       (claim_id, worker_id, policy_id, event_type, event_timestamp, gps_lat, gps_lon, zone_id, status, verification_message, claim_description, estimated_payout, submitted_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'processing', $9, $10, $11, NOW())`,
      [
        claim_id,
        resolvedWorkerId,
        policy_id || null,
        event_type,
        resolvedEventTimestamp,
        gps_coordinates?.[0] ?? null,
        gps_coordinates?.[1] ?? null,
        zone_id,
        resolvedVerificationMessage,
        resolvedClaimDescription,
        Number.isFinite(resolvedEstimatedPayout) ? resolvedEstimatedPayout : null
      ]
    );

    return res.status(201).json({
      claim_id,
      id: claim_id,
      worker_id: resolvedWorkerId,
      title: event_type,
      event_date: toISO(resolvedEventTimestamp),
      date: toISO(resolvedEventTimestamp),
      amount: Number.isFinite(resolvedEstimatedPayout) ? resolvedEstimatedPayout : 0,
      estimated_payout: Number.isFinite(resolvedEstimatedPayout) ? resolvedEstimatedPayout : null,
      verification_message: resolvedVerificationMessage,
      verificationMessage: resolvedVerificationMessage,
      claim_description: resolvedClaimDescription,
      status: 'In Review',
      progress_pct: progressPct('processing'),
      progressPct: progressPct('processing'),
      submitted_at: new Date().toISOString()
    });
  } catch (err) {
    next(err);
  }
});

/**
 * PUT /claims/:id
 * Update a claim's status, payout, or metadata.
 * Workers can only update their own claims.
 * Requirements: 6.1
 */
router.put('/:id', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, estimated_payout, verification_message, claim_description } = req.body;

    const existing = await db.query(`SELECT worker_id FROM claims WHERE claim_id = $1`, [id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not_found' });
    if (req.user.role === 'worker' && existing.rows[0].worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    await db.query(
      `UPDATE claims
       SET status = COALESCE($1, status),
           estimated_payout = COALESCE($2, estimated_payout),
           verification_message = COALESCE($3, verification_message),
           claim_description = COALESCE($4, claim_description),
           decided_at = CASE WHEN $1 IN ('approved','rejected') THEN NOW() ELSE decided_at END
         WHERE claim_id = $5`,
      [status, estimated_payout, verification_message, claim_description, id]
    );

    return res.status(200).json({ updated: true, claim_id: id });
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /claims/:id
 * Delete a claim. Workers can only delete their own.
 * Requirements: 6.1
 */
router.delete('/:id', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const existing = await db.query(`SELECT worker_id FROM claims WHERE claim_id = $1`, [id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not_found' });
    if (req.user.role === 'worker' && existing.rows[0].worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    await db.query(`DELETE FROM claims WHERE claim_id = $1`, [id]);
    return res.status(200).json({ deleted: true, claim_id: id });
  } catch (err) {
    next(err);
  }
});

router.get('/:id/status', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `SELECT claim_id, worker_id, policy_id, event_type, event_timestamp,
              gps_lat, gps_lon, zone_id, status, fraud_score,
              estimated_payout, submitted_at, decided_at, verification_message, claim_description
       FROM claims
       WHERE claim_id = $1`,
      [id]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'not_found' });

    const claim = result.rows[0];
    if (req.user.role === 'worker' && claim.worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    const payoutResult = await db.query(
      `SELECT status, disbursed_at, created_at FROM payouts WHERE claim_id = $1 ORDER BY created_at DESC LIMIT 1`,
      [id]
    );

    const payout = payoutResult.rows[0] || null;
    const payoutStatus = payout?.status || null;
    const payoutTime = payout
      ? toISO(payout.disbursed_at || payout.created_at)
      : 'Pending';

    const status = claim.status || 'processing';
    const submitted = toISO(claim.submitted_at) || '';
    const decided = toISO(claim.decided_at) || 'Pending';
    const isApproved = status === 'approved';
    const isRejected = status === 'rejected';
    const isPayoutDone = payoutStatus === 'disbursed';

    const stages = [
      { name: 'SUBMITTED', time: submitted, complete: true },
      { name: 'REVIEW', time: status === 'processing' ? 'In Progress' : decided, complete: true },
      { name: 'APPROVED', time: isApproved ? decided : 'Pending', complete: isApproved },
      { name: 'PAYOUT', time: isApproved ? payoutTime : 'Pending', complete: isApproved && isPayoutDone }
    ];

    return res.status(200).json({
      claim_id: claim.claim_id,
      worker_id: claim.worker_id,
      policy_id: claim.policy_id,
      event_type: claim.event_type,
      event_timestamp: toISO(claim.event_timestamp),
      gps_lat: claim.gps_lat != null ? parseFloat(claim.gps_lat) : null,
      gps_lon: claim.gps_lon != null ? parseFloat(claim.gps_lon) : null,
      zone_id: claim.zone_id,
      status: isRejected ? 'rejected' : (isApproved ? 'approved' : 'processing'),
      fraud_score: claim.fraud_score != null ? parseFloat(claim.fraud_score) : null,
      estimated_payout: claim.estimated_payout != null ? parseFloat(claim.estimated_payout) : null,
      expectedPayout: claim.estimated_payout != null ? parseFloat(claim.estimated_payout) : null,
      submitted_at: submitted,
      decided_at: claim.decided_at ? decided : null,
      stages,
      timeline_text: isPayoutDone ? 'Completed' : (isApproved ? 'Payout in progress' : '2-3 business days'),
      timelineText: isPayoutDone ? 'Completed' : (isApproved ? 'Payout in progress' : '2-3 business days'),
      claim_description: claim.claim_description,
      verification_message: claim.verification_message || 'Verification in progress',
      verificationMessage: claim.verification_message || 'Verification in progress'
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
