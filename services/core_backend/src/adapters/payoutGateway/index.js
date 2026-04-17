'use strict';

class AdapterNotConfiguredError extends Error {
  constructor(adapter) {
    super(`${adapter} adapter is not configured. Set required credentials.`);
    this.name = 'AdapterNotConfiguredError';
  }
}

// ─── Interface contract ──────────────────────────────────────────────────────
// Every adapter must implement: disburse(payoutId, workerId, upiId, amount) => { success, transaction_ref, error? }
//                               checkStatus(payoutId) => { status, transaction_ref? }

class MockPayoutGateway {
  async disburse(payoutId, workerId, upiId, amount) {
    return {
      success: true,
      transaction_ref: `MOCK_TXN_${payoutId.slice(0, 8)}`,
      amount,
    };
  }

  async checkStatus(payoutId) {
    return { status: 'disbursed', transaction_ref: `MOCK_TXN_${payoutId.slice(0, 8)}` };
  }
}

class SandboxPayoutGateway {
  constructor() {
    this._baseUrl = process.env.PAYU_BASE_URL || 'https://sandboxsecure.payu.in';
    this._apiKey = process.env.PAYU_API_KEY || '';
  }

  async disburse(payoutId, workerId, upiId, amount) {
    const fetch = require('node-fetch');
    try {
      const resp = await fetch(`${this._baseUrl}/api/payout/create`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this._apiKey}`,
        },
        body: JSON.stringify({ payout_id: payoutId, upi_id: upiId, amount }),
        timeout: 15000,
      });
      const data = await resp.json();
      return {
        success: resp.ok,
        transaction_ref: data.txn_ref || null,
        error: resp.ok ? undefined : data.message,
      };
    } catch (err) {
      return { success: false, error: err.message };
    }
  }

  async checkStatus(payoutId) {
    return { status: 'unknown' };
  }
}

class ProdPayoutGateway {
  constructor() {
    this._baseUrl = process.env.PAYU_PROD_URL;
    this._apiKey = process.env.PAYU_PROD_API_KEY;
    if (!this._baseUrl || !this._apiKey) {
      throw new AdapterNotConfiguredError('ProdPayoutGateway');
    }
  }

  async disburse(payoutId, workerId, upiId, amount) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/payout/create`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${this._apiKey}`,
      },
      body: JSON.stringify({ payout_id: payoutId, upi_id: upiId, amount }),
      timeout: 30000,
    });
    const data = await resp.json();
    if (!resp.ok) {
      return { success: false, error: data.message || `HTTP ${resp.status}` };
    }
    return { success: true, transaction_ref: data.txn_ref };
  }

  async checkStatus(payoutId) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/payout/status/${payoutId}`, {
      headers: { 'Authorization': `Bearer ${this._apiKey}` },
      timeout: 15000,
    });
    const data = await resp.json();
    return { status: data.status, transaction_ref: data.txn_ref };
  }
}

function createPayoutGateway() {
  const provider = (process.env.PAYOUT_GATEWAY_PROVIDER || 'mock').toLowerCase();
  switch (provider) {
    case 'prod':
      return new ProdPayoutGateway();
    case 'sandbox':
      return new SandboxPayoutGateway();
    case 'mock':
    default:
      return new MockPayoutGateway();
  }
}

module.exports = {
  createPayoutGateway,
  MockPayoutGateway,
  SandboxPayoutGateway,
  ProdPayoutGateway,
  AdapterNotConfiguredError,
};
