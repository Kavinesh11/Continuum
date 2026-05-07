'use strict';

const PINATA_JSON_URL = 'https://api.pinata.cloud/pinning/pinJSONToIPFS';
const PINATA_FILE_URL = 'https://api.pinata.cloud/pinning/pinFileToIPFS';

function _jwt() {
  const jwt = process.env.PINATA_JWT;
  if (!jwt) throw new Error('PINATA_JWT env var is not set');
  return jwt;
}

/**
 * Upload a JSON object to Pinata IPFS and return the CID.
 *
 * @param {object} content   — plain JSON-serialisable object
 * @param {string} label     — pinataMetadata.name visible in Pinata dashboard
 * @returns {Promise<string>} IPFS CID (IpfsHash)
 */
async function pinToIPFS(content, label) {
  const response = await fetch(PINATA_JSON_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${_jwt()}`,
    },
    body: JSON.stringify({
      pinataContent: content,
      pinataMetadata: { name: label },
      pinataOptions: { cidVersion: 1 },
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Pinata JSON upload failed (${response.status}): ${text}`);
  }

  return (await response.json()).IpfsHash;
}

/**
 * Upload a single file buffer to Pinata IPFS and return the CID.
 *
 * Filename convention: {platform}_{worker_id}_{label}_{timestamp}.{ext}
 * e.g. swiggy_DL789456_photo_1_20260504T123456.jpg
 *
 * @param {Buffer}  buffer    — raw file bytes
 * @param {string}  filename  — full filename including extension
 * @param {string}  mimeType  — e.g. 'image/jpeg'
 * @returns {Promise<string>} IPFS CID
 */
async function pinFileToIPFS(buffer, filename, mimeType) {
  const formData = new FormData();
  // Blob + named append mirrors multipart/form-data file upload
  formData.append('file', new Blob([buffer], { type: mimeType }), filename);
  formData.append(
    'pinataMetadata',
    JSON.stringify({ name: filename })
  );
  formData.append(
    'pinataOptions',
    JSON.stringify({ cidVersion: 1 })
  );

  const response = await fetch(PINATA_FILE_URL, {
    method: 'POST',
    // Do NOT set Content-Type manually — fetch sets multipart boundary automatically
    headers: { Authorization: `Bearer ${_jwt()}` },
    body: formData,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Pinata file upload failed (${response.status}): ${text}`);
  }

  return (await response.json()).IpfsHash;
}

/**
 * Build a Pinata filename for a worker photo.
 * Uses platform + worker_id as the primary identifier (matches the Swiggy/Zomato ID).
 *
 * @param {string} platform   — 'swiggy' | 'zomato'
 * @param {string} worker_id  — the worker's platform delivery ID
 * @param {string} label      — e.g. 'photo_1', 'id_card', 'selfie'
 * @param {string} ext        — file extension without dot (e.g. 'jpg')
 */
function workerPhotoFilename(platform, worker_id, label, ext = 'jpg') {
  const ts = new Date().toISOString().replace(/[:.]/g, '').slice(0, 15);
  // Sanitise worker_id to keep filenames filesystem-safe
  const safeId = worker_id.replace(/[^a-zA-Z0-9_-]/g, '_');
  return `${platform}_${safeId}_${label}_${ts}.${ext}`;
}

/**
 * Build the worker profile payload for Pinata JSON upload.
 * upi_id is passed in already AES-256-GCM encrypted — IPFS is a public network.
 */
function buildWorkerProfile({ worker_id, platform, tier, encrypted_upi_id, registered_at }) {
  return {
    worker_id,
    platform,
    tier,
    upi_id_enc: encrypted_upi_id,
    registered_at,
    schema_version: 1,
  };
}

module.exports = { pinToIPFS, pinFileToIPFS, workerPhotoFilename, buildWorkerProfile };
