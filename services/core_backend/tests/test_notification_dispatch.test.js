// Feature: continuum-ml-pipelines
// Unit tests for notification_dispatch BullMQ processor and FCM dispatch
// Requirements: 15.1, 15.2, 15.3, 15.4

'use strict';

// ─── Mocks ────────────────────────────────────────────────────────────────────

jest.mock('../src/db', () => ({ query: jest.fn() }));
jest.mock('../src/services/fcm', () => ({
  sendNotification: jest.fn(),
}));

const db = require('../src/db');
const { sendNotification } = require('../src/services/fcm');
const {
  processNotificationDispatch,
  broadcastZoneAlert,
} = require('../src/workers/processors/notificationDispatch');

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeJob(data, id = 'job-1') {
  return { id, data };
}

// ─── processNotificationDispatch — single-worker notifications ────────────────

describe('processNotificationDispatch — single-worker notifications', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('throws when notification_type is missing', async () => {
    const job = makeJob({ worker_id: 'w1' });
    await expect(processNotificationDispatch(job)).rejects.toThrow(/missing notification_type/);
  });

  test('throws when notification_type is unknown', async () => {
    const job = makeJob({ notification_type: 'unknown_event', worker_id: 'w1' });
    await expect(processNotificationDispatch(job)).rejects.toThrow(/unknown notification_type/);
  });

  test('throws when worker_id is missing for non-broadcast job', async () => {
    const job = makeJob({ notification_type: 'payout_credited', amount: 500 });
    await expect(processNotificationDispatch(job)).rejects.toThrow(/missing worker_id/);
  });

  // payout_credited — Requirement 15.1, 15.2
  test('sends payout_credited notification to worker via FCM token in job data', async () => {
    sendNotification.mockResolvedValueOnce('msg-id-1');

    const job = makeJob({
      notification_type: 'payout_credited',
      worker_id: 'worker-1',
      fcm_token: 'device-token-abc',
      amount: 750,
    });

    const result = await processNotificationDispatch(job);

    expect(sendNotification).toHaveBeenCalledWith(
      'device-token-abc',
      'Payout Credited',
      expect.stringContaining('750'),
      expect.objectContaining({ notification_type: 'payout_credited', worker_id: 'worker-1' })
    );
    expect(result).toEqual(
      expect.objectContaining({ worker_id: 'worker-1', notification_type: 'payout_credited', message_id: 'msg-id-1' })
    );
  });

  test('looks up FCM token from DB when not provided in job data', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ fcm_token: 'db-token-xyz' }] });
    sendNotification.mockResolvedValueOnce('msg-id-2');

    const job = makeJob({
      notification_type: 'payout_credited',
      worker_id: 'worker-2',
      amount: 300,
    });

    await processNotificationDispatch(job);

    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('SELECT fcm_token FROM workers'),
      ['worker-2']
    );
    expect(sendNotification).toHaveBeenCalledWith(
      'db-token-xyz',
      expect.any(String),
      expect.any(String),
      expect.any(Object)
    );
  });

  test('skips and returns skipped=true when worker has no FCM token in DB', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const job = makeJob({
      notification_type: 'payout_credited',
      worker_id: 'worker-no-token',
      amount: 200,
    });

    const result = await processNotificationDispatch(job);

    expect(result).toEqual(
      expect.objectContaining({ skipped: true, reason: 'no_fcm_token' })
    );
    expect(sendNotification).not.toHaveBeenCalled();
  });

  test('skips when worker FCM token is null in DB', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ fcm_token: null }] });

    const job = makeJob({
      notification_type: 'claim_approved',
      worker_id: 'worker-null-token',
      estimated_payout: 500,
    });

    const result = await processNotificationDispatch(job);

    expect(result.skipped).toBe(true);
    expect(sendNotification).not.toHaveBeenCalled();
  });

  // claim_approved — Requirement 15.1
  test('sends claim_approved notification with correct title and body', async () => {
    sendNotification.mockResolvedValueOnce('msg-claim-approved');

    const job = makeJob({
      notification_type: 'claim_approved',
      worker_id: 'worker-3',
      fcm_token: 'tok-3',
      estimated_payout: 500,
    });

    await processNotificationDispatch(job);

    const [, title, body] = sendNotification.mock.calls[0];
    expect(title).toBe('Claim Approved');
    expect(body).toContain('500');
  });

  // claim_rejected — Requirement 15.1
  test('sends claim_rejected notification with correct title', async () => {
    sendNotification.mockResolvedValueOnce('msg-claim-rejected');

    const job = makeJob({
      notification_type: 'claim_rejected',
      worker_id: 'worker-4',
      fcm_token: 'tok-4',
      claim_id: 'claim-abc',
    });

    await processNotificationDispatch(job);

    const [, title] = sendNotification.mock.calls[0];
    expect(title).toBe('Claim Update');
  });

  // premium_updated — Requirement 15.1
  test('sends premium_updated notification with new premium in body', async () => {
    sendNotification.mockResolvedValueOnce('msg-premium');

    const job = makeJob({
      notification_type: 'premium_updated',
      worker_id: 'worker-5',
      fcm_token: 'tok-5',
      new_premium: 199,
      effective_date: '2025-02-01',
    });

    await processNotificationDispatch(job);

    const [, title, body] = sendNotification.mock.calls[0];
    expect(title).toBe('Premium Update');
    expect(body).toContain('199');
  });

  // Delivery failure handling — Requirement 15.4
  // Firebase SDK handles 24-hour retry natively; processor throws on null return so BullMQ retries
  test('throws when FCM sendNotification returns null (delivery failure triggers BullMQ retry)', async () => {
    sendNotification.mockResolvedValueOnce(null);

    const job = makeJob({
      notification_type: 'payout_credited',
      worker_id: 'worker-6',
      fcm_token: 'tok-6',
      amount: 100,
    });

    await expect(processNotificationDispatch(job)).rejects.toThrow(/FCM send failed/);
  });
});

