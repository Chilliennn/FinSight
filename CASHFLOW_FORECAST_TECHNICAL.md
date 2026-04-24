# Cash Flow Forecast - Technical Reference

## File Structure Created

```
FinSight/
├── lib/
│   ├── presentation/
│   │   └── forecast/
│   │       └── forecast_page.dart              [NEW] 350 lines
│   │           ├── ForecastContent (StatefulWidget)
│   │           ├── _RiskSummaryCard()
│   │           ├── _WeeklyBreakdownCard()
│   │           ├── _DailyProjectionCard()
│   │           ├── _AiInsightsCard()
│   │           └── _BalanceChartPainter (CustomPainter)
│   │
│   ├── application/
│   │   ├── logic/
│   │   │   └── forecast.logic.js               [NEW] 250 lines
│   │   │       ├── calculateMovingAverage()
│   │   │       ├── identifyPatterns()
│   │   │       ├── projectCashFlow()
│   │   │       ├── calculateWeeklySummary()
│   │   │       ├── calculateRiskMetrics()
│   │   │       └── buildForecastDoc()
│   │   │
│   │   ├── ai-engine/
│   │   │   └── forecast.engine.js              [NEW] 200 lines
│   │   │       ├── generateForecastInsights()
│   │   │       ├── generateOptimizationRecommendations()
│   │   │       └── _validateForecastInsights()
│   │   │
│   │   ├── routes/
│   │   │   └── forecast.routes.js              [NEW] 280 lines
│   │   │       ├── GET /api/forecast/:businessId
│   │   │       ├── POST /api/forecast/generate
│   │   │       ├── GET /api/forecast/report/:forecastId
│   │   │       └── POST /api/forecast/optimize
│   │   │
│   │   └── prompts/
│   │       └── forecast.prompts.js             [NEW] 80 lines
│   │           ├── FORECAST_SYSTEM_PROMPT
│   │           ├── generateForecastInsightPrompt()
│   │           └── generateOptimizationPrompt()
│   │
│   └── data/
│       ├── models/
│       │   └── forecast.model.js               [NEW] 120 lines
│       │       └── Forecast MongoDB Schema
│       │
│       └── repositories/
│           └── forecastRepository.js           [NEW] 180 lines
│               ├── findLatestByBusinessId()
│               ├── getById()
│               ├── upsertForecast()
│               ├── getBusinessFinancialSnapshot()
│               ├── findHistoryByBusinessId()
│               └── deleteById()
│
├── presentation/shared/
│   └── app_layout.dart                         [UPDATED]
│       ├── Added import for forecast_page.dart
│       ├── Added _forecastNavTile()
│       └── Updated sidebar to use _forecastNavTile()
│
├── CASHFLOW_FORECAST_SETUP.md                  [NEW] Setup guide
├── CASHFLOW_FORECAST_SUMMARY.md                [NEW] Feature overview
└── CASHFLOW_FORECAST_TECHNICAL.md              [NEW] This file
```

**Total New Lines:** ~1,560 lines of code  
**Files Created:** 9  
**Files Updated:** 1

---

## API Endpoints

### 1. GET /api/forecast/:businessId
**Purpose:** Fetch the latest active forecast for a business

