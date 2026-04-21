/**
 * data/database/seedRecommendations.js
 */

const path = require('path');
const fs   = require('fs');
const { getDb, close } = require('./db');

// ── Enums ─────────────────────────────────────────────
const VALID_CATEGORIES   = new Set(['Collections', 'Supplier Management', 'Cost Optimization', 'Financing']);
const VALID_DIFFICULTIES = new Set(['Easy Action', 'Medium Action', 'Hard Action']);
const VALID_IMPACT_TYPES = new Set(['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing']);
const VALID_STATUSES     = new Set(['active', 'actioned', 'dismissed', 'expired']);

const SEED_FILE = path.join(__dirname, 'seeds', 'recommendations.seed.json');
const FORCE = process.argv.includes('--force');

// ── Safe Date Parser ─────────────────────────────────
function parseDate(value) {
  if (!value) return null;

  const date = new Date(value?.$date ?? value);
  return isNaN(date.getTime()) ? null : date;
}

// ── Validation ───────────────────────────────────────
function validate(doc, idx) {
  const errors = [];

  if (!doc._id) errors.push('_id missing');
  if (!doc.business_id) errors.push('missing business_id');
  if (!doc.risk_id) errors.push('missing risk_id');

  if (!Number.isInteger(doc.rank) || doc.rank < 1)
    errors.push('rank must be positive integer');

  if (!VALID_CATEGORIES.has(doc.category))
    errors.push(`invalid category: ${doc.category}`);

  if (!VALID_DIFFICULTIES.has(doc.difficulty))
    errors.push(`invalid difficulty: ${doc.difficulty}`);

  if (!VALID_IMPACT_TYPES.has(doc.impact_type))
    errors.push(`invalid impact_type: ${doc.impact_type}`);

  if (!VALID_STATUSES.has(doc.status))
    errors.push(`invalid status: ${doc.status}`);

  if (typeof doc.projected_impact_value !== 'number' || doc.projected_impact_value < 0)
    errors.push('invalid projected_impact_value');

  if (!doc.action_title?.trim()) errors.push('missing action_title');
  if (!doc.action_plan?.trim()) errors.push('missing action_plan');
  if (!doc.reasoning?.trim()) errors.push('missing reasoning');

  if (!Array.isArray(doc.action_steps) || doc.action_steps.length === 0)
    errors.push('action_steps must be non-empty array');

  const generatedAt = parseDate(doc.generated_at);
  const expiresAt   = parseDate(doc.expires_at);

  if (!generatedAt) errors.push('invalid generated_at');
  if (!expiresAt) errors.push('invalid expires_at');

  if (generatedAt && expiresAt && expiresAt <= generatedAt) {
    errors.push('expires_at must be after generated_at');
  }

  if (errors.length) {
    throw new Error(
      `Document #${idx + 1} (${doc._id}) failed validation:\n- ${errors.join('\n- ')}`
    );
  }
}

// ── Transform ────────────────────────────────────────
function transform(doc) {
  return {
    _id: doc._id,
    business_id: doc.business_id,
    risk_id: doc.risk_id,

    rank: doc.rank,
    category: doc.category,
    difficulty: doc.difficulty,
    timeframe: (doc.timeframe ?? '').trim(),

    action_title: doc.action_title.trim(),
    action_plan: doc.action_plan.trim(),
    reasoning: doc.reasoning.trim(),

    projected_impact_value: doc.projected_impact_value,
    impact_type: doc.impact_type,

    action_steps: doc.action_steps.map((s, i) => ({
      step_number: s.step_number ?? i + 1,
      description: s.description.trim(),
    })),

    related_reference: doc.related_reference ?? null,
    status: doc.status,

    actioned_at: parseDate(doc.actioned_at),
    generated_at: parseDate(doc.generated_at),
    expires_at: parseDate(doc.expires_at),
  };
}

// ── Main ─────────────────────────────────────────────
(async () => {
  let inserted = 0, skipped = 0, failed = 0;

  try {
    if (!fs.existsSync(SEED_FILE)) {
      throw new Error(`Seed file not found: ${SEED_FILE}`);
    }

    const raw = JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));

    if (!Array.isArray(raw) || raw.length === 0) {
      throw new Error('Seed file must be a non-empty array');
    }

    console.log(`\n── Seeding recommendations (${raw.length} docs) ──\n`);

    const db = await getDb();
    const coll = db.collection('recommendations');

    if (FORCE) {
      const ids = raw.map(d => d._id);
      const res = await coll.deleteMany({ _id: { $in: ids } });
      console.log(`  [force] deleted ${res.deletedCount} docs\n`);
    }

    raw.forEach((doc, i) => validate(doc, i));
    console.log(`  ✓ validation passed\n`);

    for (const docRaw of raw) {
      const doc = transform(docRaw);

      try {
        await coll.insertOne(doc);
        console.log(`  ✓ inserted ${doc._id}`);
        inserted++;
      } catch (err) {
        if (err.code === 11000) {
          console.log(`  ↷ skipped ${doc._id}`);
          skipped++;
        } else {
          console.error(`  ✗ failed ${doc._id}: ${err.message}`);
          failed++;
        }
      }
    }

    console.log(`
── DONE ──
Inserted: ${inserted}
Skipped : ${skipped}
Failed  : ${failed}
    `);

    process.exit(failed > 0 ? 1 : 0);

  } catch (err) {
    console.error('[SEED ERROR]', err.message);
    process.exit(1);
  } finally {
    await close();
  }
})();