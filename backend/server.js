const express = require('express');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3000;

// Build-time metadata baked in via Docker ARG -> ENV. NOT secrets.
const VERSION = process.env.BUILD_VERSION || 'dev';
const GIT_SHA = process.env.GIT_SHA || 'unknown';
const BUILT_AT = process.env.BUILT_AT || 'unknown';

// Runtime secrets — injected via env_file at container start, never baked into the image.
const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

app.use(express.json());

// Liveness/readiness probe used by docker-compose healthcheck and CI post-deploy check.
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ok', db: 'connected' });
  } catch (err) {
    res.status(503).json({ status: 'degraded', db: 'unreachable', error: err.message });
  }
});

// This is the source of truth for "what version is running right now."
app.get('/api/version', (req, res) => {
  res.status(200).json({
    service: 'backend',
    version: VERSION,
    gitSha: GIT_SHA,
    builtAt: BUILT_AT,
  });
});

app.get('/api/status', (req, res) => {
  res.status(200).json({
    message: 'FormFlow backend is running',
    version: VERSION,
  });
});

app.listen(PORT, () => {
  console.log(`FormFlow backend ${VERSION} (${GIT_SHA}) listening on port ${PORT}`);
});