**Request:**
```
GET /api/forecast/demo-maju-bakery-001
Content-Type: application/json
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "business_id": "demo-maju-bakery-001",
    "current_balance": 15000,
    "projection_start_date": "2026-04-23",
    "projection_period_days": 56,
    "daily_projections": [
      {
        "date": "2026-04-23",
        "inflow": 3500,
        "outflow": 1200,
        "net_cash_flow": 2300,
        "projected_balance": 17300,
        "is_at_risk": false
      },
      ...56 days total
    ],
    "weekly_totals": [
      {
        "week": 1,
        "total_inflow": 24500,
        "total_outflow": 8400,
        "net_flow": 16100,
        "end_of_week_balance": 31100
      },
      ...8 weeks total
    ],
    "risk_summary": {
      "risk_level": "Low",
      "has_shortfall_risk": false,
      "projected_shortfall_date": null,
      "at_risk_days": 0,
      "minimum_projected_balance": 15200,
      "average_projected_balance": 23450
    },
    "ai_insights": {
      "summary": "Your business shows strong cash flow stability...",
      "warnings": [],
      "opportunities": [
        "Strong cash position suggests capacity to invest in growth"
      ],
      "recommended_actions": [
        {
          "action": "Build 3-month emergency fund",
          "estimated_impact_rm": 7000,
          "timeframe": "This month"
        }
      ]
    },
    "generated_at": "2026-04-23T10:30:00Z",
    "expires_at": "2026-05-23T10:30:00Z",
    "is_active": true
  },
  "error": null
}
```

**Error (404):**
```json
{
  "success": false,
  "data": null,
  "error": "No forecast found. Please generate one first."
}
```

---

### 2. POST /api/forecast/generate
**Purpose:** Generate a new 8-week forecast from historical data

**Request:**
```json
POST /api/forecast/generate
Content-Type: application/json

{
  "businessId": "demo-maju-bakery-001",
  "projectionDays": 56
}
```

**Parameters:**
- `businessId` (string, required) - Business identifier
- `projectionDays` (number, optional) - Days to project (default: 56)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "_id": "507f1f77bcf86cd799439011",
    "business_id": "demo-maju-bakery-001",
    ... [same structure as GET endpoint]
  },
  "error": null
}
```

**Process:**
1. ✅ Fetches current balance and historical transactions (90 days)
2. ✅ Analyzes patterns (day-of-week, seasonal)
3. ✅ Projects 56-day cash flow with variance
4. ✅ Calculates risk metrics
5. ✅ Calls Z.AI for insights
6. ✅ Saves to MongoDB
7. ✅ Returns complete forecast

**Time:** ~2-5 seconds (depending on Z.AI latency)

---

### 3. GET /api/forecast/report/:forecastId
**Purpose:** Fetch a specific forecast report by ID

**Request:**
```
GET /api/forecast/report/507f1f77bcf86cd799439011
Content-Type: application/json
```

**Response:** Same as GET /:businessId endpoint

---

### 4. POST /api/forecast/optimize
**Purpose:** Generate optimization strategies based on current forecast

**Request:**
```json
POST /api/forecast/optimize
Content-Type: application/json

