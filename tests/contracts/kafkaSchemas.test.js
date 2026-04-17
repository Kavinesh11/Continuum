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

describe('contract tests: payout_authorized schema', () => {
  const schema = loadSchema('payout_authorized');
  const validate = ajv.compile(schema);

  test('valid event passes validation', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [
        { oracle_name: 'IMD', vote: 'affirm', polled_at: '2026-04-17T10:00:00Z', tls_valid: true },
        { oracle_name: 'AccuWeather', vote: 'affirm', polled_at: '2026-04-17T10:00:05Z', tls_valid: true },
        { oracle_name: 'NASA_GPM', vote: 'deny', polled_at: '2026-04-17T10:00:10Z', tls_valid: true },
      ],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.85,
    };
    expect(validate(event)).toBe(true);
  });

  test('missing required field payout_id fails', () => {
    const event = {
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.5,
    };
    expect(validate(event)).toBe(false);
    expect(validate.errors.some(e => e.params?.missingProperty === 'payout_id')).toBe(true);
  });

  test('payout_cap > 1 fails', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 1.5,
    };
    expect(validate(event)).toBe(false);
  });

  test('invalid vote value fails', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [
        { oracle_name: 'IMD', vote: 'maybe', polled_at: '2026-04-17T10:00:00Z', tls_valid: true },
      ],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.5,
    };
    expect(validate(event)).toBe(false);
  });

  test('additional properties are rejected', () => {
    const event = {
      payout_id: '550e8400-e29b-41d4-a716-446655440000',
      zone_id: 'MUM_ANDHERI_W',
      oracle_votes: [],
      authorized_at: '2026-04-17T10:01:00Z',
      payout_cap: 0.5,
      sneaky_field: 'should fail',
    };
    expect(validate(event)).toBe(false);
  });
});

describe('contract tests: enrollment_lock schema', () => {
  const schema = loadSchema('enrollment_lock');
  const validate = ajv.compile(schema);

  test('valid lock event passes', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440001',
      zone_id: 'MUM_BANDRA_W',
      event_type: 'heavy_rainfall',
      forecast_data: { severity: 'red', probability: 0.92 },
      locked_at: '2026-04-17T08:00:00Z',
      expires_at: '2026-04-19T08:00:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('missing event_id fails', () => {
    const event = {
      zone_id: 'MUM_BANDRA_W',
      event_type: 'heavy_rainfall',
      locked_at: '2026-04-17T08:00:00Z',
      expires_at: '2026-04-19T08:00:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('invalid severity in forecast_data fails', () => {
    const event = {
      event_id: '550e8400-e29b-41d4-a716-446655440001',
      zone_id: 'MUM_BANDRA_W',
      event_type: 'heavy_rainfall',
      forecast_data: { severity: 'green', probability: 0.1 },
      locked_at: '2026-04-17T08:00:00Z',
      expires_at: '2026-04-19T08:00:00Z',
    };
    expect(validate(event)).toBe(false);
  });
});

describe('contract tests: fraud_alert schema', () => {
  const schema = loadSchema('fraud_alert');
  const validate = ajv.compile(schema);

  test('valid fraud alert passes', () => {
    const event = {
      alert_type: 'dlq_threshold_exceeded',
      queue: 'payout_disbursement',
      job_id: 'job-123',
      triggered_at: '2026-04-17T12:00:00Z',
    };
    expect(validate(event)).toBe(true);
  });

  test('missing alert_type fails', () => {
    const event = {
      triggered_at: '2026-04-17T12:00:00Z',
    };
    expect(validate(event)).toBe(false);
  });

  test('additional properties are allowed (schema permits)', () => {
    const event = {
      alert_type: 'anomaly_score',
      triggered_at: '2026-04-17T12:00:00Z',
      custom_field: 'extra info',
    };
    expect(validate(event)).toBe(true);
  });
});

describe('contract tests: cross-schema compatibility', () => {
  test('payout_authorized and enrollment_lock share zone_id format', () => {
    const payoutSchema = loadSchema('payout_authorized');
    const lockSchema = loadSchema('enrollment_lock');

    expect(payoutSchema.properties.zone_id.type).toBe(lockSchema.properties.zone_id.type);
    expect(payoutSchema.properties.zone_id.minLength).toBe(lockSchema.properties.zone_id.minLength);
  });

  test('all schemas use ISO 8601 date-time format for timestamps', () => {
    const schemas = ['payout_authorized', 'enrollment_lock', 'fraud_alert'];
    for (const name of schemas) {
      const schema = loadSchema(name);
      const timestampField = name === 'payout_authorized' ? 'authorized_at'
        : name === 'enrollment_lock' ? 'locked_at'
        : 'triggered_at';

      expect(schema.properties[timestampField].format).toBe('date-time');
    }
  });
});
