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
const HOST = process.env.HOST || '0.0.0.0';

app.listen(env.PORT, HOST, () => {
  console.log(`Core Backend listening on http://${HOST}:${env.PORT}`);
});
