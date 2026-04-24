/**
 * Risk Explainer — Ilmu AI integration via the team's shared OpenAI-compat client.
 *
 * Reuses openaiClient.js so all AI traffic goes through the same keep-alive
 * HTTP agents, timeout settings, and env checks. Never duplicates the SDK setup.
 *
 * Takes a raw risk from the logic layer, calls Ilmu, returns enriched risk.
 * Falls back to a clearly-labelled template if Ilmu is unreachable.
 *
 * Per Manifesto §5: NEVER imports mongoose/mongodb.
 */

const { client } = require('./openaiClient');

const {
  SYSTEM_PROMPT,
  buildUserPrompt,
  version: promptVersion
} = require('./prompts/risk_explanation_prompt');
const fallback = require('./prompts/risk_explanation_fallback');

const AI_MODEL = process.env.ZAI_MODEL || 'ilmu-glm-5.1';

// Prepended to fallback text so the UI clearly signals when AI was unavailable.
// Keeps the real numbers from supporting_data, but is honest about the source.
const FALLBACK_MARKER = '(AI unavailable — using template) ';

function fallbackExplanation(risk) {
  return FALLBACK_MARKER + fallback.generate(risk);
}

function buildFallback(risk) {
  return {
    ...risk,
    detailed_explanation: fallbackExplanation(risk),
    ai_metadata: { source: 'fallback', fallback_version: fallback.version }
  };
}

async function explainRisk(risk) {
  try {
    const completion = await client.chat.completions.create({
      model:           AI_MODEL,
      temperature:     0.3,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user',   content: buildUserPrompt(risk) }
      ]
    });

    const raw = completion?.choices?.[0]?.message?.content;
    if (!raw) {
      console.warn('[risk_explainer] empty AI response, using fallback');
      return buildFallback(risk);
    }

    // Ilmu sometimes wraps JSON in a markdown code fence (```json ... ```)
    // even with response_format: json_object. Strip it before parsing.
    const cleaned = raw
      .trim()
      .replace(/^```(?:json)?\s*/i, '')
      .replace(/\s*```\s*$/i, '')
      .trim();

    let parsed;
    try {
      parsed = JSON.parse(cleaned);
    } catch (parseErr) {
      console.warn('[risk_explainer] AI output not valid JSON, using fallback:', parseErr.message);
      return buildFallback(risk);
    }

    const combined = [parsed.explanation, parsed.consequence]
      .filter(Boolean)
      .join(' ');

    if (!combined) {
      return buildFallback(risk);
    }

    return {
      ...risk,
      detailed_explanation: combined,
      ai_metadata: {
        source:           'ilmu',
        model:            AI_MODEL,
        prompt_version:   promptVersion,
        fallback_version: fallback.version,
        generated_at:     new Date().toISOString()
      }
    };
  } catch (err) {
    // SDK throws on non-2xx (401/404/429/5xx) and network errors.
    const status = err?.status || err?.response?.status;
    const msg    = err?.message || String(err);
    console.warn(`[risk_explainer] AI call failed (${status || 'no-status'}): ${msg}`);
    return buildFallback(risk);
  }
}

async function explainAll(risks) {
  return Promise.all(risks.map(explainRisk));
}

module.exports = { explainRisk, explainAll };