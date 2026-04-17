// Feature: continuum-ml-pipelines
// Express app setup — exported for testing

require('dotenv').config();

const express = require('express');
const authRoutes = require('./routes/auth');
const policiesRoutes = require('./routes/policies');
const payoutsRoutes = require('./routes/payouts');
const claimsRoutes = require('./routes/claims');
const workersRoutes = require('./routes/workers');
const { createMetricsHandler } = require('./services/metrics');
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

// Mount auth routes
app.use('/auth', authRoutes);

// Mount policies routes
app.use('/policies', policiesRoutes);

// Mount payouts routes
app.use('/payouts', payoutsRoutes);

// Mount claims routes
app.use('/claims', claimsRoutes);

// Mount workers routes
app.use('/workers', workersRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Prometheus metrics — Requirements 16.1, 16.4
app.get('/metrics', createMetricsHandler(db));

// Global error handler
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'internal_server_error' });
});

module.exports = app;
