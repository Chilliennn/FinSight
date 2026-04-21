/**
 * application/ai_engine/recommendation.engine.js
 */

const config = require('../../data/database/config');
const {
  RECOMMENDATION_SYSTEM_PROMPT,
  buildUserPrompt,
} = require('./prompts/recommendation.prompt');

// ── Validation constants ──────────────────────────────────────────────────────

const VALID_CATEGORIES   = ['Collections', 'Supplier Management', 'Cost Optimization', 'Financing'];
const VALID_DIFFICULTIES = ['Easy Action', 'Medium Action', 'Hard Action'];
const VALID_IMPACT_TYPES = ['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing'];

// ── Main export ───────────────────────────────────────────────────────────────

/**
 * Call Z.AI and return validated raw recommendation objects.
 *
 * @param {Object} financialSnapshot - Injected by routes/recommendation.routes.js
 * @returns {Promise<Array<Object>>} - Validated raw recommendation objects
 */
async function generateRecommendations(financialSnapshot) {
  const userPrompt = buildUserPrompt(financialSnapshot);
  const endpoint   = `${config.zaiBaseUrl}/chat/completions`;

  // ── 1. Call Z.AI ─────────────────────────────────────────────────────────
  let rawText;
  try {
    const response = await fetch(endpoint, {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${config.zaiApiKey}`,
      },
      body: JSON.stringify({
        model:      config.zaiModel,   // 'glm-4-flash' from .env / config default
        max_tokens: 4096,
        temperature: 0.3,              // Lower temperature = more consistent JSON output
        messages: [
          { role: 'system', content: RECOMMENDATION_SYSTEM_PROMPT },
          { role: 'user',   content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Z.AI returned HTTP ${response.status}: ${errBody}`);
    }

    const data = await response.json();

    // Z.AI follows the OpenAI response shape
    rawText = data?.choices?.[0]?.message?.content ?? '';

    if (!rawText) {
      throw new Error('Z.AI returned an empty content field');
    }
  } catch (err) {
    throw new Error(`AI engine: Z.AI API call failed — ${err.message}`);
  }

  // ── 2. Strip markdown fences if present ──────────────────────────────────
  const cleaned = rawText
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i,     '')
    .replace(/```\s*$/,      '')
    .trim();

  // ── 3. Parse JSON ─────────────────────────────────────────────────────────
  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (err) {
    throw new Error(
      `AI engine: JSON parse failed — ${err.message}\n` +
      `First 400 chars of raw output: ${rawText.slice(0, 400)}`,
    );
  }

  const recs = parsed?.recommendations;
  if (!Array.isArray(recs) || recs.length === 0) {
    throw new Error('AI engine: Response did not contain a recommendations array');
  }

  // ── 4. Validate and sanitize each recommendation ─────────────────────────
  const validated = recs.filter((rec, idx) => {
    const issues = [];

    if (!VALID_CATEGORIES.includes(rec.category))
      issues.push(`invalid category "${rec.category}"`);
    if (!VALID_DIFFICULTIES.includes(rec.difficulty))
      issues.push(`invalid difficulty "${rec.difficulty}"`);
    if (!VALID_IMPACT_TYPES.includes(rec.impact_type))
      issues.push(`invalid impact_type "${rec.impact_type}"`);
    if (typeof rec.projected_impact_value !== 'number' || rec.projected_impact_value <= 0)
      issues.push('invalid projected_impact_value (must be positive number)');
    if (!rec.action_title?.trim())
      issues.push('missing action_title');
    if (!rec.action_plan?.trim())
      issues.push('missing action_plan');
    if (!rec.reasoning?.trim())
      issues.push('missing reasoning');
    if (!Array.isArray(rec.action_steps) || rec.action_steps.length === 0)
      issues.push('missing or empty action_steps');

    if (issues.length > 0) {
      console.warn(`[AI engine] Dropping rec #${idx + 1} (rank ${rec.rank}): ${issues.join(', ')}`);
      return false;
    }
    return true;
  });

  if (validated.length === 0) {
    throw new Error('AI engine: All recommendations failed validation — check Z.AI prompt output');
  }

  console.log(`[AI engine] ${validated.length}/${recs.length} recommendations passed validation`);
  return validated;
}

module.exports = { generateRecommendations };