// Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
// Feature: continuum-ml-pipelines, Property 25: DLQ Escalation Timeout
// Validates: Requirements 8.2, 8.4, 14.3

'use strict';

const fc = require('fast-check');

// ─── Mock BullMQ ─────────────────────────────────────────────────────────────
// Mock before requiring any module that imports bullmq
jest.mock('bullmq', () => {
  const mockQueue = {
    add: jest.fn().mockResolvedValue({ id: 'job-1' }),
    getFailed: jest.fn().mockResolvedValue([]),
    close: jest.fn().mockResolvedValue(undefined),
  };
  const mockWorker = {
    on: jest.fn(),
    close: jest.fn().mockResolvedValue(undefined),
  };
  return {
    Queue: jest.fn(() => mockQueue),
    Worker: jest.fn(() => mockWorker),
  };
});

// ─── Mock Kafka ───────────────────────────────────────────────────────────────
jest.mock('../src/services/kafka', () => ({
  publishEvent: jest.fn().mockResolvedValue(undefined),
  disconnect: jest.fn().mockResolvedValue(undefined),
}));

// ─── Mock DB (required by workers/index.js scheduler) ────────────────────────
jest.mock('../src/db', () => ({ query: jest.fn().mockResolvedValue({ rows: [] }) }));

// ─── Mock processors ─────────────────────────────────────────────────────────
jest.mock('../src/workers/processors/premiumRecalculation', () => ({
  processPremiumRecalculation: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../src/workers/processors/payoutDisbursement', () => ({
  processPayoutDisbursement: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../src/workers/processors/notificationDispatch', () => ({
  processNotificationDispatch: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../src/workers/processors/fraudReviewEscalation', () => ({
  processFraudReviewEscalation: jest.fn().mockResolvedValue(undefined),
}));

const { BACKOFF_DELAYS, MAX_ATTEMPTS } = require('../src/workers/queues');
const { customBackoffStrategy, checkDLQEscalations } = require('../src/workers/index');
const kafka = require('../src/services/kafka');
const { Queue } = require('bullmq');

// ─── Property 24: BullMQ Exponential Backoff ─────────────────────────────────
// Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
// Assert retry delays follow exponential sequence [1s, 2s, 4s, 8s, 16s]
// Validates: Requirements 8.2, 14.3

