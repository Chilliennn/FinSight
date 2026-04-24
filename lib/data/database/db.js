// lib/data/database/db.js
const { MongoClient, ServerApiVersion } = require('mongodb');
const { uri, dbName } = require('./config');

const client = new MongoClient(uri, {
  serverApi: {
    version: ServerApiVersion.v1,
    strict: true,
    deprecationErrors: true,
  },
  tls: true,
  tlsAllowInvalidCertificates: process.env.NODE_ENV === 'development',
  tlsAllowInvalidHostnames:    process.env.NODE_ENV === 'development',
});

let _connected = false;

async function connect() {
  if (!_connected) {
    await client.connect();
    _connected = true;
  }
  return client;
}

async function getDb(name = dbName) {
  await connect();
  return client.db(name);
}

async function close() {
  if (_connected) {
    await client.close();
    _connected = false;
  }
}

async function ensureCollection(model) {
  const db = await getDb();
  const name = model.name;
  const existing = await db.listCollections({ name }).toArray();
  if (existing.length === 0) {
    await db.createCollection(name, {
      validator: { $jsonSchema: model.schema },
      validationLevel: 'moderate'
    });
    console.log(`  Created collection: ${name}`);
  } else {
    try {
      await db.command({
        collMod: name,
        validator: { $jsonSchema: model.schema },
        validationLevel: 'moderate'
      });
      console.log(`  Updated validator for: ${name}`);
    } catch (err) {
      console.log(`  Could not modify validator for ${name}: ${err.message}`);
    }
  }
}

async function ensureCollections(models) {
  for (const m of models) {
    await ensureCollection(m);
  }
}

module.exports = { connect, getDb, close, ensureCollection, ensureCollections };

