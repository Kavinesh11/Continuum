'use strict';

const { Client } = require('pg');
const { readFileSync } = require('fs');
const path = require('path');

const PG_DSN = process.env.TEST_PG_DSN || 'postgresql://test:test@localhost:15432/continuum_test';
const CRDB_DSN = process.env.TEST_CRDB_DSN || 'postgresql://root@localhost:16257/defaultdb?sslmode=disable';

async function runMigrations(client, dir) {
  const migrationsDir = path.resolve(__dirname, '../../db/migrations', dir);
  const fs = require('fs');
  const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();

  for (const file of files) {
    const sql = readFileSync(path.join(migrationsDir, file), 'utf8');
    try {
      await client.query(sql);
    } catch (err) {
      if (err.message.includes('already exists') || err.message.includes('does not exist')) {
        continue;
      }
      console.warn(`Migration ${file} warning: ${err.message}`);
    }
  }
}

async function seedData(client) {
  const seedSql = readFileSync(path.join(__dirname, 'seed.sql'), 'utf8');
  await client.query(seedSql);
}

async function setupPostgres() {
  const client = new Client({ connectionString: PG_DSN });
  await client.connect();

  await client.query('CREATE EXTENSION IF NOT EXISTS postgis');
  await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');

  await runMigrations(client, 'postgres');
  await seedData(client);
  await client.end();
  return PG_DSN;
}

async function setupCockroach() {
  const client = new Client({ connectionString: CRDB_DSN });
  await client.connect();

  await client.query('CREATE DATABASE IF NOT EXISTS continuum_test');
  await client.query('USE continuum_test');
  await runMigrations(client, 'cockroachdb');
  await client.end();

  return CRDB_DSN.replace('defaultdb', 'continuum_test');
}

async function setup() {
  console.log('[integration] Setting up test databases...');
  const pgDsn = await setupPostgres();
  const crdbDsn = await setupCockroach();
  console.log('[integration] Databases ready.');
  return { pgDsn, crdbDsn };
}

async function teardown() {
  const pgClient = new Client({ connectionString: PG_DSN });
  await pgClient.connect();
  await pgClient.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  await pgClient.end();

  const crdbClient = new Client({ connectionString: CRDB_DSN });
  await crdbClient.connect();
  await crdbClient.query('DROP DATABASE IF EXISTS continuum_test CASCADE');
  await crdbClient.end();
}

module.exports = { setup, teardown, PG_DSN, CRDB_DSN };
