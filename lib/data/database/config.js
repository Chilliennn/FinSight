/**
 * lib/data/database/config.js
 *
 * Loads all environment variables from the .env file at the project root.
 * Never hardcode credentials here — they live in .env only.
 *
 * .env location: F:\FinSight-main\.env
 * This file location: F:\FinSight-main\lib\data\database\config.js
 * So the path up to root is: ../../../.env  (3 levels up)
 */

require('dotenv').config({ path: require('path').resolve(__dirname, '../../../.env') });

// Fail fast — if a required variable is missing, crash immediately with a clear message
// so you know exactly what's wrong instead of getting a confusing error later.
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
  // MongoDB
  uri:    process.env.MONGODB_URI,
  dbName: process.env.DB_NAME || 'finsight',

  // Z.AI
  zaiApiKey:  process.env.ZAI_API_KEY,
  zaiBaseUrl: process.env.ZAI_BASE_URL || 'https://open.bigmodel.cn/api/paas/v4',
  zaiModel:   process.env.ZAI_MODEL    || 'glm-4-flash',

  // Server
  port:     parseInt(process.env.PORT || '3000', 10),
  nodeEnv:  process.env.NODE_ENV || 'development',
};