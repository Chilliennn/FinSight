/**
 * Risk Alert Schema (MongoDB Atlas)
 *
 * Aligned with ER diagram:
 *   id PK | business_id FK | type | severity | trigger_condition | detected_at | status
 *
 * Additions (approved by owner, to be back-filled into ER diagram):
 *   - severity extended to 4 values (critical/high/medium/low) — UI shows CRITICAL
 *   - title, description, category, timeframe        (UI display fields)
 *   - detailed_explanation                           (Z.AI-generated cache)
 *   - affected_amount                                (Manifesto §6 mandatory)
 *   - supporting_data                                (Z.AI prompt context)
 */
module.exports = {
  name: 'risk_alerts',
  schema: {
    bsonType: 'object',
    required: [
      '_id',
      'business_id',
      'type',
      'severity',
      'detected_at',
      'status',
      'affected_amount'
    ],
    properties: {
      _id: { bsonType: 'string' },
      business_id: { bsonType: 'string' },

      // ER-diagram fields
      type: { bsonType: 'string' },
      severity: { enum: ['critical', 'high', 'medium', 'low'] },
      trigger_condition: { bsonType: 'string' },
      detected_at: { bsonType: 'date' },
      status: { enum: ['active', 'resolved'] },

      // Manifesto §6 mandatory
      affected_amount: { bsonType: 'double' },

      // UI display
      title: { bsonType: 'string' },
      description: { bsonType: 'string' },
      category: { bsonType: 'string' },
      timeframe: { bsonType: 'string' },

      // Z.AI enrichment
      detailed_explanation: { bsonType: 'string' },
      supporting_data: { bsonType: 'object' }
    }
  }
};