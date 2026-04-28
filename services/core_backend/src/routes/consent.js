'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');

const router = express.Router();

const VALID_PURPOSES = [
  'gps_location_tracking',
  'biometric_liveness',
  'proximity_detection',
  'aadhaar_verification',
  'upi_mandate',
  'push_notifications',
];

/**
 * POST /consent
 * Grant consent for one or more purposes. DPDP Act §6 — freely given, specific, informed.
 * Body: { purpose: string } OR { purposes: string[], consent_version: string }
 */
router.post('/', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { purpose, purposes, template_version, consent_version } = req.body;
    const worker_id = req.user.worker_id;
    const version = consent_version || template_version || 'v1';

    const purposeList = purposes || (purpose ? [purpose] : []);

    const invalid = purposeList.filter(p => !VALID_PURPOSES.includes(p));
    if (purposeList.length === 0 || invalid.length > 0) {
      return res.status(400).json({
        error: 'invalid_purpose',
        invalid_purposes: invalid,
        valid_purposes: VALID_PURPOSES,
      });
    }

    const results = [];
    for (const p of purposeList) {
      const result = await db.query(
        `INSERT INTO consent_receipts (worker_id, purpose, template_version, granted_at, revoked_at)
         VALUES ($1, $2, $3, NOW(), NULL)
         ON CONFLICT (worker_id, purpose) DO UPDATE SET
           granted_at = NOW(),
           revoked_at = NULL,
           template_version = EXCLUDED.template_version
         RETURNING *`,
        [worker_id, p, version]
      );
      results.push(result.rows[0]);
    }

    return res.status(201).json(results.length === 1 ? results[0] : results);
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /consent/:purpose
 * Revoke consent for a specific purpose. DPDP Act §6 — right to withdraw.
 */
router.delete('/:purpose', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { purpose } = req.params;
    const worker_id = req.user.worker_id;

    const result = await db.query(
      `UPDATE consent_receipts SET revoked_at = NOW()
       WHERE worker_id = $1 AND purpose = $2 AND revoked_at IS NULL
       RETURNING *`,
      [worker_id, purpose]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'consent_not_found_or_already_revoked' });
    }

    return res.status(200).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /consent
 * List all consent receipts for the authenticated worker.
 */
router.get('/', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const worker_id = req.user.worker_id;
    const result = await db.query(
      `SELECT * FROM consent_receipts WHERE worker_id = $1 ORDER BY granted_at DESC`,
      [worker_id]
    );
    return res.status(200).json(result.rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
