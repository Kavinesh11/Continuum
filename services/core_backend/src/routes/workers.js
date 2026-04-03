// Feature: continuum-ml-pipelines
// Workers endpoints — FCM token registration
// Requirements: 15.5

'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');

const router = express.Router();

/**
 * PUT /workers/fcm-token
 * Upsert the FCM device token for the authenticated worker.
 *
 * Auth: JWT required (worker role)
 * Body: { fcm_token: string }
 * Response 200: { updated: true }
 *
 * Requirements: 15.5
 */
router.put('/fcm-token', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { fcm_token } = req.body;

    if (!fcm_token || typeof fcm_token !== 'string' || fcm_token.trim() === '') {
      return res.status(400).json({ error: 'fcm_token is required' });
    }

    const { worker_id } = req.user;

    await db.query(
      `UPDATE workers SET fcm_token = $1 WHERE worker_id = $2`,
      [fcm_token.trim(), worker_id]
    );

    return res.status(200).json({ updated: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
