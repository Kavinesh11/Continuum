'use strict';

const { createKmsAdapter } = require('../adapters/kms');

let _kms = null;

function getKms() {
  if (!_kms) _kms = createKmsAdapter();
  return _kms;
}

async function encryptUpiId(upiId) {
  if (!upiId) return null;
  return getKms().encrypt(upiId);
}

async function decryptUpiId(encrypted) {
  if (!encrypted) return null;
  return getKms().decrypt(encrypted);
}

async function encryptGpsCoordinates(lat, lon) {
  const payload = JSON.stringify({ lat, lon });
  return getKms().encrypt(payload);
}

async function decryptGpsCoordinates(encrypted) {
  if (!encrypted) return null;
  const raw = await getKms().decrypt(encrypted);
  return JSON.parse(raw);
}

async function encryptField(value) {
  if (value === null || value === undefined) return null;
  return getKms().encrypt(String(value));
}

async function decryptField(encrypted) {
  if (!encrypted) return null;
  return getKms().decrypt(encrypted);
}

module.exports = {
  encryptUpiId,
  decryptUpiId,
  encryptGpsCoordinates,
  decryptGpsCoordinates,
  encryptField,
  decryptField,
};
