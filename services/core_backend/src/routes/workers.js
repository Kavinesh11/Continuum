// Feature: continuum-ml-pipelines
// Workers endpoints — FCM token registration
// Requirements: 15.5

'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');

const router = express.Router();

function canAccess(req, workerId) {
  return req.user.role !== 'worker' || req.user.worker_id === workerId;
}

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

/**
 * GET /workers/:id
 * Get worker profile including stats and claim history.
 * Workers can only access their own profile; admins/insurers can view any.
 * Requirements: 15.5
 */
router.get('/:id', authenticate, requireRole('worker', 'admin', 'insurer'), async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!canAccess(req, id)) return res.status(403).json({ error: 'insufficient_role' });

    const workerQ = db.query(
      `SELECT worker_id, platform, tier, zone_id, upi_id, registered_at,
              full_name, city, phone, emergency_contact
       FROM workers
       WHERE worker_id = $1`,
      [id]
    );

    const statsQ = db.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'approved')::int AS claims_approved_count
       FROM claims
       WHERE worker_id = $1`,
      [id]
    );

    const protectedQ = db.query(
      `SELECT COALESCE(SUM(amount), 0)::float AS total_protected_amount
       FROM payouts
       WHERE worker_id = $1 AND status = 'disbursed'`,
      [id]
    );

    const historyQ = db.query(
      `SELECT claim_id, event_type, status, submitted_at
       FROM claims
       WHERE worker_id = $1
       ORDER BY submitted_at DESC
       LIMIT 10`,
      [id]
    );

    const policyQ = db.query(
      `SELECT weekly_premium, billing_cycle_end
       FROM policies
       WHERE worker_id = $1 AND status = 'active'
       ORDER BY effective_date DESC
       LIMIT 1`,
      [id]
    );

    const [workerR, statsR, protectedR, historyR, policyR] = await Promise.all([
      workerQ,
      statsQ,
      protectedQ,
      historyQ,
      policyQ,
    ]);

    if (workerR.rows.length === 0) return res.status(404).json({ error: 'not_found' });

    const w = workerR.rows[0];
    const s = statsR.rows[0] || {};
    const p = policyR.rows[0];
    const totalProtected = protectedR.rows[0]?.total_protected_amount || 0;

    return res.status(200).json({
      worker_id: w.worker_id,
      full_name: w.full_name || w.worker_id,
      city: w.city || '',
      phone: w.phone || '',
      platform: w.platform || '',
      zone_id: w.zone_id || '',
      tier: w.tier || 'silver',
      upi_id: w.upi_id || '',
      registered_at: w.registered_at instanceof Date ? w.registered_at.toISOString() : w.registered_at,
      emergency_contact: w.emergency_contact || null,
      claims_approved_count: s?.claims_approved_count || 0,
      total_protected_amount: totalProtected,
      weekly_premium: p?.weekly_premium ? parseFloat(p.weekly_premium) : null,
      next_renewal: p?.billing_cycle_end instanceof Date
        ? p.billing_cycle_end.toISOString()
        : p?.billing_cycle_end || null,
      recent_claims: historyR.rows.map((c) => ({
        claim_id: c.claim_id,
        event_type: c.event_type,
        status: c.status,
        submitted_at: c.submitted_at instanceof Date ? c.submitted_at.toISOString() : c.submitted_at,
      })),
      member_since: w.registered_at instanceof Date ? w.registered_at.toISOString() : w.registered_at,
      stats: {
        total_protected_amount: totalProtected,
        claims_approved_count: s?.claims_approved_count || 0,
        weekly_order_count: 0,
        weekly_earnings: 0,
        completion_rate: 0
      },
      location: {
        current_address: '',
        current_zone: w.zone_id || '',
        ping_count: 0
      },
      recent_history: historyR.rows.map((r) => ({
        incident: r.event_type || 'Incident',
        status: r.status || 'processing',
        submitted_at: r.submitted_at instanceof Date ? r.submitted_at.toISOString() : r.submitted_at,
        detail: `Claim ${r.claim_id}`
      }))
    });
  } catch (err) {
    next(err);
  }
});

/**
 * PUT /workers/:id
 * Update worker profile information.
 * Workers can only update their own profile; admins can update any.
 * Requirements: 15.5
 */
router.put('/:id', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!canAccess(req, id)) {
      return res.status(403).json({ error: 'insufficient_role' });
    }

    const {
      full_name,
      city,
      phone,
      platform,
      zone_id,
      tier,
      emergency_contact
    } = req.body;

    const updates = [];
    const values = [id];
    let paramIndex = 2;

    if (full_name !== undefined && full_name !== null) {
      updates.push(`full_name = $${paramIndex}`);
      values.push(full_name);
      paramIndex++;
    }
    if (city !== undefined && city !== null) {
      updates.push(`city = $${paramIndex}`);
      values.push(city);
      paramIndex++;
    }
    if (phone !== undefined && phone !== null) {
      updates.push(`phone = $${paramIndex}`);
      values.push(phone);
      paramIndex++;
    }
    if (platform !== undefined && platform !== null) {
      updates.push(`platform = $${paramIndex}`);
      values.push(platform);
      paramIndex++;
    }
    if (zone_id !== undefined && zone_id !== null) {
      updates.push(`zone_id = $${paramIndex}`);
      values.push(zone_id);
      paramIndex++;
    }
    if (tier !== undefined && tier !== null) {
      updates.push(`tier = $${paramIndex}`);
      values.push(tier);
      paramIndex++;
    }
    if (emergency_contact !== undefined && emergency_contact !== null) {
      updates.push(`emergency_contact = $${paramIndex}`);
      values.push(emergency_contact);
      paramIndex++;
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'no_fields_to_update' });
    }

    const updateQuery = `UPDATE workers SET ${updates.join(', ')} WHERE worker_id = $1 RETURNING *`;
    const result = await db.query(updateQuery, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found' });
    }

    const w = result.rows[0];
    return res.status(200).json({
      worker_id: w.worker_id,
      full_name: w.full_name || '',
      city: w.city || '',
      phone: w.phone || '',
      platform: w.platform || '',
      zone_id: w.zone_id || '',
      tier: w.tier || '',
      emergency_contact: w.emergency_contact || null,
      updated: true,
    });
  } catch (err) {
    next(err);
  }
});

router.post('/:id/fcm-token', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { id } = req.params;
    const { fcm_token } = req.body;
    if (!canAccess(req, id)) return res.status(403).json({ error: 'insufficient_role' });
    if (!fcm_token || typeof fcm_token !== 'string' || fcm_token.trim() === '') {
      return res.status(400).json({ error: 'fcm_token is required' });
    }

    await db.query(`UPDATE workers SET fcm_token = $1 WHERE worker_id = $2`, [fcm_token.trim(), id]);
    return res.status(200).json({ updated: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
