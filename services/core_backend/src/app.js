// Feature: continuum-ml-pipelines
// Express app setup — exported for testing

require('dotenv').config();

const express = require('express');
const authRoutes = require('./routes/auth');

const app = express();

// JSON body parser
app.use(express.json());

// Mount auth routes
app.use('/auth', authRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Global error handler
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'internal_server_error' });
});

module.exports = app;
