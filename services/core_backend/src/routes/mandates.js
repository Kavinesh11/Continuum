// Mandate management and webhook endpoints
// Requirements: G2 — UPI eNACH mandate lifecycle

'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const {
  createMandate,
  handleMandateWebhook,
  getMandateByPolicy,
} = require('../services/upi_mandate');

const router = express.Router();

/**
 * POST /mandates
 * Create a new UPI eNACH mandate for the worker's policy.
 */
router.post('/', authenticate, requireRole('worker'), async (req, res, next) => {
  try {
    const { policy_id, upi_id, max_amount } = req.body;

    if (!policy_id || !upi_id || !max_amount) {
      return res.status(400).json({ error: 'missing_fields' });
    }

    const result = await createMandate(req.user.worker_id, policy_id, upi_id, max_amount);
    return res.status(201).json(result);
  } catch (err) {
    next(err);
  }
});

/**
 * GET /mandates/policy/:policyId
 * Get the active mandate for a given policy.
 */
router.get('/policy/:policyId', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const mandate = await getMandateByPolicy(req.params.policyId);
    if (!mandate) {
      return res.status(404).json({ error: 'no_active_mandate' });
    }
    return res.status(200).json(mandate);
  } catch (err) {
    next(err);
  }
});

/**
 * POST /mandates/webhook
 * PayU eNACH mandate state transition webhook.
 * No auth — secured by webhook signature verification (HMAC).
 */
router.post('/webhook', async (req, res, next) => {
  try {
    const hmacHeader = req.headers['x-payu-signature'];
    if (!hmacHeader) {
      return res.status(401).json({ error: 'missing_signature' });
    }

    const crypto = require('crypto');
    const secret = process.env.PAYU_WEBHOOK_SECRET || '';
    const expected = crypto
      .createHmac('sha256', secret)
      .update(JSON.stringify(req.body))
      .digest('hex');

    if (hmacHeader !== expected) {
      return res.status(403).json({ error: 'invalid_signature' });
    }

    const result = await handleMandateWebhook(req.body);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
