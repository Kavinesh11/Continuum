// Feature: continuum-ml-pipelines, Property 35: SIM Change Disbursement Hold
// Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5

'use strict';

const fc = require('fast-check');

// ─── Mocks ────────────────────────────────────────────────────────────────────

jest.mock('../src/db', () => ({ query: jest.fn() }));
jest.mock('node-fetch');
jest.mock('../src/adapters/payoutGateway', () => ({ createPayoutGateway: jest.fn() }));

const db = require('../src/db');
const fetch = require('node-fetch');
const {
  callPayUGateway,
  hasSIMChangedRecently,
  recordDisbursementStatus,
} = require('../src/services/payu');

// ─── callPayUGateway ──────────────────────────────────────────────────────────

describe('callPayUGateway', () => {
  beforeEach(() => jest.clearAllMocks());

  test('returns success with transaction_ref on HTTP 200', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ transaction_ref: 'TXN_001' }),
    });

    const result = await callPayUGateway('payout-1', 'worker-1', 'worker@upi', 500);

    expect(result.success).toBe(true);
    expect(result.transaction_ref).toBe('TXN_001');
    expect(result.error).toBeUndefined();
  });

  test('accepts txn_id as fallback field name', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ txn_id: 'TXN_ALT_002' }),
    });

    const result = await callPayUGateway('payout-2', 'worker-1', 'worker@upi', 300);

    expect(result.success).toBe(true);
    expect(result.transaction_ref).toBe('TXN_ALT_002');
  });

  test('returns failure with error message on non-OK HTTP response', async () => {
    fetch.mockResolvedValueOnce({
      ok: false,
      status: 422,
      text: async () => 'invalid upi id',
    });

    const result = await callPayUGateway('payout-3', 'worker-1', 'bad@upi', 100);

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/422/);
  });

  test('returns failure with error message on network error', async () => {
    fetch.mockRejectedValueOnce(new Error('ECONNREFUSED'));

    const result = await callPayUGateway('payout-4', 'worker-1', 'worker@upi', 200);

    expect(result.success).toBe(false);
    expect(result.error).toBe('ECONNREFUSED');
  });

  test('POSTs correct payload to PayU API', async () => {
    fetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ transaction_ref: 'TXN_CHECK' }),
    });

    await callPayUGateway('payout-5', 'worker-xyz', 'xyz@upi', 750);

    expect(fetch).toHaveBeenCalledTimes(1);
    const [url, options] = fetch.mock.calls[0];
    expect(url).toContain('/api/payout');
    expect(options.method).toBe('POST');

    const body = JSON.parse(options.body);
    expect(body.payout_id).toBe('payout-5');
    expect(body.worker_id).toBe('worker-xyz');
    expect(body.upi_id).toBe('xyz@upi');
    expect(body.amount).toBe(750);
    expect(body.currency).toBe('INR');
  });
});

// ─── hasSIMChangedRecently ────────────────────────────────────────────────────

