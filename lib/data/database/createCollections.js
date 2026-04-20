//createCollections.js
const { ensureCollections, close } = require('./db');

const models = [
  require('./models/business'),
  require('./models/document'),
  require('./models/transaction'),
  require('./models/riskAlert'),
  require('./models/recommendation'),
  require('./models/forecastScenario')
];

(async () => {
  try {
    console.log('Ensuring collections and validators...');
    await ensureCollections(models);
    console.log('Done.');
  } catch (err) {
    console.error('Error creating collections:', err);
  } finally {
    await close();
  }
})();
