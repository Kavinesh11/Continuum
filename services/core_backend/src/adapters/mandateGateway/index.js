'use strict';

const { AdapterNotConfiguredError } = require('../payoutGateway');

class MockMandateGateway {
  async createMandate(mandateId, upiId, maxAmount, frequency) {
    return { provider_ref: `MOCK_MANDATE_${mandateId.slice(0, 8)}`, status: 'created' };
  }

  async executeDebit(mandateId, providerRef, amount, debitId) {
    return { txn_ref: `MOCK_DEBIT_${debitId.slice(0, 8)}`, status: 'success' };
  }

  async revokeMandate(mandateId, providerRef) {
    return { status: 'revoked' };
  }
}

class SandboxMandateGateway {
  constructor() {
    this._baseUrl = process.env.PAYU_MANDATE_URL || 'https://sandboxsecure.payu.in';
    this._apiKey = process.env.PAYU_API_KEY || '';
  }

  async createMandate(mandateId, upiId, maxAmount, frequency) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/mandate/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this._apiKey}` },
      body: JSON.stringify({ mandate_id: mandateId, upi_id: upiId, max_amount: maxAmount, frequency }),
      timeout: 15000,
    });
    const data = await resp.json();
    return { provider_ref: data.provider_ref, status: resp.ok ? 'created' : 'failed' };
  }

  async executeDebit(mandateId, providerRef, amount, debitId) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/mandate/debit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this._apiKey}` },
      body: JSON.stringify({ mandate_id: mandateId, provider_ref: providerRef, amount, debit_id: debitId }),
      timeout: 15000,
    });
    const data = await resp.json();
    return { txn_ref: data.txn_ref, status: resp.ok ? 'success' : 'failed' };
  }

  async revokeMandate(mandateId, providerRef) {
    return { status: 'revoked' };
  }
}

class ProdMandateGateway {
  constructor() {
    this._baseUrl = process.env.PAYU_PROD_MANDATE_URL;
    this._apiKey = process.env.PAYU_PROD_API_KEY;
    if (!this._baseUrl || !this._apiKey) {
      throw new AdapterNotConfiguredError('ProdMandateGateway');
    }
  }

  async createMandate(mandateId, upiId, maxAmount, frequency) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/mandate/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this._apiKey}` },
      body: JSON.stringify({ mandate_id: mandateId, upi_id: upiId, max_amount: maxAmount, frequency }),
      timeout: 30000,
    });
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.message || `HTTP ${resp.status}`);
    return { provider_ref: data.provider_ref, status: 'created' };
  }

  async executeDebit(mandateId, providerRef, amount, debitId) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/mandate/debit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this._apiKey}` },
      body: JSON.stringify({ mandate_id: mandateId, provider_ref: providerRef, amount, debit_id: debitId }),
      timeout: 30000,
    });
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.message || `HTTP ${resp.status}`);
    return { txn_ref: data.txn_ref, status: 'success' };
  }

  async revokeMandate(mandateId, providerRef) {
    const fetch = require('node-fetch');
    const resp = await fetch(`${this._baseUrl}/api/mandate/revoke`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this._apiKey}` },
      body: JSON.stringify({ mandate_id: mandateId, provider_ref: providerRef }),
      timeout: 15000,
    });
    return { status: resp.ok ? 'revoked' : 'failed' };
  }
}

function createMandateGateway() {
  const provider = (process.env.MANDATE_GATEWAY_PROVIDER || 'mock').toLowerCase();
  switch (provider) {
    case 'prod': return new ProdMandateGateway();
    case 'sandbox': return new SandboxMandateGateway();
    case 'mock':
    default: return new MockMandateGateway();
  }
}

module.exports = { createMandateGateway, MockMandateGateway, SandboxMandateGateway, ProdMandateGateway };
