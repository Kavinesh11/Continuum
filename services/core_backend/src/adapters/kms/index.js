'use strict';

const crypto = require('crypto');
const { AdapterNotConfiguredError } = require('../payoutGateway');

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const AUTH_TAG_LENGTH = 16;

/**
 * Local KMS adapter — uses a static AES-256 key derived from an env var.
 * Suitable for dev/CI only; never use in production.
 */
class LocalKmsAdapter {
  constructor() {
    const secret = process.env.LOCAL_KMS_SECRET || 'continuum-dev-kms-secret-32ch';
    this._key = crypto.createHash('sha256').update(secret).digest();
  }

  async encrypt(plaintext) {
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, this._key, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return Buffer.concat([iv, tag, encrypted]).toString('base64');
  }

  async decrypt(ciphertext) {
    const buf = Buffer.from(ciphertext, 'base64');
    const iv = buf.subarray(0, IV_LENGTH);
    const tag = buf.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH);
    const encrypted = buf.subarray(IV_LENGTH + AUTH_TAG_LENGTH);
    const decipher = crypto.createDecipheriv(ALGORITHM, this._key, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
  }
}

/**
 * AWS KMS adapter — envelope encryption using AWS KMS.
 * Generates a data key per encryption, encrypts with data key,
 * stores encrypted data key alongside ciphertext.
 */
class AwsKmsAdapter {
  constructor() {
    this._keyArn = process.env.AWS_KMS_KEY_ARN;
    if (!this._keyArn) throw new AdapterNotConfiguredError('AwsKmsAdapter');
    const { KMSClient, GenerateDataKeyCommand, DecryptCommand } = require('@aws-sdk/client-kms');
    this._client = new KMSClient({});
    this._GenerateDataKeyCommand = GenerateDataKeyCommand;
    this._DecryptCommand = DecryptCommand;
  }

  async encrypt(plaintext) {
    const { Plaintext: dataKey, CiphertextBlob: encryptedDataKey } = await this._client.send(
      new this._GenerateDataKeyCommand({ KeyId: this._keyArn, KeySpec: 'AES_256' })
    );
    const iv = crypto.randomBytes(IV_LENGTH);
    const cipher = crypto.createCipheriv(ALGORITHM, Buffer.from(dataKey), iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();

    const envelope = JSON.stringify({
      edk: Buffer.from(encryptedDataKey).toString('base64'),
      iv: iv.toString('base64'),
      tag: tag.toString('base64'),
      ct: encrypted.toString('base64'),
    });
    return Buffer.from(envelope).toString('base64');
  }

  async decrypt(ciphertext) {
    const envelope = JSON.parse(Buffer.from(ciphertext, 'base64').toString('utf8'));
    const { Plaintext: dataKey } = await this._client.send(
      new this._DecryptCommand({ CiphertextBlob: Buffer.from(envelope.edk, 'base64') })
    );
    const iv = Buffer.from(envelope.iv, 'base64');
    const tag = Buffer.from(envelope.tag, 'base64');
    const encrypted = Buffer.from(envelope.ct, 'base64');
    const decipher = crypto.createDecipheriv(ALGORITHM, Buffer.from(dataKey), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
  }
}

/**
 * GCP KMS adapter (typed shell).
 */
class GcpKmsAdapter {
  constructor() {
    this._keyName = process.env.GCP_KMS_KEY_NAME;
    if (!this._keyName) throw new AdapterNotConfiguredError('GcpKmsAdapter');
  }

  async encrypt(_plaintext) {
    throw new Error('GcpKmsAdapter.encrypt: not yet implemented — requires @google-cloud/kms');
  }

  async decrypt(_ciphertext) {
    throw new Error('GcpKmsAdapter.decrypt: not yet implemented — requires @google-cloud/kms');
  }
}

function createKmsAdapter() {
  const provider = (process.env.KMS_PROVIDER || 'local').toLowerCase();
  switch (provider) {
    case 'aws': return new AwsKmsAdapter();
    case 'gcp': return new GcpKmsAdapter();
    case 'local':
    default: return new LocalKmsAdapter();
  }
}

module.exports = { createKmsAdapter, LocalKmsAdapter, AwsKmsAdapter, GcpKmsAdapter };
