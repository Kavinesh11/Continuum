'use strict';

// POST /documents/upload
// Accepts multipart/form-data with one or more photo files, pins each to Pinata IPFS,
// and returns the array of CIDs. Files are named using the authenticated worker's
// platform + worker_id so they are traceable without exposing the internal UUID.

const express = require('express');
const multer = require('multer');
const { authenticate } = require('../middleware/auth');
const { pinFileToIPFS, workerPhotoFilename } = require('../utils/pinata');

const router = express.Router();

// Store uploads in memory — we stream straight to Pinata, never write to disk.
// 10 MB per file, max 10 files per request.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 10 },
  fileFilter(_req, file, cb) {
    if (!file.mimetype.startsWith('image/')) {
      return cb(new Error('only_image_files_allowed'));
    }
    cb(null, true);
  },
});

/**
 * POST /documents/upload
 * Requires Bearer JWT (any role).
 * Field name: "photos" (multiple allowed).
 * Returns: { cids: [{ filename, cid }] }
 */
router.post(
  '/upload',
  authenticate,
  upload.array('photos', 10),
  async (req, res, next) => {
    try {
      const { worker_id, platform } = req.user;

      if (!req.files || req.files.length === 0) {
        return res.status(400).json({ error: 'no_files_uploaded' });
      }

      const results = [];

      for (let i = 0; i < req.files.length; i++) {
        const file = req.files[i];
        const ext = file.mimetype.split('/')[1] || 'jpg';
        const label = `photo_${i + 1}`;
        const filename = workerPhotoFilename(platform, worker_id, label, ext);

        const cid = await pinFileToIPFS(file.buffer, filename, file.mimetype);
        results.push({ filename, cid });
      }

      return res.status(200).json({ cids: results });
    } catch (err) {
      next(err);
    }
  }
);

module.exports = router;
