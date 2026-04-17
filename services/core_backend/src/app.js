// Feature: continuum-ml-pipelines
// Express app setup — exported for testing

require('dotenv').config();

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');
const authRoutes = require('./routes/auth');
const policiesRoutes = require('./routes/policies');
const payoutsRoutes = require('./routes/payouts');
const claimsRoutes = require('./routes/claims');
const workersRoutes = require('./routes/workers');
const mandatesRoutes = require('./routes/mandates');
const reservesRoutes = require('./routes/reserves');
const consentRoutes = require('./routes/consent');
const adminRoutes = require('./routes/admin');
const { createMetricsHandler } = require('./services/metrics');
const { startAllConsumers } = require('./consumers/index');
const db = require('./db');

const app = express();

// CORS middleware (must run before routes)
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }

  return next();
});

// JSON body parser
app.use(express.json());
app.use(helmet());

const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS
  ? process.env.CORS_ALLOWED_ORIGINS.split(',').map(s => s.trim())
  : [];
app.use(cors({
  origin: allowedOrigins.length > 0 ? allowedOrigins : false,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400,
}));

const globalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_requests' },
});
app.use(globalLimiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'too_many_requests' },
  keyGenerator: (req) => req.ip,
});

app.use((req, _res, next) => {
  req.requestId = req.headers['x-request-id'] || uuidv4();
  next();
});

startAllConsumers().catch(err => {
  console.error('[app] Failed to start Kafka consumers:', err.message);
});

app.use(express.json());

app.use('/auth', authLimiter, authRoutes);
app.use('/policies', policiesRoutes);
app.use('/payouts', payoutsRoutes);
app.use('/claims', claimsRoutes);
app.use('/workers', workersRoutes);
app.use('/mandates', mandatesRoutes);
app.use('/reserves', reservesRoutes);
app.use('/consent', consentRoutes);
app.use('/admin', adminRoutes);

app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// Prometheus metrics — Requirements 16.1, 16.4
app.get('/metrics', createMetricsHandler(db));

app.use((err, req, res, _next) => { // eslint-disable-line no-unused-vars
  const status = err.status || 500;
  const requestId = req.requestId || 'unknown';

  const logger = require('./utils/logger');
  logger.error(err.message, {
    requestId,
    method: req.method,
    path: req.originalUrl,
    status,
    stack: err.stack,
  });

  if (status >= 500) {
    return res.status(status).json({ error: 'internal_server_error', requestId });
  }
  return res.status(status).json({ error: err.message || 'request_error', requestId });
});

module.exports = app;