{
  "businessId": "demo-maju-bakery-001"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "strategies": [
      {
        "title": "Early Collection Program",
        "description": "Implement 2% early payment discount for invoices collected within 5 days",
        "impact_rm": 1200,
        "timeframe": "Immediate"
      },
      {
        "title": "Payables Staggering",
        "description": "Negotiate 30-day terms with 3 key suppliers to align outflows with inflows",
        "impact_rm": 2000,
        "timeframe": "This week"
      }
    ]
  },
  "error": null
}
```

---

## Database Schema

### Forecast Collection (`forecasts`)

```javascript
{
  _id: ObjectId,
  
  // Business Reference
  business_id: String,                              // Index
  
  // Financial Context
  current_balance: Number,                          // RM
  projection_start_date: String,                    // ISO 8601
  projection_period_days: Number,                   // Default: 56
  
  // Daily Projections Array (56 elements)
  daily_projections: [
    {
      date: String,                                 // YYYY-MM-DD
      inflow: Number,
      outflow: Number,
      net_cash_flow: Number,
      projected_balance: Number,
      is_at_risk: Boolean                          // Balance < RM 5000
    }
  ],
  
  // Weekly Aggregates Array (8 elements)
  weekly_totals: [
    {
      week: Number,                                 // 1-8
      total_inflow: Number,
      total_outflow: Number,
      net_flow: Number,
      end_of_week_balance: Number
    }
  ],
  
  // Risk Analysis
  risk_summary: {
    risk_level: String,                            // 'Low' | 'Medium' | 'High'
    has_shortfall_risk: Boolean,
    projected_shortfall_date: String,              // ISO date or null
    at_risk_days: Number,
    minimum_projected_balance: Number,
    average_projected_balance: Number
  },
  
  // AI-Generated Content
  ai_insights: {
    summary: String,
    warnings: [String],
    opportunities: [String],
    recommended_actions: [
      {
        action: String,
        estimated_impact_rm: Number,
        timeframe: String
      }
    ]
  },
  
  // Lifecycle
  generated_at: Date,                              // Index
  expires_at: Date,                                // TTL Index (30 days)
  is_active: Boolean,                              // Index
  
  // Compound Indexes:
  // { business_id: 1, is_active: 1, generated_at: -1 }
  // { expires_at: 1 } (TTL)
}
```

---

## Component Responsibilities

### ForecastContent (Flutter UI)
**File:** `forecast_page.dart`

**Responsibilities:**
- Fetch forecast data from backend
- Display risk summary with color coding
- Render weekly breakdown cards (horizontal scroll)
- Draw daily balance line chart with risk threshold
- Show AI-generated insights and recommendations
- Provide refresh functionality

**State Management:**
- `_isLoading` - Loading indicator
- `_forecastData` - Full forecast object
- `_errorMessage` - Error handling

**Key Methods:**
- `_loadForecastData()` - HTTP GET request
- `_generateMockForecastData()` - Testing/demo data
- `_buildRiskSummaryCard()` - Risk display
- `_buildWeeklyBreakdownCard()` - Weekly summary
- `_buildDailyProjectionCard()` - Chart rendering
- `_buildAiInsightsCard()` - Insights display

---

### forecast.logic.js
**File:** `forecast.logic.js`

**Responsibilities:**
- Pure mathematical calculations (no I/O)
- Historical pattern analysis
- 56-day cash flow projection
- Risk metrics computation
- Data validation

**Key Functions:**
```javascript
calculateMovingAverage(values, windowSize)
  → Smooths historical data using moving average

identifyPatterns(historicalTransactions)
  → Extracts day-of-week and weekly patterns

projectCashFlow(balance, inflows, outflows, days)
  → Projects daily balance for 56 days

calculateWeeklySummary(dailyProjections)
  → Aggregates to weekly totals

calculateRiskMetrics(dailyProjections)
  → Returns risk_level, shortfall_date, etc.

buildForecastDoc(forecastData)
  → Formats for MongoDB insertion
```

**No Dependencies:** No imports except built-in Math

---

### forecast.engine.js
**File:** `forecast.engine.js`

**Responsibilities:**
- Z.AI prompt engineering
- Calling GLM 5.1 API (production)
- Response validation
- Fallback mock data for testing

**Key Functions:**
```javascript
generateForecastInsights(forecastData)
  → Calls Z.AI, returns validated insights

generateOptimizationRecommendations(forecast, patterns)
  → AI-generated strategy suggestions

_validateForecastInsights(insights)  [private]
  → Ensures response structure and types
```

**Production Mode:**
- Requires Z.AI SDK: `zhiyu-sdk`
- API Key: Environment variable `ZHIYU_API_KEY`
- Response Format: JSON mode

---

### forecast.routes.js
**File:** `forecast.routes.js`

**Responsibilities:**
- HTTP endpoint handling
- Request validation
- Orchestration between layers
- Error handling and responses

**Architectural Rules:**
```
✅ Can import/call:   logic, ai_engine, repositories
✅ Cannot be called by: logic, ai_engine, repositories
✅ Receives all data via function parameters
✅ Never performs direct DB queries or business logic
```

**Layer Coordination:**
```javascript
Routes layer does:
  1. Validate HTTP request
  2. Fetch data via repositories
  3. Pass data to logic
  4. Pass data to ai_engine
  5. Collect results
  6. Format response
  7. Send to client
