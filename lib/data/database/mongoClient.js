// lib/data/database/mongoClient.js
const { MongoClient, ServerApiVersion } = require('mongodb');
const uri = "mongodb+srv://chillien:Wxs3ai2XWTlya6Qt@finsight.qnfswzc.mongodb.net/?appName=FinSight";

const client = new MongoClient(uri, {
  serverApi: {
    version: ServerApiVersion.v1,
    strict: true,
    deprecationErrors: true,
  }
});

async function run() {
  try {
    await client.connect();
    await client.db("admin").command({ ping: 1 });
    console.log("Pinged your deployment. You successfully connected to MongoDB!");
  } finally {
    await client.close();
  }
}
run().catch(console.dir);
