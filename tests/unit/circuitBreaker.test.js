'use strict';

const { CircuitBreaker, STATES } = require('../../services/core_backend/src/services/circuitBreaker');

describe('CircuitBreaker', () => {
  test('starts in CLOSED state and executes successfully', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 3 });
    const result = await cb.call(() => Promise.resolve('ok'));
    expect(result).toBe('ok');
    expect(cb.state).toBe(STATES.CLOSED);
  });

  test('transitions to OPEN after reaching failure threshold', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 2, resetTimeoutMs: 10000 });

    const failFn = () => Promise.reject(new Error('fail'));

    await expect(cb.call(failFn)).rejects.toThrow('fail');
    await expect(cb.call(failFn)).rejects.toThrow('fail');

    expect(cb.state).toBe(STATES.OPEN);
  });

  test('rejects immediately when circuit is OPEN (failClosed=true)', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 1, resetTimeoutMs: 60000, failClosed: true });

    await expect(cb.call(() => Promise.reject(new Error('x')))).rejects.toThrow();
    expect(cb.state).toBe(STATES.OPEN);

    await expect(cb.call(() => Promise.resolve('ok'))).rejects.toThrow(/OPEN/);
  });

  test('returns null when circuit is OPEN (failClosed=false)', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 1, resetTimeoutMs: 60000, failClosed: false });

    await expect(cb.call(() => Promise.reject(new Error('x')))).rejects.toThrow();
    expect(cb.state).toBe(STATES.OPEN);

    const result = await cb.call(() => Promise.resolve('ok'));
    expect(result).toBeNull();
  });

  test('transitions to HALF_OPEN after reset timeout', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 1, resetTimeoutMs: 50 });

    await expect(cb.call(() => Promise.reject(new Error('x')))).rejects.toThrow();
    expect(cb.state).toBe(STATES.OPEN);

    await new Promise(resolve => setTimeout(resolve, 100));

    // State transition happens lazily on next call attempt
    const result = await cb.call(() => Promise.resolve('probe'));
    expect(result).toBe('probe');
  });

  test('HALF_OPEN requires 2 successes to transition back to CLOSED', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 1, resetTimeoutMs: 50 });

    await expect(cb.call(() => Promise.reject(new Error('x')))).rejects.toThrow();
    await new Promise(resolve => setTimeout(resolve, 100));

    await cb.call(() => Promise.resolve('probe-1'));
    expect(cb.state).toBe(STATES.HALF_OPEN);

    await cb.call(() => Promise.resolve('probe-2'));
    expect(cb.state).toBe(STATES.CLOSED);
  });

  test('HALF_OPEN failure transitions back to OPEN', async () => {
    const cb = new CircuitBreaker('test', { failureThreshold: 1, resetTimeoutMs: 50 });

    await expect(cb.call(() => Promise.reject(new Error('x')))).rejects.toThrow();
    await new Promise(resolve => setTimeout(resolve, 100));

    await expect(cb.call(() => Promise.reject(new Error('still broken')))).rejects.toThrow();
    expect(cb.state).toBe(STATES.OPEN);
  });

  test('getState returns current circuit status', () => {
    const cb = new CircuitBreaker('payout-gateway', { failureThreshold: 3 });
    const state = cb.getState();
    expect(state).toEqual({ name: 'payout-gateway', state: 'closed', failureCount: 0 });
  });
});