describe('hasSIMChangedRecently', () => {
  beforeEach(() => jest.clearAllMocks());

  test('returns false when worker not found', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    expect(await hasSIMChangedRecently('unknown-worker')).toBe(false);
  });

  test('returns false when sim_changed_at is null', async () => {
    db.query.mockResolvedValueOnce({ rows: [{ sim_changed_at: null }] });
    expect(await hasSIMChangedRecently('worker-1')).toBe(false);
  });

  test('returns true when SIM changed 1 minute ago (within 6-hour window)', async () => {
    const oneMinuteAgo = new Date(Date.now() - 60 * 1000);
    db.query.mockResolvedValueOnce({ rows: [{ sim_changed_at: oneMinuteAgo }] });
    expect(await hasSIMChangedRecently('worker-1')).toBe(true);
  });

  test('returns true when SIM changed 1ms before the 6-hour boundary', async () => {
    // 1ms inside the 6-hour window — must be held
    const justInsideWindow = new Date(Date.now() - (6 * 60 * 60 * 1000 - 1));
    db.query.mockResolvedValueOnce({ rows: [{ sim_changed_at: justInsideWindow }] });
    expect(await hasSIMChangedRecently('worker-1')).toBe(true);
  });

  test('returns false when SIM changed 7 hours ago (outside 6-hour window)', async () => {
    const sevenHoursAgo = new Date(Date.now() - 7 * 60 * 60 * 1000);
    db.query.mockResolvedValueOnce({ rows: [{ sim_changed_at: sevenHoursAgo }] });
    expect(await hasSIMChangedRecently('worker-1')).toBe(false);
  });

  // Property 35: SIM Change Disbursement Hold
  // For any sim_changed_at within the last 6 hours, hasSIMChangedRecently returns true.
  // For any sim_changed_at older than 6 hours, it returns false.
  test('PBT — SIM changed within 6h always returns true', () => {
    // Feature: continuum-ml-pipelines, Property 35: SIM Change Disbursement Hold
    // Validates: Requirements 14.4
    return fc.assert(
      fc.asyncProperty(
        // Generate a timestamp between 1ms and 6h ago (inclusive boundary)
        fc.integer({ min: 1, max: 6 * 60 * 60 * 1000 }),
        async (msAgo) => {
          jest.clearAllMocks();
          const simChangedAt = new Date(Date.now() - msAgo);
          db.query.mockResolvedValueOnce({ rows: [{ sim_changed_at: simChangedAt }] });
          return (await hasSIMChangedRecently('worker-pbt')) === true;
        }
      ),
      { numRuns: 100 }
    );
  });

  test('PBT — SIM changed more than 6h ago always returns false', () => {
    // Feature: continuum-ml-pipelines, Property 35: SIM Change Disbursement Hold
    // Validates: Requirements 14.4
    return fc.assert(
      fc.asyncProperty(
        // Generate a timestamp strictly older than 6 hours (6h+1ms to 30 days)
        fc.integer({ min: 6 * 60 * 60 * 1000 + 1, max: 30 * 24 * 60 * 60 * 1000 }),
        async (msAgo) => {
          jest.clearAllMocks();
          const simChangedAt = new Date(Date.now() - msAgo);
          db.query.mockResolvedValueOnce({ rows: [{ sim_changed_at: simChangedAt }] });
          return (await hasSIMChangedRecently('worker-pbt')) === false;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── recordDisbursementStatus ─────────────────────────────────────────────────

describe('recordDisbursementStatus', () => {
  beforeEach(() => jest.clearAllMocks());

  test('sets status=disbursed, payu_txn_ref, and disbursed_at on success', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    await recordDisbursementStatus('payout-1', 'disbursed', 'TXN_SUCCESS');

    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/status = 'disbursed'/);
    expect(sql).toMatch(/payu_txn_ref/);
    expect(sql).toMatch(/disbursed_at/);
    expect(params[0]).toBe('TXN_SUCCESS');
    expect(params[1]).toBe('payout-1');
  });

  test('sets status=failed on failure', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    await recordDisbursementStatus('payout-2', 'failed');

    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/status = 'failed'/);
    expect(params[0]).toBe('payout-2');
  });

  test('sets status=held_sim_change on SIM hold', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });

    await recordDisbursementStatus('payout-3', 'held_sim_change');

    const [sql, params] = db.query.mock.calls[0];
    expect(sql).toMatch(/status = 'held_sim_change'/);
    expect(params[0]).toBe('payout-3');
  });

  test('throws on unknown status', async () => {
    await expect(recordDisbursementStatus('payout-4', 'unknown_status')).rejects.toThrow(
      /unknown status/
    );
    expect(db.query).not.toHaveBeenCalled();
  });
});

// ─── processPayoutDisbursement integration ────────────────────────────────────

