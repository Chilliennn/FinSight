/**
 * FinSight AI — Backend Server Entry Point
 * Run:  node lib/app.js
 */

require('dotenv').config();

const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const express = require('express');
const cors    = require('cors');


// const { connect, ensureCollections, close } = require('./data/databa../../database/db');
// const riskAlertModel       = require('./data/models/riskAlert');
// const risksRoute           = require('./application/routes/risksRoute');
// const recommendationRoutes = require('./application/routes/recommendationRoutes');

const { connect, ensureCollections, close } = require('./data/database/db');
const riskAlertModel = require('./data/models/riskAlert');
const risksRoute = require('./application/routes/risksRoute');
const recommendationRoutes = require('./application/routes/recommendationRoutes');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/risks',           risksRoute);
app.use('/api/recommendations', recommendationRoutes);

// Health check — useful for confirming the server is up
app.get('/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok' }, error: null });
});

// ── Startup ───────────────────────────────────────────────────────────────────
async function start() {
  try {
    await connect();
    console.log('[app] MongoDB connected');

    await ensureCollections([riskAlertModel]);
    console.log('[app] risk_alerts collection ready');

    app.listen(PORT, () => {
      console.log(`[app] FinSight backend listening on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('[app] startup failed:', err);
    await close();
    process.exit(1);
  }
}

start();

