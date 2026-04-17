'use strict';

const { AdapterNotConfiguredError } = require('../payoutGateway');

class MockLivenessProvider {
  async checkLiveness(workerId, sessionToken) {
    return { passed: true, confidence: 0.99, provider: 'mock' };
  }
}

class IProovLivenessProvider {
  constructor() {
    this._baseUrl = process.env.IPROOV_BASE_URL;
    this._apiKey = process.env.IPROOV_API_KEY;
    this._secret = process.env.IPROOV_SECRET;
    if (!this._baseUrl || !this._apiKey || !this._secret) {
      throw new AdapterNotConfiguredError('IProovLivenessProvider');
    }
  }

  async checkLiveness(workerId, sessionToken) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/v2/verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': this._apiKey,
      },
      body: JSON.stringify({
        api_key: this._apiKey,
        secret: this._secret,
        token: sessionToken,
        user_id: workerId,
      }),
      timeout: 30000,
    });
    const data = await resp.json();
    return {
      passed: data.passed === true,
      confidence: data.confidence || 0,
      provider: 'iproov',
      reason: data.reason,
    };
  }
}

function createLivenessProvider() {
  const provider = (process.env.LIVENESS_PROVIDER || 'mock').toLowerCase();
  switch (provider) {
    case 'iproov': return new IProovLivenessProvider();
    case 'mock':
    default: return new MockLivenessProvider();
  }
}

module.exports = { createLivenessProvider, MockLivenessProvider, IProovLivenessProvider };