// ─── processNotificationDispatch — zone broadcast (disruption_alert) ──────────

describe('processNotificationDispatch — disruption_alert zone broadcast', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  // Requirement 15.3: zone-specific alert to all active-policy workers within 60 seconds
  test('broadcasts disruption_alert to all active workers in zone', async () => {
    db.query.mockResolvedValueOnce({
      rows: [
        { worker_id: 'w1', fcm_token: 'tok-w1' },
        { worker_id: 'w2', fcm_token: 'tok-w2' },
        { worker_id: 'w3', fcm_token: 'tok-w3' },
      ],
    });
    sendNotification.mockResolvedValue('msg-broadcast');

    const job = makeJob({
      notification_type: 'disruption_alert',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'heavy_rainfall',
    });

    const result = await processNotificationDispatch(job);

    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining("p.status = 'active'"),
      ['MUM_ANDHERI_W']
    );
    expect(sendNotification).toHaveBeenCalledTimes(3);
    expect(result).toEqual(expect.objectContaining({ zone_id: 'MUM_ANDHERI_W', sent: 3 }));
  });

  test('returns sent=0 when no active workers in zone', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    const job = makeJob({
      notification_type: 'disruption_alert',
      zone_id: 'EMPTY_ZONE',
      event_type: 'cyclone',
    });

    const result = await processNotificationDispatch(job);

    expect(sendNotification).not.toHaveBeenCalled();
    expect(result).toEqual(expect.objectContaining({ zone_id: 'EMPTY_ZONE', sent: 0 }));
  });

  test('counts failed sends separately and does not throw on partial failure', async () => {
    db.query.mockResolvedValueOnce({
      rows: [
        { worker_id: 'w1', fcm_token: 'tok-w1' },
        { worker_id: 'w2', fcm_token: 'tok-w2' },
      ],
    });
    sendNotification
      .mockResolvedValueOnce('msg-ok')
      .mockResolvedValueOnce(null); // second worker fails

    const job = makeJob({
      notification_type: 'disruption_alert',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'flood',
    });

    const result = await processNotificationDispatch(job);

    expect(result.sent).toBe(1);
    expect(result.failed).toBe(1);
  });

  test('disruption_alert with worker_id routes as single-worker notification, not broadcast', async () => {
    sendNotification.mockResolvedValueOnce('msg-single');

    const job = makeJob({
      notification_type: 'disruption_alert',
      worker_id: 'worker-specific',
      zone_id: 'MUM_ANDHERI_W',
      fcm_token: 'tok-specific',
      event_type: 'heavy_rainfall',
    });

    const result = await processNotificationDispatch(job);

    // DB should NOT be queried for zone workers — token was provided directly
    expect(db.query).not.toHaveBeenCalled();
    expect(sendNotification).toHaveBeenCalledTimes(1);
    expect(result).toEqual(
      expect.objectContaining({ worker_id: 'worker-specific', notification_type: 'disruption_alert' })
    );
  });

  // Requirement 15.4: delivery failure — Firebase SDK handles 24-hour retry natively
  // Broadcast continues even when individual sends fail (logged, not thrown)
  test('broadcast continues sending to remaining workers when one FCM call throws', async () => {
    db.query.mockResolvedValueOnce({
      rows: [
        { worker_id: 'w1', fcm_token: 'tok-w1' },
        { worker_id: 'w2', fcm_token: 'tok-w2' },
        { worker_id: 'w3', fcm_token: 'tok-w3' },
      ],
    });
    sendNotification
      .mockResolvedValueOnce('msg-ok')
      .mockRejectedValueOnce(new Error('FCM quota exceeded'))
      .mockResolvedValueOnce('msg-ok-2');

    const job = makeJob({
      notification_type: 'disruption_alert',
      zone_id: 'MUM_ANDHERI_W',
      event_type: 'heavy_rainfall',
    });

    const result = await processNotificationDispatch(job);

    // All 3 workers attempted; 2 succeeded, 1 failed
    expect(sendNotification).toHaveBeenCalledTimes(3);
    expect(result.sent).toBe(2);
    expect(result.failed).toBe(1);
  });
});

