'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');

const router = express.Router();

/**
 * POST /admin/breach
 * Report a data breach per DPDP Act §8 — 72-hour notification requirement.
 * RBAC-gated to admin role only.
 */
router.post('/breach', authenticate, requireRole('admin'), async (req, res, next) => {
  try {
    const { breach_type, description, affected_data_principals, severity } = req.body;

    if (!breach_type || !description) {
      return res.status(400).json({ error: 'missing_fields', required: ['breach_type', 'description'] });
    }

    const result = await db.query(
      `INSERT INTO agent_audit_log (agent_name, action, payload)
       VALUES ('breach_reporter', 'breach_reported', $1)
       RETURNING log_id, logged_at`,
      [JSON.stringify({
        breach_type,
        description,
        affected_data_principals: affected_data_principals || 'unknown',
        severity: severity || 'high',
        reported_by: req.user.worker_id || req.user.admin_id,
        reported_at: new Date().toISOString(),
      })]
    );

    console.warn('[BREACH REPORTED]', {
      log_id: result.rows[0].log_id,
      breach_type,
      severity,
    });

    return res.status(201).json({
      breach_id: result.rows[0].log_id,
      reported_at: result.rows[0].logged_at,
      message: 'Breach recorded. DPDP Act requires notification to DPB within 72 hours.',
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
