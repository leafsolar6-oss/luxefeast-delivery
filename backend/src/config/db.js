require('dotenv').config();
const { Pool } = require('pg');

// DATABASE_URL works with any Postgres — paste your Neon connection string in .env:
//   DATABASE_URL=postgresql://user:password@ep-xxxx.eu-central-1.aws.neon.tech/luxefeast?sslmode=require
const connectionString =
  process.env.DATABASE_URL || 'postgresql://luxefeast:luxefeast@localhost:5432/luxefeast';

const needsSSL = /neon\.tech|sslmode=require/i.test(connectionString);

const pool = new Pool({
  connectionString,
  ssl: needsSSL ? { rejectUnauthorized: false } : false,
  max: 10,
  idleTimeoutMillis: 30000,
});

pool.on('error', (err) => console.error('Unexpected PG pool error:', err.message));

const query = (text, params) => pool.query(text, params);

module.exports = { pool, query };
