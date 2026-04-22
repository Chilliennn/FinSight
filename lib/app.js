/**
 * FinSight AI — Backend Server Entry Point
 *
 * Responsibilities:
 *   - Load environment variables (.env)
 *   - Connect to MongoDB Atlas via team's existing db.js
 *   - Ensure risk_alerts collection exists with schema validator
 *   - Mount REST routes
 *   - Start Express on the configured port
 *
 * Run:  node lib/app.js
 */

require('dotenv').config();

// Force Google DNS — Node.js 24 on Windows sometimes refuses SRV queries
// when using the system's default DNS resolver. This affects `mongodb+srv://`.
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const express = require('express');
const cors = require('cors');

const { connect, ensureCollections, close } = require('./data/database/db');
const { riskAlertModel, documentsModel, financialRecordsModel, documentChunksModel } = require('./data/models');
const risksRoute = require('./application/routes/risksRoute');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

// Mount risks routes
app.use('/api/risks', risksRoute);

// Health check — useful for confirming the server is up
app.get('/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok' }, error: null });
});

async function start() {
  try {
    await connect();
    console.log('[app] MongoDB connected');

    // Only ensure collections this feature owns.
    // Other teammates' models should be ensured by their own code or a shared init.
    await ensureCollections([riskAlertModel, documentsModel, financialRecordsModel, documentChunksModel]);
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