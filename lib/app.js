const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const requiredEnv = [
  'MONGODB_URI',
  'DB_NAME',
  'ZAI_API_KEY',
  'ZAI_BASE_URL',
  'ZAI_MODEL',
];
const missing = requiredEnv.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error('[app] Missing required env vars:', missing.join(', '));
  process.exit(1);
}

const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const cors = require('cors');
const express = require('express');

const { close, connect, ensureCollections } = require('./data/database/db');
const {
  businessModel,
  documentChunksModel,
  documentsModel,
  financialRecordsModel,
  recommendationModel,
  transactionModel,
  riskAlertModel,
  transactionModel,
} = require('./data/models');

const businessRoutes = require('./application/routes/businessRoutes');
const documentsRoute = require('./application/routes/documentsRoute');
const recommendationRoutes = require('./application/routes/recommendationRoutes');
const risksRoute = require('./application/routes/risksRoute');
const transactionsRoute = require('./application/routes/transactionsRoute');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

console.log('[app] Registering routes...');
app.use('/api/risks', risksRoute);
app.use('/api/businesses', businessRoutes);
app.use('/api/recommendations', recommendationRoutes);
app.use('/api/documents', documentsRoute);
app.use('/api/transactions', transactionsRoute);
console.log('[app] Routes registered successfully');

app.get('/health', (_req, res) => {
  res.json({ success: true, data: { status: 'ok' }, error: null });
});

async function start() {
  try {
    await connect();
    await ensureCollections([
      riskAlertModel,
      businessModel,
      documentsModel,
      financialRecordsModel,
      documentChunksModel,
      transactionModel,
      recommendationModel,
      transactionModel,
    ]);

    const server = app.listen(PORT, () => {
      console.log(`[app] FinSight backend listening on http://localhost:${PORT}`);
    });
    // server.setTimeout(300_000);

  } catch (err) {
    console.error('[app] startup failed:', err);
    await close();
    process.exit(1);
  }
}

start();
