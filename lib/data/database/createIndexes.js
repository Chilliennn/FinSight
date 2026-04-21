/**
 * data/database/createIndexes.js
*/

const { getDb, close } = require('./db');

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
    const db = await getDb();
    console.log('\n── FinSight AI: Applying Schemas & Creating Indexes ───────────\n');

    for (const model of models) {
      // ── 1. Apply JSON Schema validator
      if (model.schema) {
        const existingCollections = await db
          .listCollections({ name: model.name })
          .toArray();

        if (existingCollections.length === 0) {
          await db.createCollection(model.name, {
            validator: { $jsonSchema: model.schema },
            validationLevel:  'strict',   // reject inserts AND updates that violate schema
            validationAction: 'error',    // throw an error (not just warn)
          });
          console.log(`  [${model.name}] Collection created with schema validator`);
        } else {
          await db.command({
            collMod:          model.name,
            validator:        { $jsonSchema: model.schema },
            validationLevel:  'strict',
            validationAction: 'error',
          });
          console.log(`  [${model.name}] Schema validator updated on existing collection`);
        }
      } else {
        console.log(`  [${model.name}] No schema defined — skipping validator`);
      }

      // ── 2. Create indexes 
      if (!Array.isArray(model.indexes) || model.indexes.length === 0) {
        console.log(`  [${model.name}] No indexes defined — skipping`);
        continue;
      }

      console.log(`  [${model.name}] Creating ${model.indexes.length} index(es)...`);
      const coll = db.collection(model.name);

      for (const indexDef of model.indexes) {
        const { key, name, ...options } = indexDef;
        try {
          await coll.createIndex(key, { name, background: true, ...options });
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