describe('Property 24: BullMQ Exponential Backoff', () => {
  // Unit test: verify the exact delay sequence
  test('BACKOFF_DELAYS is exactly [1000, 2000, 4000, 8000, 16000]', () => {
    expect(BACKOFF_DELAYS).toEqual([1000, 2000, 4000, 8000, 16000]);
  });

  test('MAX_ATTEMPTS is 5', () => {
    expect(MAX_ATTEMPTS).toBe(5);
  });

  // Unit test: each attempt maps to the correct delay
  test('customBackoffStrategy returns correct delay for each attempt 1–5', () => {
    expect(customBackoffStrategy(1)).toBe(1000);
    expect(customBackoffStrategy(2)).toBe(2000);
    expect(customBackoffStrategy(3)).toBe(4000);
    expect(customBackoffStrategy(4)).toBe(8000);
    expect(customBackoffStrategy(5)).toBe(16000);
  });

  // Unit test: attempt beyond max is clamped to last delay
  test('customBackoffStrategy clamps to 16000ms for attempts > 5', () => {
    expect(customBackoffStrategy(6)).toBe(16000);
    expect(customBackoffStrategy(100)).toBe(16000);
  });

  // Property 24a: For any valid attempt number (1–5), delay equals BACKOFF_DELAYS[attempt-1]
  test('PBT — delay for attempt N equals BACKOFF_DELAYS[N-1] for all N in [1, 5]', () => {
    // Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 5 }),
        (attempt) => {
          const delay = customBackoffStrategy(attempt);
          const expected = BACKOFF_DELAYS[attempt - 1];
          return delay === expected;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 24b: Delays form a strictly increasing exponential sequence
  // Each delay must be exactly double the previous
  test('PBT — each successive delay is exactly double the previous', () => {
    // Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 4 }), // attempt 1..4 (so attempt+1 is still <= 5)
        (attempt) => {
          const current = customBackoffStrategy(attempt);
          const next = customBackoffStrategy(attempt + 1);
          return next === current * 2;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 24c: For any attempt >= 1, delay is always a positive integer
  test('PBT — delay is always a positive integer for any attempt >= 1', () => {
    // Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 1000 }),
        (attempt) => {
          const delay = customBackoffStrategy(attempt);
          return Number.isInteger(delay) && delay > 0;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 24d: For any attempt >= 5, delay is clamped to the maximum (16000ms)
  test('PBT — delay is clamped to 16000ms for any attempt >= 5', () => {
    // Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
    fc.assert(
      fc.property(
        fc.integer({ min: 5, max: 1000 }),
        (attempt) => {
          const delay = customBackoffStrategy(attempt);
          return delay === 16000;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 24e: Delay sequence is monotonically non-decreasing
  test('PBT — delay for attempt N+1 is always >= delay for attempt N', () => {
    // Feature: continuum-ml-pipelines, Property 24: BullMQ Exponential Backoff
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 999 }),
        (attempt) => {
          const current = customBackoffStrategy(attempt);
          const next = customBackoffStrategy(attempt + 1);
          return next >= current;
        }
      ),
      { numRuns: 100 }
    );
  });
});

// ─── Property 25: DLQ Escalation Timeout ─────────────────────────────────────
// Feature: continuum-ml-pipelines, Property 25: DLQ Escalation Timeout
// Assert DLQ entries >24h trigger `fraud_alert` Kafka event
// Validates: Requirements 8.4

describe('Property 25: DLQ Escalation Timeout', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  // Unit test: job finished exactly 24h ago is NOT escalated (boundary)
  // Uses fake timers to freeze Date.now() so finishedOn === twentyFourHoursAgo (strict < is false)
  test('job finished exactly 24h ago is NOT escalated', async () => {
    const now = Date.now();
    jest.setSystemTime(now);
    const finishedOn = now - 24 * 60 * 60 * 1000;
    const mockQueueInstance = new Queue();
    mockQueueInstance.getFailed.mockResolvedValueOnce([
      { id: 'job-boundary', finishedOn, data: { worker_id: 'w1' } },
    ]);

    await checkDLQEscalations();

    expect(kafka.publishEvent).not.toHaveBeenCalled();
  });

  // Unit test: job finished 24h + 1ms ago IS escalated
  test('job finished 24h + 1ms ago triggers fraud_alert', async () => {
    const finishedOn = Date.now() - (24 * 60 * 60 * 1000 + 1);
    const mockQueueInstance = new Queue();
    mockQueueInstance.getFailed.mockResolvedValueOnce([
      { id: 'job-over-24h', finishedOn, data: { worker_id: 'w1', claim_id: 'c1' } },
    ]);

    await checkDLQEscalations();

    expect(kafka.publishEvent).toHaveBeenCalledWith(
      'fraud_alert',
      expect.objectContaining({
        alert_type: 'dlq_escalation',
        job_id: 'job-over-24h',
      })
    );
  });

  // Unit test: job with finishedOn = 0 (never finished) is NOT escalated
  test('job with finishedOn = 0 is not escalated', async () => {
    const mockQueueInstance = new Queue();
    mockQueueInstance.getFailed.mockResolvedValueOnce([
      { id: 'job-unfinished', finishedOn: 0, data: {} },
    ]);

    await checkDLQEscalations();

    expect(kafka.publishEvent).not.toHaveBeenCalled();
  });

  // Unit test: empty DLQ produces no Kafka events
  test('empty DLQ produces no fraud_alert events', async () => {
    const mockQueueInstance = new Queue();
    mockQueueInstance.getFailed.mockResolvedValueOnce([]);

    await checkDLQEscalations();

    expect(kafka.publishEvent).not.toHaveBeenCalled();
  });

  // Property 25a: For any finishedOn > 24h ago, fraud_alert is published
  test('PBT — any DLQ job older than 24h always triggers fraud_alert', async () => {
    // Feature: continuum-ml-pipelines, Property 25: DLQ Escalation Timeout
    await fc.assert(
      fc.asyncProperty(
        // Generate ages strictly greater than 24h (in ms), up to 30 days
        fc.integer({ min: 24 * 60 * 60 * 1000 + 1, max: 30 * 24 * 60 * 60 * 1000 }),
        fc.uuid(),
        async (ageMs, jobId) => {
          jest.clearAllMocks();

          const finishedOn = Date.now() - ageMs;
          const mockQueueInstance = new Queue();
          mockQueueInstance.getFailed.mockResolvedValueOnce([
            { id: jobId, finishedOn, data: { worker_id: 'w1' } },
          ]);

          await checkDLQEscalations();

          // fraud_alert must have been published
          const calls = kafka.publishEvent.mock.calls;
          if (calls.length === 0) return false;

          const [topic, payload] = calls[0];
          return (
            topic === 'fraud_alert' &&
            payload.alert_type === 'dlq_escalation' &&
            payload.job_id === jobId
          );
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 25b: For any finishedOn <= 24h ago (but > 0), fraud_alert is NOT published
  test('PBT — DLQ jobs within 24h window do NOT trigger fraud_alert', async () => {
    // Feature: continuum-ml-pipelines, Property 25: DLQ Escalation Timeout
    await fc.assert(
      fc.asyncProperty(
        // Generate ages strictly less than 24h (1ms to 24h - 1ms)
        fc.integer({ min: 1, max: 24 * 60 * 60 * 1000 - 1 }),
        fc.uuid(),
        async (ageMs, jobId) => {
          jest.clearAllMocks();

          const finishedOn = Date.now() - ageMs;
          const mockQueueInstance = new Queue();
          mockQueueInstance.getFailed.mockResolvedValueOnce([
            { id: jobId, finishedOn, data: { worker_id: 'w1' } },
          ]);

          await checkDLQEscalations();

          // fraud_alert must NOT have been published
          return kafka.publishEvent.mock.calls.length === 0;
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 25c: fraud_alert payload always contains required fields
  test('PBT — fraud_alert payload always contains alert_type, queue, job_id, failed_at, triggered_at', async () => {
    // Feature: continuum-ml-pipelines, Property 25: DLQ Escalation Timeout
    await fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 24 * 60 * 60 * 1000 + 1, max: 30 * 24 * 60 * 60 * 1000 }),
        fc.uuid(),
        async (ageMs, jobId) => {
          jest.clearAllMocks();

          const finishedOn = Date.now() - ageMs;
          const mockQueueInstance = new Queue();
          mockQueueInstance.getFailed.mockResolvedValueOnce([
            { id: jobId, finishedOn, data: { worker_id: 'w1' } },
          ]);

          await checkDLQEscalations();

          const calls = kafka.publishEvent.mock.calls;
          if (calls.length === 0) return false;

          const [topic, payload] = calls[0];
          return (
            topic === 'fraud_alert' &&
            typeof payload.alert_type === 'string' &&
            typeof payload.queue === 'string' &&
            typeof payload.job_id === 'string' &&
            typeof payload.failed_at === 'string' &&
            typeof payload.triggered_at === 'string'
          );
        }
      ),
      { numRuns: 100 }
    );
  });

  // Property 25d: Multiple DLQ jobs — each job older than 24h gets its own fraud_alert
  test('PBT — each DLQ job older than 24h produces exactly one fraud_alert', async () => {
    // Feature: continuum-ml-pipelines, Property 25: DLQ Escalation Timeout
    await fc.assert(
      fc.asyncProperty(
        // Generate 1–5 jobs, all older than 24h
        fc.array(
          fc.record({
            id: fc.uuid(),
            ageMs: fc.integer({ min: 24 * 60 * 60 * 1000 + 1, max: 30 * 24 * 60 * 60 * 1000 }),
          }),
          { minLength: 1, maxLength: 5 }
        ),
        async (jobSpecs) => {
          jest.clearAllMocks();

          const jobs = jobSpecs.map(({ id, ageMs }) => ({
            id,
            finishedOn: Date.now() - ageMs,
            data: { worker_id: 'w1' },
          }));

          const mockQueueInstance = new Queue();
          mockQueueInstance.getFailed.mockResolvedValueOnce(jobs);

          await checkDLQEscalations();

          // Each job must produce exactly one fraud_alert
          return kafka.publishEvent.mock.calls.length === jobs.length;
        }
      ),
      { numRuns: 100 }
    );
  });
});
