// HTTP companion server for FormDemo
//
// Exposes MySQL as a simple REST API. No database is hardcoded —
// every endpoint accepts an optional ?db= / body.db parameter so
// any database on the server is reachable.
//
// Endpoints:
//   GET  /connect          — test connection, return server version
//   GET  /databases        — list all databases
//   GET  /tables?db=name   — list tables in a specific database
//   POST /query            — run any SQL  { sql, db?, params? }
//
// Configuration via environment variables:
//   MYSQL_HOST     MYSQL_PORT  MYSQL_USER  MYSQL_PASSWORD
//   HTTP_PORT      (default: 3001)
//
// Run:
//   MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD=secret node server.js

import express from 'express';
import cors    from 'cors';
import mysql   from 'mysql2/promise';

const app = express();
app.use(cors());
app.use(express.json());

// Base config — no database selected; each request picks its own
const baseConfig = {
  host:     process.env.MYSQL_HOST     || 'localhost',
  port:     parseInt(process.env.MYSQL_PORT || '3306', 10),
  user:     process.env.MYSQL_USER     || 'root',
  password: process.env.MYSQL_PASSWORD || '',
};

function connConfig(db) {
  return db ? { ...baseConfig, database: db } : baseConfig;
}

// ── GET /connect?db=name ─────────────────────────────────────────────────────

app.get('/connect', async (req, res) => {
  let conn;
  try {
    conn = await mysql.createConnection(connConfig(req.query.db));
    const [[row]] = await conn.execute(
      'SELECT VERSION() AS version, DATABASE() AS db'
    );
    res.json({ ok: true, version: row.version, database: row.db || null });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  } finally {
    if (conn) await conn.end();
  }
});

// ── GET /databases ────────────────────────────────────────────────────────────

app.get('/databases', async (req, res) => {
  let conn;
  try {
    conn = await mysql.createConnection(baseConfig);
    const [rows] = await conn.execute('SHOW DATABASES');
    const names = rows.map(r => Object.values(r)[0]);
    res.json({ ok: true, databases: names });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  } finally {
    if (conn) await conn.end();
  }
});

// ── GET /tables?db=name ───────────────────────────────────────────────────────

app.get('/tables', async (req, res) => {
  const db = req.query.db;
  if (!db) return res.status(400).json({ ok: false, error: 'db query param required' });
  let conn;
  try {
    conn = await mysql.createConnection(connConfig(db));
    const [rows] = await conn.execute('SHOW TABLES');
    const names = rows.map(r => Object.values(r)[0]);
    res.json({ ok: true, tables: names });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  } finally {
    if (conn) await conn.end();
  }
});

// ── POST /query ───────────────────────────────────────────────────────────────

app.post('/query', async (req, res) => {
  const { sql, db, params } = req.body;
  if (!sql) return res.status(400).json({ ok: false, error: 'sql is required' });
  let conn;
  try {
    conn = await mysql.createConnection(connConfig(db));
    const [rows] = await conn.execute(sql, params ?? []);
    res.json({ ok: true, rows });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  } finally {
    if (conn) await conn.end();
  }
});

// ── Start ─────────────────────────────────────────────────────────────────────

const PORT = parseInt(process.env.HTTP_PORT || '3001', 10);
app.listen(PORT, () => {
  console.log(`mysql-http listening on http://localhost:${PORT}`);
  console.log(`  host: ${baseConfig.host}:${baseConfig.port}`);
});
