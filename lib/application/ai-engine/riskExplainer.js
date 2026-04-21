/**
 * Risk Explainer — Z.AI GLM 5.1 integration.
 *
 * Takes a raw risk from the logic layer, calls Z.AI, returns enriched risk.
 * Per Manifesto §5: NEVER imports mongoose/mongodb.
 */

const {
  SYSTEM_PROMPT,
  buildUserPrompt,
  version: promptVersion
} = require('./prompts/risk_explanation_prompt');
const fallback = require('./prompts/risk_explanation_fallback');

const ZAI_ENDPOINT =
  process.env.ZAI_API_ENDPOINT || 'https://api.z.ai/api/paas/v4/chat/completions';
const ZAI_MODEL = process.env.ZAI_MODEL || 'glm-5.1';
const ZAI_API_KEY = process.env.ZAI_API_KEY;

async function explainRisk(risk) {
  try {
    if (!ZAI_API_KEY) {
      return {
        ...risk,
        detailed_explanation: fallback.generate(risk),
        ai_metadata: { source: 'fallback', fallback_version: fallback.version }
      };
    }

    const response = await fetch(ZAI_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${ZAI_API_KEY}`
      },
      body: JSON.stringify({
        model: ZAI_MODEL,
        response_format: { type: 'json_object' },
        temperature: 0.3,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: buildUserPrompt(risk) }
        ]
      })
    });

    if (!response.ok) {
      const text = await response.text();
      console.warn(`[riskExplainer] Z.AI ${response.status}: ${text}`);
      return {
        ...risk,
        detailed_explanation: fallback.generate(risk),
        ai_metadata: { source: 'fallback', fallback_version: fallback.version }
      };
    }

    const data = await response.json();
    const raw = data?.choices?.[0]?.message?.content;
    if (!raw) {
      return {
        ...risk,
        detailed_explanation: fallback.generate(risk),
        ai_metadata: { source: 'fallback', fallback_version: fallback.version }
      };
    }

    const parsed = JSON.parse(raw);
    const combined = [parsed.explanation, parsed.consequence]
      .filter(Boolean)
      .join(' ');

    return {
      ...risk,
      detailed_explanation: combined || fallback.generate(risk),
      ai_metadata: {
        source: combined ? 'z.ai' : 'fallback',
        model: ZAI_MODEL,
        prompt_version: promptVersion,
        fallback_version: fallback.version,
        generated_at: new Date().toISOString()
      }
    };
  } catch (err) {
    console.error('[riskExplainer] unexpected error:', err);
    return {
      ...risk,
      detailed_explanation: fallback.generate(risk),
      ai_metadata: { source: 'fallback', fallback_version: fallback.version }
    };
  }
}

async function explainAll(risks) {
  return Promise.all(risks.map(explainRisk));
}

module.exports = { explainRisk, explainAll };