```

---

### forecast.model.js
**File:** `forecast.model.js`

**Schema:**
- 120 lines defining exact MongoDB structure
- Compound indices for efficient queries
- TTL index for automatic 30-day cleanup
- Enforced field types and ranges

**Indexes:**
```javascript
// Efficient latest forecast lookup
{ business_id: 1, is_active: 1, generated_at: -1 }

// Auto-expire old forecasts
{ expires_at: 1 }  // TTL Index
```

---

### forecastRepository.js
**File:** `forecastRepository.js`

**Responsibilities:**
- All MongoDB CRUD operations
- Query optimization
- Data marshaling

**Key Methods:**
```javascript
findLatestByBusinessId(businessId)
  → Latest active forecast before expiry

getById(forecastId)
  → Fetch by _id

upsertForecast(businessId, forecastData)
  → Insert new + deactivate previous

getBusinessFinancialSnapshot(businessId)
  → Current balance + 90-day history

findHistoryByBusinessId(businessId, limit)
  → Pagination of forecast history

deleteById(forecastId)
  → Manual deletion
```

**Architectural Rules:**
```
✅ Only source of truth for database
✅ Cannot call logic or ai_engine
✅ Handles connections and transactions
✅ Returns plain objects (no logic)
```

---

## Data Flow Diagrams

### GET Forecast Flow
```
[Frontend GET]
    ↓
[Routes.get('/:businessId')]
    ↓
[Repository.findLatestByBusinessId()]
    ├─ Query MongoDB
    └─ Return raw forecast doc
    ↓
[Return JSON Response]
    ↓
[Flutter renders UI]
```

### Generate Forecast Flow
```
[Frontend POST generate]
    ↓
[Routes.post('/generate')]
    ├─→ [Repo.getBusinessFinancialSnapshot()]
    │   └─ Fetch: current_balance, historical_inflows, historical_outflows
    │
    ├─→ [Logic.projectCashFlow()]
    │   ├─ identifyPatterns()
    │   ├─ Project 56 daily balances
    │   └─ Return daily_projections[]
    │
    ├─→ [Logic.calculateWeeklySummary()]
    │   └─ Return weekly_totals[]
    │
    ├─→ [Logic.calculateRiskMetrics()]
    │   └─ Return risk_summary{}
    │
    ├─→ [Engine.generateForecastInsights()]
    │   ├─ Build prompts
    │   ├─ Call Z.AI
    │   └─ Validate response
    │   └─ Return ai_insights{}
    │
    ├─→ [Logic.buildForecastDoc()]
    │   └─ Package everything for DB
    │
    └─→ [Repo.upsertForecast()]
        ├─ Deactivate previous forecasts
        ├─ Insert new forecast
        └─ Return saved document
        ↓
[Return to Frontend]
    ↓
[Flutter renders UI]
```

---

## Testing Examples

### 1. Test Projection Algorithm
```javascript
const logic = require('./lib/application/logic/forecast.logic');

const inflows = [
  { date: '2026-04-01', amount: 3500 },
  { date: '2026-04-02', amount: 2800 },
];

const outflows = [
  { date: '2026-04-01', amount: 1200 },
  { date: '2026-04-02', amount: 800 },
];

const projections = logic.projectCashFlow(
  15000,      // currentBalance
  inflows,
  outflows,
  56          // days
);

console.log(`Day 1: RM${projections[0].projected_balance}`);
console.log(`Day 56: RM${projections[55].projected_balance}`);
```

### 2. Test Risk Metrics
```javascript
const riskMetrics = logic.calculateRiskMetrics(projections);

