'use strict';

const Ajv = require('ajv');
const addFormats = require('ajv-formats');
const { readFileSync } = require('fs');
const path = require('path');

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);

function loadSchema(name) {
  const schemaPath = path.resolve(__dirname, '../../contracts/oracle_events', `${name}.schema.json`);
  return JSON.parse(readFileSync(schemaPath, 'utf8'));
}

describe('Kafka chaos scenarios (simulated)', () => {
  describe('malformed payload handling', () => {
    const payoutSchema = loadSchema('payout_authorized');
    const validate = ajv.compile(payoutSchema);

    test('completely empty JSON object is rejected', () => {
      expect(validate({})).toBe(false);
    });

    test('null payload is rejected', () => {
      expect(validate(null)).toBe(false);
    });

    test('array payload is rejected', () => {
      expect(validate([])).toBe(false);
    });

    test('string payload is rejected', () => {
      expect(validate('not json')).toBe(false);
    });

    test('number payload is rejected', () => {
      expect(validate(42)).toBe(false);
    });

    test('partial payload with only zone_id is rejected', () => {
      expect(validate({ zone_id: 'MUM_ANDHERI_W' })).toBe(false);
    });
  });

  describe('duplicate event idempotency (simulated)', () => {
    const processedEvents = new Set();

    function simulateIdempotentProcessing(eventId) {
      if (processedEvents.has(eventId)) {
        return { processed: false, reason: 'duplicate' };
      }
      processedEvents.add(eventId);
      return { processed: true };
    }

    test('first event is processed', () => {
      const result = simulateIdempotentProcessing('evt-001');
      expect(result.processed).toBe(true);
    });

    test('duplicate event is skipped', () => {
      const result = simulateIdempotentProcessing('evt-001');
      expect(result.processed).toBe(false);
      expect(result.reason).toBe('duplicate');
    });

    test('different event ID is processed', () => {
      const result = simulateIdempotentProcessing('evt-002');
      expect(result.processed).toBe(true);
    });
  });

  describe('handler failure and DLQ simulation', () => {
    const dlq = [];

    async function simulateHandler(event, handler) {
      try {
        return await handler(event);
      } catch (err) {
        dlq.push({ event, error: err.message, failedAt: new Date().toISOString() });
        throw err;
      }
    }

    test('successful handler does not produce DLQ message', async () => {
      dlq.length = 0;
      await simulateHandler({ id: 'ok' }, async () => 'done');
      expect(dlq.length).toBe(0);
    });

    test('failing handler sends event to DLQ', async () => {
      dlq.length = 0;
      await expect(
        simulateHandler({ id: 'bad' }, async () => { throw new Error('handler crash'); })
      ).rejects.toThrow('handler crash');

      expect(dlq.length).toBe(1);
      expect(dlq[0].event.id).toBe('bad');
      expect(dlq[0].error).toBe('handler crash');
    });

    test('multiple failures accumulate in DLQ', async () => {
      dlq.length = 0;
      for (let i = 0; i < 5; i++) {
        await simulateHandler({ id: `fail-${i}` }, async () => { throw new Error(`err-${i}`); }).catch(() => {});
      }
      expect(dlq.length).toBe(5);
    });
  });

  describe('out-of-order event handling', () => {
    test('events with older timestamps do not overwrite newer state', () => {
      const state = { zone_id: null, updatedAt: null };

      function processEvent(event) {
        if (!state.updatedAt || new Date(event.timestamp) > new Date(state.updatedAt)) {
          state.zone_id = event.zone_id;
          state.updatedAt = event.timestamp;
          return true;
        }
        return false;
      }

      processEvent({ zone_id: 'A', timestamp: '2026-04-17T10:00:00Z' });
      expect(state.zone_id).toBe('A');

      const applied = processEvent({ zone_id: 'B', timestamp: '2026-04-17T09:00:00Z' });
      expect(applied).toBe(false);
      expect(state.zone_id).toBe('A');

      const applied2 = processEvent({ zone_id: 'C', timestamp: '2026-04-17T11:00:00Z' });
      expect(applied2).toBe(true);
      expect(state.zone_id).toBe('C');
    });
  });

  describe('burst/throughput tolerance', () => {
    test('can validate 1000 events in under 1 second', () => {
      const schema = loadSchema('payout_authorized');
      const validate = ajv.compile(schema);

      const baseEvent = {
        payout_id: '550e8400-e29b-41d4-a716-446655440000',
        zone_id: 'MUM_ANDHERI_W',
        oracle_votes: [
          { oracle_name: 'IMD', vote: 'affirm', polled_at: '2026-04-17T10:00:00Z', tls_valid: true },
        ],
        authorized_at: '2026-04-17T10:01:00Z',
        payout_cap: 0.85,
      };

      const start = Date.now();
      for (let i = 0; i < 1000; i++) {
        validate({ ...baseEvent, payout_id: `550e8400-e29b-41d4-a716-${String(i).padStart(12, '0')}` });
      }
      const elapsed = Date.now() - start;

      expect(elapsed).toBeLessThan(1000);
    });
  });
});
