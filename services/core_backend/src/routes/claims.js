// Feature: continuum-ml-pipelines
// Claim status endpoint
// Requirements: 6.1

'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');

const router = express.Router();

/**
 * GET /claims/:id/status
 * Returns current claim status + fraud_score for the authenticated worker.
 * Workers can only access their own claims.
 * Requirements: 6.1
 */
router.get('/:id/status', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await db.query(
      `SELECT claim_id, worker_id, policy_id, event_type, event_timestamp,
              gps_lat, gps_lon, zone_id, status, fraud_score,
              estimated_payout, submitted_at, decided_at
       FROM claims
       WHERE claim_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found' });
    }

    const claim = result.rows[0];

    // Workers can only access their own claims (Requirements 6.1)
    if (req.user.role === 'worker' && claim.worker_id !== req.user.worker_id) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    return res.status(200).json({
      claim_id:         claim.claim_id,
      worker_id:        claim.worker_id,
      policy_id:        claim.policy_id,
      event_type:       claim.event_type,
      event_timestamp:  claim.event_timestamp instanceof Date
        ? claim.event_timestamp.toISOString()
        : claim.event_timestamp,
      gps_lat:          claim.gps_lat != null ? parseFloat(claim.gps_lat) : null,
      gps_lon:          claim.gps_lon != null ? parseFloat(claim.gps_lon) : null,
      zone_id:          claim.zone_id,
      status:           claim.status,
      fraud_score:      claim.fraud_score != null ? parseFloat(claim.fraud_score) : null,
      estimated_payout: claim.estimated_payout != null ? parseFloat(claim.estimated_payout) : null,
      submitted_at:     claim.submitted_at instanceof Date
        ? claim.submitted_at.toISOString()
        : claim.submitted_at,
      decided_at:       claim.decided_at
        ? (claim.decided_at instanceof Date
          ? claim.decided_at.toISOString()
          : claim.decided_at)
        : null,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
