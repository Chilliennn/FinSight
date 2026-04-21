/**
 * lib/application/ai_engine/recommendation.engine.js
 
 */

const { RECOMMENDATION_SYSTEM_PROMPT, buildUserPrompt } = require('./prompts/recommendation_prompt');

const ZAI_API_KEY  = process.env.ZAI_API_KEY;
const ZAI_BASE_URL = process.env.ZAI_BASE_URL ?? 'https://open.bigmodel.cn/api/paas/v4';
const ZAI_MODEL    = process.env.ZAI_MODEL    ?? 'glm-4-flash';

if (!ZAI_API_KEY) {
  throw new Error('ZAI_API_KEY is not set in environment — check your .env file');
}

const VALID_CATEGORIES   = ['Collections', 'Supplier Management', 'Cost Optimization', 'Financing'];
const VALID_DIFFICULTIES = ['Easy Action', 'Medium Action', 'Hard Action'];
const VALID_IMPACT_TYPES = ['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing'];

/**
 * Call ZhipuAI GLM and return validated recommendation objects.
 * Uses the OpenAI-compatible /chat/completions endpoint.
 *
 * @param {Object} financialSnapshot - Injected by routes/
 * @returns {Promise<Array>}         - Validated raw recommendation objects
 */
async function generateRecommendations(financialSnapshot) {
  const userPrompt = buildUserPrompt(financialSnapshot);

  let rawText;
  try {
    const response = await fetch(`${ZAI_BASE_URL}/chat/completions`, {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${ZAI_API_KEY}`,
      },
      body: JSON.stringify({
        model:       ZAI_MODEL,
        max_tokens:  4096,
        temperature: 0.1,   // low temperature for consistent structured JSON output
        messages: [
          { role: 'system', content: RECOMMENDATION_SYSTEM_PROMPT },
          { role: 'user',   content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`ZhipuAI API error ${response.status}: ${errBody.slice(0, 300)}`);
    }

    const data = await response.json();
    rawText = data?.choices?.[0]?.message?.content;

    if (!rawText) {
      throw new Error(`ZhipuAI returned no content. Full response: ${JSON.stringify(data).slice(0, 300)}`);
    }
  } catch (err) {
    throw new Error(`AI engine: ZhipuAI call failed — ${err.message}`);
  }

  // Strip markdown fences if model wraps output despite instructions
  const cleaned = rawText
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i,     '')
    .replace(/```\s*$/,      '')
    .trim();

  let parsed;
  try {
    parsed = JSON.parse(cleaned);
  } catch (err) {
    throw new Error(
      `AI engine: JSON parse failed — ${err.message}\n` +
      `Raw output (first 400 chars): ${rawText.slice(0, 400)}`
    );
  }

  const recs = parsed?.recommendations;
  if (!Array.isArray(recs) || recs.length === 0) {
    throw new Error('AI engine: No recommendations array in parsed response');
  }

  // Validate and sanitize each recommendation — drop invalid ones with a warning
  const validated = recs.filter((rec, idx) => {
    const issues = [];
    if (!VALID_CATEGORIES.includes(rec.category))
      issues.push(`invalid category "${rec.category}"`);
    if (!VALID_DIFFICULTIES.includes(rec.difficulty))
      issues.push(`invalid difficulty "${rec.difficulty}"`);
    if (!VALID_IMPACT_TYPES.includes(rec.impact_type))
      issues.push(`invalid impact_type "${rec.impact_type}"`);
    if (typeof rec.projected_impact_value !== 'number' || rec.projected_impact_value <= 0)
      issues.push('invalid projected_impact_value');
    if (!rec.action_title?.trim())  issues.push('missing action_title');
    if (!rec.action_plan?.trim())   issues.push('missing action_plan');
    if (!rec.reasoning?.trim())     issues.push('missing reasoning');
    if (!Array.isArray(rec.action_steps) || rec.action_steps.length === 0)
      issues.push('missing action_steps');

    if (issues.length > 0) {
      console.warn(`[AI engine] Dropping rec #${idx + 1}: ${issues.join(', ')}`);
      return false;
    }
    return true;
  });

  if (validated.length === 0) {
    throw new Error('AI engine: All recommendations failed validation');
  }

  return validated;
}

module.exports = { generateRecommendations };


