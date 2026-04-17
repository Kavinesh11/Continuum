// Feature: continuum-ml-pipelines
// PostgreSQL/CockroachDB client using pg Pool

const { Pool } = require('pg');
const fs = require('fs');

function buildSslConfig() {
  if (process.env.DB_SSL !== 'true') return false;

  const rejectUnauthorized = process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false';
  const ssl = { rejectUnauthorized };

  if (process.env.DB_CA_CERT_PATH) {
    ssl.ca = fs.readFileSync(process.env.DB_CA_CERT_PATH, 'utf8');
  } else if (process.env.DB_CA_CERT) {
    ssl.ca = process.env.DB_CA_CERT;
  }

  if (!rejectUnauthorized) {
    console.warn('[db] WARNING: DB_SSL_REJECT_UNAUTHORIZED=false disables certificate verification — MITM risk');
  }

  return ssl;
}

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'continuum',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  ssl: buildSslConfig(),
});

module.exports = pool;