console.log(`Risk Level: ${riskMetrics.risk_level}`);
console.log(`Shortfall Date: ${riskMetrics.projected_shortfall_date}`);
console.log(`Min Balance: RM${riskMetrics.minimum_projected_balance}`);
```

### 3. Test API Endpoint
```bash
curl -X POST http://localhost:3000/api/forecast/generate \
  -H "Content-Type: application/json" \
  -d '{
    "businessId": "test-business-001",
    "projectionDays": 56
  }' | jq '.data.risk_summary'
```

---

## Performance Considerations

### Optimization
- **MongoDB Indexes:** Compound index on (business_id, is_active, generated_at)
- **TTL Index:** Auto-removes forecasts older than 30 days
- **Daily Projections:** Stored as array (single document) for atomicity
- **Z.AI Caching:** Consider caching insights for 24 hours if regenerating

### Expected Response Times
- **GET forecast:** 50-200ms (MongoDB query + formatting)
- **POST generate:** 2-5 seconds (includes Z.AI call)
- **Frontend render:** 100-300ms (chart drawing + layout)

### Scalability
- Forecasts stored per business (sharding by business_id)
- Daily projections array (56 elements) = ~2KB per forecast
- Historical queries limited to 90 days
- AI insights cached in forecast document

---

## Error Handling

### Frontend Errors
```json
{
  "isLoading": false,
  "errorMessage": "Failed to connect to backend",
  "forecastData": {}
}
→ Shows error UI with retry button
```

### Backend Validation Errors
```json
{
  "success": false,
  "data": null,
  "error": "businessId is required"
}
→ HTTP 400 Bad Request
```

### Database Errors
```json
{
  "success": false,
  "data": null,
  "error": "MongoDB connection failed"
}
→ HTTP 500 Internal Server Error
```

### Z.AI Errors
- If Z.AI fails, routes returns mock insights
- Forecast still saved (AI optional)
- User sees: "AI insights unavailable at this time"

---

## Security Considerations

### Input Validation
- ✅ businessId must be non-empty string
- ✅ projectionDays must be 7-365
- ✅ All numeric fields validated as numbers

### Data Privacy
- ✅ Forecasts scoped to businessId (multi-tenant)
- ✅ No cross-business data leakage
- ✅ TTL ensures old data cleaned up

### API Security
- ⚠️ Should add authentication (JWT tokens)
- ⚠️ Should add rate limiting (prevent spam)
- ⚠️ Should add CORS configuration
- ⚠️ Should log API calls for audit trail

---

## Future Enhancements

1. **Forecast Comparison** - Week-over-week changes
2. **Sensitivity Analysis** - "What if" scenarios
3. **Seasonal Adjustments** - Holiday/festival impacts
4. **Budget Integration** - Compare projection to budget
5. **Alert Thresholds** - Notify when balance approaches minimum
6. **Export to PDF/Excel** - Shareable reports
7. **Forecast Accuracy Tracking** - Actual vs projected
8. **Multi-scenario Planning** - Optimistic/pessimistic/realistic
9. **Cash Flow Waterfall** - Detailed transaction view
10. **Mobile App** - Native Swift/Kotlin UI for forecast

---

## Deployment Checklist

- [ ] Node.js 18+ running
- [ ] MongoDB Atlas cluster configured (AWS Singapore)
- [ ] Environment variables set (MONGO_URI, ZHIYU_API_KEY)
- [ ] Routes registered in Express app
- [ ] Forecast model imported
- [ ] Flutter assets compiled
- [ ] Backend URL configured in Flutter code
- [ ] CORS enabled for frontend domain
- [ ] SSL/TLS certificates valid
- [ ] Database backups configured
- [ ] Error logging configured
- [ ] Rate limiting configured
- [ ] Authentication implemented

---

## Reference Links

- **N-Tier Architecture:** See AGENTS.md
- **Z.AI Documentation:** https://zhiyu.ai/docs
- **MongoDB Schema Design:** https://docs.mongodb.com
- **Express.js Best Practices:** https://expressjs.com
- **Flutter Charts:** Custom painter based on Canvas API
