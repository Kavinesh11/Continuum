'use strict';

const {
  encryptField,
  decryptField,
} = require('../../services/core_backend/src/services/piiEncryption');

describe('PII encryption service', () => {
  test('encrypt and decrypt round-trip for a UPI ID', async () => {
    const plaintext = 'worker@upi';
    const encrypted = await encryptField(plaintext);
    expect(encrypted).not.toBe(plaintext);

    const decrypted = await decryptField(encrypted);
    expect(decrypted).toBe(plaintext);
  });

  test('encrypt and decrypt round-trip for GPS coordinates', async () => {
    const coords = '19.1234,72.8567';
    const encrypted = await encryptField(coords);
    const decrypted = await decryptField(encrypted);
    expect(decrypted).toBe(coords);
  });

  test('same plaintext produces different ciphertext each time (random IV)', async () => {
    const plaintext = 'test@upi';
    const a = await encryptField(plaintext);
    const b = await encryptField(plaintext);
    expect(a).not.toBe(b);
  });

  test('empty string round-trips correctly', async () => {
    const encrypted = await encryptField('');
    const decrypted = await decryptField(encrypted);
    expect(decrypted).toBe('');
  });

  test('unicode text round-trips correctly', async () => {
    const hindi = 'मुंबई कार्यकर्ता';
    const encrypted = await encryptField(hindi);
    const decrypted = await decryptField(encrypted);
    expect(decrypted).toBe(hindi);
  });
});
