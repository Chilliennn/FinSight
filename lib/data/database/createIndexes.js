/**
 * lib/data/database/createIndexes.js
 *
 * Run once (or in CI) to:
 *   1. Create/update the recommendations collection with JSON Schema validator
 *      (delegated to ensureCollections() already in db.js)
 *   2. Create all indexes defined in each model file
 *
 * Usage (from project root):
 *   node lib/data/database/createIndexes.js
 */

const { getDb, close, ensureCollections } = require('./db');

// Models live at lib/data/models/ — one level up from lib/data/database/
const models = [
  require('../models/recommendation'),
  // require('../models/business'),
  // require('../models/riskAlert'),
  // require('../models/transaction'),
  // require('../models/forecastScenario'),
  // require('../models/document'),
];

(async () => {
  try {
    console.log('\n── FinSight AI: Applying Schemas & Creating Indexes ───────────\n');

    // Step 1: Create collections + apply validators (uses db.js ensureCollections)
    await ensureCollections(models);

    // Step 2: Create indexes for each model
    const db = await getDb();

    for (const model of models) {
      if (!Array.isArray(model.indexes) || model.indexes.length === 0) {
        console.log(`  [${model.name}] No indexes defined — skipping`);
        continue;
      }

      console.log(`  [${model.name}] Creating ${model.indexes.length} index(es)...`);
      const coll = db.collection(model.name);

      for (const indexDef of model.indexes) {
        const { key, name, ...options } = indexDef;
        try {
          await coll.createIndex(key, { name, ...options });
          console.log(`    ✓ ${name}  →  ${JSON.stringify(key)}`);
        } catch (err) {
          if (err.codeName === 'IndexKeySpecsConflict') {
            console.error(`    ✗ ${name} already exists with different keys.`);
            console.error(`      Drop it first:  db.${model.name}.dropIndex("${name}")`);
          }
          throw err;
        }
      }
    }

    console.log('\n── Done ────────────────────────────────────────────────────────\n');
  } catch (err) {
    console.error('\n[SETUP ERROR]', err.message);
    process.exit(1);
  } finally {
    await close();
  }
})();
