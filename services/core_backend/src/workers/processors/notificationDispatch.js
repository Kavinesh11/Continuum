// Feature: continuum-ml-pipelines
// notification_dispatch queue processor
// Requirements: 8.1, 15.1, 15.2, 15.3, 15.4

'use strict';

const db = require('../../db');
const { sendNotification } = require('../../services/fcm');

// Notification type → title/body templates
const NOTIFICATION_TEMPLATES = {
  payout_credited: (data) => ({
    title: 'Payout Credited',
    body: `₹${data.amount} has been credited to your UPI account.`,
  }),
  claim_approved: (data) => ({
    title: 'Claim Approved',
    body: `Your claim has been approved. Payout of ₹${data.estimated_payout || 'N/A'} is being processed.`,
  }),
  claim_rejected: (data) => ({
    title: 'Claim Update',
    body: `Your claim (${data.claim_id}) could not be approved at this time.`,
  }),
  disruption_alert: (data) => ({
    title: 'Disruption Alert',
    body: `A disruption event (${data.event_type || 'weather'}) has been detected in your zone.`,
  }),
  premium_updated: (data) => ({
    title: 'Premium Update',
    body: `Your weekly premium changes to ₹${data.new_premium} effective ${data.effective_date}.`,
  }),
};

/**
 * Process a notification_dispatch job.
 *
 * Job data shape (single worker):
 *   { notification_type, worker_id, fcm_token?, ...payload }
 *
 * Job data shape (zone broadcast for disruption_alert):
 *   { notification_type: 'disruption_alert', zone_id, event_type, ...payload }
 *
 * Requirements: 8.1, 15.1, 15.2, 15.3, 15.4
 *
 * @param {import('bullmq').Job} job
 */
async function processNotificationDispatch(job) {
  const { notification_type, worker_id, zone_id, ...payload } = job.data;

  if (!notification_type) {
    throw new Error(`notification_dispatch: missing notification_type in job ${job.id}`);
  }

  const template = NOTIFICATION_TEMPLATES[notification_type];
  if (!template) {
    throw new Error(`notification_dispatch: unknown notification_type '${notification_type}' in job ${job.id}`);
  }

  const { title, body } = template({ ...payload, notification_type });

  // Zone-wide broadcast for disruption_alert (Requirements 15.3)
  if (notification_type === 'disruption_alert' && zone_id && !worker_id) {
    return broadcastZoneAlert(job.id, zone_id, title, body, payload);
  }

  // Single-worker notification
  if (!worker_id) {
    throw new Error(`notification_dispatch: missing worker_id for non-broadcast job ${job.id}`);
  }

  // Resolve FCM token if not provided directly
  let fcmToken = job.data.fcm_token;
  if (!fcmToken) {
    const result = await db.query(
      `SELECT fcm_token FROM workers WHERE worker_id = $1`,
      [worker_id]
    );
    if (result.rows.length === 0 || !result.rows[0].fcm_token) {
      console.warn(`[notification_dispatch] No FCM token for worker ${worker_id} — skipping job ${job.id}`);
      return { skipped: true, reason: 'no_fcm_token', worker_id };
    }
    fcmToken = result.rows[0].fcm_token;
  }

  const messageId = await sendNotification(fcmToken, title, body, {
    notification_type,
    worker_id,
    ...Object.fromEntries(
      Object.entries(payload).map(([k, v]) => [k, String(v)])
    ),
  });

  if (!messageId) {
    throw new Error(`notification_dispatch: FCM send failed for worker ${worker_id} in job ${job.id}`);
  }

  console.log(`[notification_dispatch] Sent '${notification_type}' to worker ${worker_id}, messageId=${messageId}`);
  return { worker_id, notification_type, message_id: messageId };
}

/**
 * Broadcast a disruption alert to all workers with active policies in a zone.
 * Requirements: 15.3
 */
async function broadcastZoneAlert(jobId, zoneId, title, body, payload) {
  // Fetch all active workers in the zone
  const result = await db.query(
    `SELECT DISTINCT w.worker_id, w.fcm_token
     FROM workers w
     JOIN policies p ON p.worker_id = w.worker_id
     WHERE w.zone_id = $1
       AND p.status = 'active'
       AND w.fcm_token IS NOT NULL`,
    [zoneId]
  );

  if (result.rows.length === 0) {
    console.log(`[notification_dispatch] No active workers in zone ${zoneId} for job ${jobId}`);
    return { zone_id: zoneId, sent: 0 };
  }

  let sent = 0;
  let failed = 0;

  for (const row of result.rows) {
    try {
      const messageId = await sendNotification(row.fcm_token, title, body, {
        notification_type: 'disruption_alert',
        zone_id: zoneId,
        worker_id: row.worker_id,
        ...Object.fromEntries(
          Object.entries(payload).map(([k, v]) => [k, String(v)])
        ),
      });
      if (messageId) {
        sent++;
      } else {
        failed++;
      }
    } catch (err) {
      console.error(`[notification_dispatch] FCM failed for worker ${row.worker_id}:`, err.message);
      failed++;
    }
  }

  console.log(`[notification_dispatch] Zone broadcast for ${zoneId}: sent=${sent}, failed=${failed}`);
  return { zone_id: zoneId, sent, failed };
}

module.exports = { processNotificationDispatch, broadcastZoneAlert };