// ─── broadcastZoneAlert — direct unit tests ───────────────────────────────────

describe('broadcastZoneAlert', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('queries workers with active policies in the given zone', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    await broadcastZoneAlert('job-1', 'ZONE_A', 'Disruption Alert', 'Event in your zone', {});

    expect(db.query).toHaveBeenCalledWith(
      expect.stringContaining('zone_id = $1'),
      ['ZONE_A']
    );
  });

  test('sends notification to each worker with a valid FCM token', async () => {
    db.query.mockResolvedValueOnce({
      rows: [
        { worker_id: 'w1', fcm_token: 'tok1' },
        { worker_id: 'w2', fcm_token: 'tok2' },
      ],
    });
    sendNotification.mockResolvedValue('msg-id');

    const result = await broadcastZoneAlert('job-2', 'ZONE_B', 'Alert', 'Body', { event_type: 'flood' });

    expect(sendNotification).toHaveBeenCalledTimes(2);
    expect(result.sent).toBe(2);
    expect(result.failed).toBe(0);
  });

  test('includes zone_id and event_type in FCM data payload', async () => {
    db.query.mockResolvedValueOnce({
      rows: [{ worker_id: 'w1', fcm_token: 'tok1' }],
    });
    sendNotification.mockResolvedValueOnce('msg-id');

    await broadcastZoneAlert('job-3', 'ZONE_C', 'Alert', 'Body', { event_type: 'cyclone' });

    const [, , , data] = sendNotification.mock.calls[0];
    expect(data).toMatchObject({
      notification_type: 'disruption_alert',
      zone_id: 'ZONE_C',
      worker_id: 'w1',
      event_type: 'cyclone',
    });
  });
});
