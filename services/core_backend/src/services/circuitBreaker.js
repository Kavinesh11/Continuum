'use strict';

const STATES = { CLOSED: 'closed', OPEN: 'open', HALF_OPEN: 'half_open' };

class CircuitBreaker {
  /**
   * @param {string} name
   * @param {object} opts
   * @param {number} opts.failureThreshold - failures before opening (default 5)
   * @param {number} opts.resetTimeoutMs - ms before transitioning to half-open (default 30000)
   * @param {boolean} opts.failClosed - if true, throws on open (fail-closed); if false, returns null (fail-open)
   */
  constructor(name, opts = {}) {
    this.name = name;
    this.failureThreshold = opts.failureThreshold || 5;
    this.resetTimeoutMs = opts.resetTimeoutMs || 30000;
    this.failClosed = opts.failClosed !== undefined ? opts.failClosed : true;

    this.state = STATES.CLOSED;
    this.failureCount = 0;
    this.lastFailureTime = null;
    this.successCount = 0;
  }

  async call(fn) {
    if (this.state === STATES.OPEN) {
      if (Date.now() - this.lastFailureTime >= this.resetTimeoutMs) {
        this.state = STATES.HALF_OPEN;
      } else {
        if (this.failClosed) {
          throw new Error(`CircuitBreaker[${this.name}] is OPEN — request rejected`);
        }
        return null;
      }
    }

    try {
      const result = await fn();
      this._onSuccess();
      return result;
    } catch (err) {
      this._onFailure();
      throw err;
    }
  }

  _onSuccess() {
    if (this.state === STATES.HALF_OPEN) {
      this.successCount++;
      if (this.successCount >= 2) {
        this.state = STATES.CLOSED;
        this.failureCount = 0;
        this.successCount = 0;
      }
    } else {
      this.failureCount = 0;
    }
  }

  _onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.failureThreshold) {
      this.state = STATES.OPEN;
    }
  }

  getState() {
    return { name: this.name, state: this.state, failureCount: this.failureCount };
  }
}

module.exports = { CircuitBreaker, STATES };
