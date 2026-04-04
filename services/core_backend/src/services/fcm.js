// Feature: continuum-ml-pipelines
// FCM client wrapper using firebase-admin SDK
// Requirements: 2.5, 15.5

'use strict';

const admin = require('firebase-admin');
const db = require('../db');

let _app = null;

/**
 * Lazily initialise firebase-admin once.
 * Supports FIREBASE_SERVICE_ACCOUNT_JSON (JSON string) or
 * GOOGLE_APPLICATION_CREDENTIALS (path to service-account file).
 */
function getApp() {
  if (_app) return _app;

  if (admin.apps.length > 0) {
    _app = admin.apps[0];
    return _app;
  }

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    const serviceAccount = JSON.parse(serviceAccountJson);
    _app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    // Fall back to GOOGLE_APPLICATION_CREDENTIALS env var (ADC)
    _app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }

  return _app;
}

/**
 * Send a push notification to a single FCM device token.
 *
 * @param {string} fcmToken - Target device FCM registration token
 * @param {string} title    - Notification title
 * @param {string} body     - Notification body
 * @param {object} [data]   - Optional key-value data payload
 * @returns {Promise<string|null>} FCM message ID on success, null on error
 */
async function sendNotification(fcmToken, title, body, data = {}) {
  try {
    const app = getApp();
    const messaging = admin.messaging(app);

    const message = {
      token: fcmToken,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
    };

    const messageId = await messaging.send(message);
    return messageId;
  } catch (err) {
    console.error('[FCM] sendNotification error:', err.message || err);
    return null;
  }
}

/**
 * Send a premium change notification to a worker via FCM.
 * Only sends if effectiveDate is >= 7 days from now (enforces ≥7-day advance notice).
 *
 * Requirements: 2.5
 *
 * @param {string} workerId      - Worker UUID
 * @param {number} newPremium    - New weekly premium amount (INR)
 * @param {Date|string} effectiveDate - Date the new premium takes effect
 * @returns {Promise<string|null>} FCM message ID, null if not sent or error
 */
async function sendPremiumChangeNotification(workerId, newPremium, effectiveDate) {
  const effectiveDateObj = effectiveDate instanceof Date
    ? effectiveDate
    : new Date(effectiveDate);

  // Enforce ≥7 days advance notice (Requirement 2.5)
  const sevenDaysFromNow = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  if (effectiveDateObj < sevenDaysFromNow) {
    console.warn(
      `[FCM] sendPremiumChangeNotification: effectiveDate ${effectiveDateObj.toISOString()} ` +
      `is less than 7 days from now — notification NOT sent for worker ${workerId}`
    );
    return null;
  }

  // Look up worker's FCM token from DB
  let fcmToken;
  try {
    const result = await db.query(
      'SELECT fcm_token FROM workers WHERE worker_id = $1',
      [workerId]
    );
    if (result.rows.length === 0 || !result.rows[0].fcm_token) {
      console.warn(`[FCM] sendPremiumChangeNotification: no FCM token for worker ${workerId}`);
      return null;
    }
    fcmToken = result.rows[0].fcm_token;
  } catch (err) {
    console.error('[FCM] DB lookup error in sendPremiumChangeNotification:', err.message || err);
    return null;
  }

  const dateStr = effectiveDateObj.toLocaleDateString('en-IN', {
    day: '2-digit', month: 'short', year: 'numeric',
  });

  const title = 'Premium Update';
  const body = `Your weekly premium changes to ₹${newPremium} on ${dateStr}`;

  return sendNotification(fcmToken, title, body, {
    event_type: 'premium_updated',
    worker_id: workerId,
    new_premium: String(newPremium),
    effective_date: effectiveDateObj.toISOString(),
  });
}

module.exports = { sendNotification, sendPremiumChangeNotification };
