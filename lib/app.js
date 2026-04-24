const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const requiredEnv = ['MONGODB_URI', 'DB_NAME', 'ZAI_API_KEY', 'ZAI_BASE_URL', 'ZAI_MODEL'];
const missing = requiredEnv.filter((k) => !process.env[k]);
if (missing.length > 0) {
  console.error('[app] Missing required env vars:', missing.join(', '));
  process.exit(1);
}

const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const express = require('express');
const cors    = require('cors');

const { connect, ensureCollections, close } = require('./data/database/db');
const riskAlertModel       = require('./data/models/risk_alert');
const businessModel        = require('./data/models/business');
const risksRoute           = require('./application/routes/risksRoute');
const businessRoutes       = require('./application/routes/businessRoutes');
const recommendationRoutes = require('./application/routes/recommendationRoutes');

const PORT = process.env.PORT || 3000;

const app = express();
app.use(cors());
app.use(express.json());

console.log('[app] Registering routes...');
app.use('/api/risks',           risksRoute);
app.use('/api/businesses', (req, _res, next) => {
  console.log('[app] /api/businesses hit:', req.method, req.originalUrl, 'path=', req.path);
  next();
});
app.use('/api/businesses',       businessRoutes);
app.use('/api/recommendations', recommendationRoutes);
console.log(
  '[app] businessRoutes methods:',
  businessRoutes.stack.map((l) => ({ path: l.route?.path, methods: l.route?.methods })),
);
console.log('[app] Routes registered successfully');

app.get('/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok' }, error: null });
});

async function start() {
  try {
    await connect();
    await ensureCollections([riskAlertModel, businessModel]);

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
