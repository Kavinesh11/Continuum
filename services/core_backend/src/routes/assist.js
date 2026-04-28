// Feature: continuum-ml-pipelines
// AI Assistant chat endpoints — integration with RASA + Gemini
// Requirements: 15.1, 15.2, 15.5

'use strict';

const express = require('express');
const { authenticate } = require('../middleware/auth');
const { requireRole } = require('../middleware/rbac');
const db = require('../db');
const kafka = require('../services/kafka');

const router = express.Router();

const RASA_ASSISTANT_URL = process.env.RASA_ASSISTANT_URL || 'http://localhost:8002';
const MAX_MESSAGE_LENGTH = 1000;

/**
 * POST /assist/chat
 * Send a message to the AI assistant (RASA + Gemini integration)
 * Returns AI-generated response with fraud flags if applicable.
 * Requirements: 15.1, 15.2
 */
router.post('/chat', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { message } = req.body;
    const { worker_id } = req.user;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'message_required' });
    }

    if (message.length > MAX_MESSAGE_LENGTH) {
      return res.status(400).json({ error: 'message_too_long', max_length: MAX_MESSAGE_LENGTH });
    }

    // Call RASA Assistant service
    let assistResponse;
    try {
      const fetch = require('node-fetch');
      const rasaResp = await fetch(`${RASA_ASSISTANT_URL}/message`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: message.trim(),
          worker_id,
          sender: 'worker',
        }),
        timeout: 10000,
      });

      if (!rasaResp.ok) {
        throw new Error(`RASA returned ${rasaResp.status}`);
      }

      assistResponse = await rasaResp.json();
    } catch (rasaErr) {
      console.warn('[assist] RASA service unavailable:', rasaErr.message);
      // Fallback: return a generic response
      assistResponse = {
        text: 'I encountered an issue processing your request. Please try again.',
        intent: 'unknown',
        confidence: 0.0,
      };
    }

    // Store chat history in DB (non-critical)
    try {
      await db.query(
        `INSERT INTO assist_messages (worker_id, role, message, response, created_at)
         VALUES ($1, 'worker', $2, $3, NOW())`,
        [
          worker_id,
          message.trim(),
          assistResponse.text || '',
        ]
      );
    } catch (dbErr) {
      console.warn('[assist] Failed to store message:', dbErr.message);
      // Non-fatal; continue
    }

    // Publish to Kafka for analytics (non-critical)
    try {
      await kafka.publishEvent('assist_interaction', {
        worker_id,
        message: message.trim(),
        response: assistResponse.text || '',
        intent: assistResponse.intent || 'unknown',
        confidence: assistResponse.confidence || 0.0,
        timestamp: new Date().toISOString(),
      });
    } catch (kafkaErr) {
      console.warn('[assist] Kafka publish failed:', kafkaErr.message);
    }

    return res.status(200).json({
      text: assistResponse.text || 'I couldn\'t process that. Please rephrase.',
      intent: assistResponse.intent || 'unknown',
      confidence: assistResponse.confidence || 0.0,
      escalated: assistResponse.escalated === true,
      agent_name: assistResponse.agent_name || null,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * GET /assist/messages
 * Get conversation history for the authenticated worker.
 * Requirements: 15.1
 */
router.get('/messages', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { worker_id } = req.user;
    const limit = Math.min(parseInt(req.query.limit) || 50, 100);

    try {
      const result = await db.query(
        `SELECT worker_id, role, message, response, created_at
         FROM assist_messages
         WHERE worker_id = $1
         ORDER BY created_at DESC
         LIMIT $2`,
        [worker_id, limit]
      );

      const messages = result.rows.reverse().flatMap(row => [
        {
          role: 'worker',
          text: row.message,
          time: row.created_at instanceof Date
            ? row.created_at.toISOString()
            : row.created_at,
        },
        {
          role: 'assistant',
          text: row.response,
          time: row.created_at instanceof Date
            ? row.created_at.toISOString()
            : row.created_at,
        },
      ]);

      return res.status(200).json(messages);
    } catch (dbErr) {
      if (dbErr.code === 'ENOENT' || dbErr.message.includes('undefined table')) {
        // Table doesn't exist yet; return empty
        return res.status(200).json([]);
      }
      throw dbErr;
    }
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /assist/messages
 * Clear conversation history for the authenticated worker.
 * Requirements: 15.1
 */
router.delete('/messages', authenticate, requireRole('worker', 'admin'), async (req, res, next) => {
  try {
    const { worker_id } = req.user;

    try {
      await db.query(
        'DELETE FROM assist_messages WHERE worker_id = $1',
        [worker_id]
      );
    } catch (dbErr) {
      if (!dbErr.message.includes('undefined table')) {
        throw dbErr;
      }
    }

    return res.status(200).json({ cleared: true });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
