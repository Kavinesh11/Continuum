// Feature: continuum-ml-pipelines
// Express app setup — exported for testing

require('dotenv').config();

const express = require('express');
const authRoutes = require('./routes/auth');
const policiesRoutes = require('./routes/policies');
const payoutsRoutes = require('./routes/payouts');
const claimsRoutes = require('./routes/claims');
const workersRoutes = require('./routes/workers');
const mandatesRoutes = require('./routes/mandates');
const { createMetricsHandler } = require('./services/metrics');
const db = require('./db');

const app = express();

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

// Mount mandates routes
app.use('/mandates', mandatesRoutes);

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
