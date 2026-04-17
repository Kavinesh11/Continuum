// Feature: continuum-ml-pipelines
// Server entry point

require('dotenv').config();

const { validateEnv } = require('./config/env');

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

app.listen(PORT, HOST, () => {
  console.log(`Core Backend listening on http://${HOST}:${PORT}`);
let env;
try {
  env = validateEnv();
} catch (err) {
  console.error('[startup] Environment validation failed:', err.message);
  process.exit(1);
}

const app = require('./app');

app.listen(env.PORT, () => {
  console.log(`Core Backend listening on port ${env.PORT}`);
});
