const { getDb, close } = require('./db');       

const models = [
  require('../models/recommendation'),
  // require('./models/business'),
  // require('./models/riskAlert'),
  // require('./models/transaction'),
  // require('./models/forecastScenario'),
  // require('./models/document'),
];

(async () => {
  try {
    const db = await getDb();
    console.log('\n── FinSight AI: Creating Indexes ──────────────────────────────\n');

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
    console.error('\n[INDEX ERROR]', err.message);
    process.exit(1);
  } finally {
    await close();
  }
})();