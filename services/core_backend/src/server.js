// Feature: continuum-ml-pipelines
// Server entry point

require('dotenv').config();

const { validateEnv } = require('./config/env');

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