describe('processPayoutDisbursement', () => {
  // Re-mock FCM for the processor tests
  jest.mock('../src/services/fcm', () => ({
    sendNotification: jest.fn().mockResolvedValue('msg-id'),
  }));

  const { processPayoutDisbursement } = require('../src/workers/processors/payoutDisbursement');
  const { sendNotification } = require('../src/services/fcm');
  const { createPayoutGateway } = require('../src/adapters/payoutGateway');
  const mockDisburse = jest.fn();

  const baseJob = {
    id: 'job-1',
    data: {
      payout_id: 'payout-abc',
      worker_id: 'worker-xyz',
      claim_id: 'claim-1',
      policy_id: 'policy-1',
      amount: 500,
      zone_id: 'MUM_ANDHERI_W',
      tier: 'silver',
      oracle_votes: [],
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createPayoutGateway.mockReturnValue({ disburse: mockDisburse });
  });

  test('throws when required fields are missing', async () => {
    const badJob = { id: 'job-bad', data: { payout_id: 'p1' } };
    await expect(processPayoutDisbursement(badJob)).rejects.toThrow(/missing required fields/);
  });

  test('throws when worker not found in DB', async () => {
    db.query
      .mockResolvedValueOnce({ rows: [] }); // worker lookup returns nothing

    await expect(processPayoutDisbursement(baseJob)).rejects.toThrow(/worker.*not found/);
  });

  test('holds payout and returns held_sim_change when SIM changed recently', async () => {
    const recentSIMChange = new Date(Date.now() - 30 * 60 * 1000); // 30 min ago

    db.query
      .mockResolvedValueOnce({ rows: [{ upi_id: 'w@upi', fcm_token: 'tok', sim_changed_at: recentSIMChange }] }) // worker fetch
      .mockResolvedValueOnce({ rows: [{ sim_changed_at: recentSIMChange }] })  // hasSIMChangedRecently
      .mockResolvedValueOnce({ rows: [] }); // recordDisbursementStatus UPDATE

    const result = await processPayoutDisbursement(baseJob);

    expect(result.status).toBe('held_sim_change');
    expect(result.reason).toBe('sim_change_detected');
    expect(sendNotification).toHaveBeenCalledWith(
      'tok',
      'Payout On Hold',
      expect.stringContaining('SIM change'),
      expect.objectContaining({ event_type: 'payout_held_sim_change' })
    );
    // PayU should NOT have been called
    expect(fetch).not.toHaveBeenCalled();
  });

  test('throws and records failed status when PayU returns failure', async () => {
    const oldSIMChange = new Date(Date.now() - 8 * 60 * 60 * 1000); // 8h ago — outside window

    db.query
      .mockResolvedValueOnce({ rows: [{ upi_id: 'w@upi', fcm_token: 'tok', sim_changed_at: oldSIMChange }] })
      .mockResolvedValueOnce({ rows: [{ sim_changed_at: oldSIMChange }] }) // hasSIMChangedRecently
      .mockResolvedValueOnce({ rows: [] }); // recordDisbursementStatus failed

    mockDisburse.mockResolvedValueOnce({ success: false, error: 'gateway_error' });

    await expect(processPayoutDisbursement(baseJob)).rejects.toThrow(/PayU disbursement failed/);

    // Verify failed status was recorded
    const updateCall = db.query.mock.calls.find(c => c[0] && c[0].includes("status = 'failed'"));
    expect(updateCall).toBeDefined();
  });

  test('records disbursed status and sends FCM on PayU success', async () => {
    const oldSIMChange = new Date(Date.now() - 8 * 60 * 60 * 1000);

    db.query
      .mockResolvedValueOnce({ rows: [{ upi_id: 'w@upi', fcm_token: 'tok', sim_changed_at: oldSIMChange }] })
      .mockResolvedValueOnce({ rows: [{ sim_changed_at: oldSIMChange }] }) // hasSIMChangedRecently
      .mockResolvedValueOnce({ rows: [] }); // recordDisbursementStatus disbursed

    mockDisburse.mockResolvedValueOnce({ success: true, transaction_ref: 'TXN_DONE' });

    const result = await processPayoutDisbursement(baseJob);

    expect(result.status).toBe('disbursed');
    expect(result.transaction_ref).toBe('TXN_DONE');

    // Verify disbursed status was recorded with txn ref
    const updateCall = db.query.mock.calls.find(c => c[0] && c[0].includes("status = 'disbursed'"));
    expect(updateCall).toBeDefined();
    expect(updateCall[1][0]).toBe('TXN_DONE');

    // FCM payout_credited notification sent
    expect(sendNotification).toHaveBeenCalledWith(
      'tok',
      'Payout Credited',
      expect.stringContaining('500'),
      expect.objectContaining({ event_type: 'payout_credited' })
    );
  });
});
