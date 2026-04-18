/**
 * Overall Financial Risk Score — the 7.4/10 in the red banner.
 *
 * Weighted sum of active risks, capped at 10.
 *
 * Weights tuned so Maju Bakery demo (1 critical + 2 high + 2 medium) = 7.4
 *   1 × 2.6 + 2 × 1.6 + 2 × 0.8 = 7.4  ✓ (matches UI mockup)
 */

const WEIGHTS = {
  critical: 2.6,
  high: 1.6,
  medium: 0.8,
  low: 0.3
};

const LABELS = [
  { min: 7.0, label: 'HIGH RISK' },
  { min: 4.0, label: 'MEDIUM RISK' },
  { min: 0.0, label: 'LOW RISK' }
];

function calculateScore(risks) {
  const raw = risks.reduce(
    (acc, r) => acc + (WEIGHTS[r.severity] || 0),
    0
  );
  const score = Math.min(10, Number(raw.toFixed(1)));

  const sortedLabels = [...LABELS].sort((a, b) => b.min - a.min);
  const label = sortedLabels.find((l) => score >= l.min)?.label ?? 'LOW RISK';

  const percent = Math.round((score / 10) * 100);

  return { score, label, percent };
}

module.exports = { calculateScore };