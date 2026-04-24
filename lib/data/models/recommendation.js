module.exports = {
  name: 'recommendations',

  schema: {
    bsonType: 'object',
    required: [
      '_id',
      'business_id',
      'risk_id',
      'action_title',
      'action_plan',
      'reasoning',
      'projected_impact_value',
      'impact_type',
      'status',
    ],
    properties: {
      _id: {
        bsonType: 'string',
        description: 'Hex ObjectId string — assigned by recommendationRepository.create()',
      },
      business_id: {
        bsonType: 'string',
        description: 'FK → businesses._id',
      },
      risk_id: {
        bsonType: 'string',
        description: 'FK → riskAlerts._id that triggered this recommendation',
      },

      action_title: {
        bsonType: 'string',
        description: 'Short imperative title (≤10 words) shown on the card header',
      },
      action_plan: {
        bsonType: 'string',
        description: 'One-sentence action description shown as card subtitle',
      },
      reasoning: {
        bsonType: 'string',
        description: 'Full AI reasoning paragraph shown in expanded card view',
      },

      projected_impact_value: {
        bsonType: ['double', 'int'],
        description: 'Positive MYR amount — sign is implied by impact_type',
      },
      impact_type: {
        bsonType: 'string',
        enum: ['Cash Inflow', 'Cash Buffer', 'Cost Savings', 'Available Financing'],
      },

      category: {
        bsonType: 'string',
        enum: ['Collections', 'Supplier Management', 'Cost Optimization', 'Financing'],
      },
      difficulty: {
        bsonType: 'string',
        enum: ['Easy Action', 'Medium Action', 'Hard Action'],
      },
      timeframe: {
        bsonType: 'string',
        description: 'Human-readable urgency, e.g. "Within 7 days"',
      },
      rank: {
        bsonType: 'int',
        description: '1 = highest priority; used for sort order in the UI',
      },

      action_steps: {
        bsonType: 'array',
        description: 'Ordered list of concrete steps (3–5 items)',
        items: {
          bsonType: 'object',
          required: ['step_number', 'description'],
          properties: {
            step_number: { bsonType: 'int'    },
            description: { bsonType: 'string' },
          },
        },
      },

      related_reference: {
        bsonType: ['string', 'null'],
        description: 'Invoice/ref number e.g. INV-2026-089, or null',
      },

      status: {
        bsonType: 'string',
        enum: ['active', 'actioned', 'dismissed', 'expired'],
      },
      actioned_at: {
        bsonType: ['date', 'null'],
        description: 'Set when user taps "Mark as Actioned"',
      },
      generated_at: {
        bsonType: 'date',
        description: 'Timestamp Z.AI generated this batch',
      },
      expires_at: {
        bsonType: 'date',
        description: 'Auto-set to generated_at + 7 days by the logic layer',
      },
    },
  },

  indexes: [
    {
      key:  { business_id: 1, status: 1, expires_at: 1, rank: 1 },
      name: 'idx_business_status_expires_rank',
    },
    {
      key:  { risk_id: 1, status: 1 },
      name: 'idx_risk_status',
    },
    {
      key:  { status: 1, expires_at: 1 },
      name: 'idx_status_expires',
    },
    {
      key:    { business_id: 1, actioned_at: 1 },
      name:   'idx_business_actioned_at',
      sparse: true,
    },
  ],
};
