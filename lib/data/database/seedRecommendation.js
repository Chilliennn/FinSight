/**
 * data/database/seedRecommendations.js

 * USAGE:
 *   node data/database/seedRecommendations.js
 *   node data/database/seedRecommendations.js --force   ← drops existing seed docs first
 *
 * SAFE TO RE-RUN — uses insertOne per doc and catches duplicate key errors gracefully.
 *R
 * FILE LOCATION:  data/database/seedRecommendations.js
 * SEED JSON:      data/database/seeds/recommendations.seed.json
 */

const path = require('path');
const fs   = require('fs');
const { getDb, close } = require('./db');

// ── Allowed enum values (must match recommendation.model.js exactly) ─────────
const VALID_CATEGORIES   = new Set(['Collections', 'Supplier Management', 'Cost Optimization', 'Financing']);
const VALID_DIFFICULTIES = new Set(['Easy Action', 'Medium Action', 'Hard Action']);
const VALID_IMPACT_TYPES = new Set(['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing']);
const VALID_STATUSES     = new Set(['active', 'actioned', 'dismissed', 'expired']);

const SEED_FILE = path.join(__dirname, 'seeds', 'recommendations.seed.json');
const FORCE     = process.argv.includes('--force');

// ── Validate a single raw JSON document ──────────────────────────────────────
function validate(doc, idx) {
  const errors = [];
  if (!doc._id || typeof doc._id !== 'string')          errors.push('_id must be a non-empty string');
  if (!doc.business_id)                                  errors.push('missing business_id');
  if (!doc.risk_id)                                      errors.push('missing risk_id');
  if (!Number.isInteger(doc.rank) || doc.rank < 1)      errors.push(`rank must be a positive integer, got ${doc.rank}`);
  if (!VALID_CATEGORIES.has(doc.category))               errors.push(`invalid category "${doc.category}"`);
  if (!VALID_DIFFICULTIES.has(doc.difficulty))           errors.push(`invalid difficulty "${doc.difficulty}"`);
  if (!VALID_IMPACT_TYPES.has(doc.impact_type))          errors.push(`invalid impact_type "${doc.impact_type}"`);
  if (!VALID_STATUSES.has(doc.status))                   errors.push(`invalid status "${doc.status}"`);
  if (typeof doc.projected_impact_value !== 'number' || doc.projected_impact_value < 0)
                                                         errors.push('projected_impact_value must be a non-negative number');
  if (!doc.action_title?.trim())                         errors.push('missing action_title');
  if (!doc.action_plan?.trim())                          errors.push('missing action_plan');
  if (!doc.reasoning?.trim())                            errors.push('missing reasoning');
  if (!Array.isArray(doc.action_steps) || doc.action_steps.length === 0)
                                                         errors.push('action_steps must be a non-empty array');
  if (!doc.generated_at)                                 errors.push('missing generated_at');
  if (!doc.expires_at)                                   errors.push('missing expires_at');

  if (errors.length > 0) {
    throw new Error(`Document #${idx + 1} (_id: ${doc._id ?? 'unknown'}) failed validation:\n  ${errors.join('\n  ')}`);
  }
}

// ── Transform a validated JSON doc into a MongoDB-ready document ──────────────
function transform(doc) {
  return {
    _id:         doc._id,                    // string hex — schema bsonType: 'string'
    business_id: doc.business_id,
    risk_id:     doc.risk_id,

    rank:       doc.rank,                    // already int from JSON
    category:   doc.category,
    difficulty: doc.difficulty,
    timeframe:  (doc.timeframe ?? '').trim(),

    action_title: doc.action_title.trim(),
    action_plan:  doc.action_plan.trim(),
    reasoning:    doc.reasoning.trim(),

    projected_impact_value: doc.projected_impact_value,
    impact_type:            doc.impact_type,

    action_steps: doc.action_steps.map((s, i) => ({
      step_number: Number.isInteger(s.step_number) ? s.step_number : i + 1,
      description: s.description.trim(),
    })),

    related_reference: doc.related_reference ?? null,

    status:      doc.status,
    actioned_at: doc.actioned_at ? new Date(doc.actioned_at) : null,  // BSON Date or null
    generated_at: new Date(doc.generated_at),                          // BSON Date
    expires_at:   new Date(doc.expires_at),                            // BSON Date
  };
}

// ── Main ─────────────────────────────────────────────────────────────────────
(async () => {
  let inserted = 0, skipped = 0, failed = 0;

  try {
    // Read seed file
    if (!fs.existsSync(SEED_FILE)) {
      console.error(`\n[SEED ERROR] Seed file not found: ${SEED_FILE}`);
      console.error('  Create it at: data/database/seeds/recommendations.seed.json\n');
      process.exit(1);
    }

    const raw = JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));
    if (!Array.isArray(raw) || raw.length === 0) {
      console.error('\n[SEED ERROR] Seed file must contain a non-empty JSON array\n');
      process.exit(1);
    }

    console.log(`\n── FinSight AI: Seeding recommendations (${raw.length} docs) ──────────\n`);

    const db   = await getDb();
    const coll = db.collection('recommendations');

    // --force: remove all documents whose _id appears in the seed file
    if (FORCE) {
      const seedIds = raw.map(d => d._id).filter(Boolean);
      const { deletedCount } = await coll.deleteMany({ _id: { $in: seedIds } });
      if (deletedCount > 0) {
        console.log(`  [--force] Removed ${deletedCount} existing seed document(s)\n`);
      }
    }

    // Validate all docs first — fail fast before any DB writes
    console.log('  Validating documents...');
    raw.forEach((doc, idx) => validate(doc, idx));
    console.log(`  ✓ All ${raw.length} documents passed validation\n`);

    // Insert one by one so a single failure doesn't abort the whole batch
    for (const rawDoc of raw) {
      const doc = transform(rawDoc);
      try {
        await coll.insertOne(doc);
        console.log(`  ✓ Inserted  ${doc._id}  (${doc.business_id} · ${doc.category} · rank ${doc.rank})`);
        inserted++;
      } catch (err) {
        if (err.code === 11000) {
          // Duplicate key — document already exists
          console.log(`  ↷ Skipped   ${doc._id}  (already exists — run with --force to overwrite)`);
          skipped++;
        } else {
          console.error(`  ✗ Failed    ${doc._id}  → ${err.message}`);
          failed++;
        }
      }
    }

    console.log(`
── Seed complete ───────────────────────────────────────────────
   Inserted : ${inserted}
   Skipped  : ${skipped}  (already existed)
   Failed   : ${failed}
────────────────────────────────────────────────────────────────\n`);

    if (failed > 0) process.exit(1);

  } catch (err) {
    console.error('\n[SEED ERROR]', err.message);
    process.exit(1);
  } finally {
    await close();
  }
})();
