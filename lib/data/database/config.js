
require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') });

const required = ['MONGODB_URI', 'ZAI_API_KEY'];
for (const key of required) {
  if (!process.env[key]) {
    throw new Error(
      `[config] Missing required environment variable: ${key}\n` +
      `  → Check that F:\\FinSight-main\\.env exists and contains ${key}=...`
    );
  }
}

module.exports = {
  uri:    process.env.MONGODB_URI,
  dbName: process.env.DB_NAME || 'finsight',

  zaiApiKey:  process.env.ZAI_API_KEY,
  zaiBaseUrl: process.env.ZAI_BASE_URL || 'https://open.bigmodel.cn/api/paas/v4',
  zaiModel:   process.env.ZAI_MODEL    || 'glm-4-flash',

  port:     parseInt(process.env.PORT || '3000', 10),
  nodeEnv:  process.env.NODE_ENV || 'development',
};

