# Cash Flow Forecast Feature - Implementation Summary

## 🎯 What Was Built

A complete **8-week cash flow forecasting system** for FinSight AI that:

✅ **Estimates future financial liquidity** by projecting cash inflows and outflows  
✅ **Identifies potential cash shortages** with risk metrics and warnings  
✅ **Plans for financing** with AI-generated optimization recommendations  
✅ **Enables proactive cash management** through predictive analytics  

---

## 📊 Feature Components

### Frontend (Flutter)
**File:** `lib/presentation/forecast/forecast_page.dart`

**UI Elements:**
1. **Risk Summary Card** - Shows overall liquidity risk (Low/Medium/High)
2. **Weekly Breakdown** - Horizontal scrollable cards with inflow/outflow/balance per week
3. **Daily Projection Chart** - Line chart showing 56-day projected balance trend
4. **AI Insights Panel** - Auto-generated warnings, opportunities, and action recommendations

**Key Features:**
- Real-time refresh button
- Risk threshold visualization (RM 5000 danger line)
- Quantified RM impact on every recommendation
- Malaysian SME context (cafes, pet stores, retail)

---

### Backend Logic Layer
**File:** `lib/application/logic/forecast.logic.js`

**Algorithms:**
- **Moving Average Calculation** - Smooths historical data for trend detection
- **Pattern Identification** - Analyzes day-of-week and weekly cycles
- **Cash Flow Projection** - 56-day projection using:
  - Historical averages
  - Seasonal patterns
  - Realistic variance (±20%)
  - Non-negative constraints
- **Risk Metrics** - Calculates:
  - Risk level (Low/Medium/High based on at-risk days)
  - Shortfall date detection
  - Minimum projected balance
  - Average balance trajectory

**No Database Access:** Pure calculations, data injected from routes

---

### AI Engine Layer
**File:** `lib/application/ai-engine/forecast.engine.js`

**Z.AI Integration:**
- Uses GLM 5.1 in JSON mode for structured output
- Generates context-aware Malaysian business insights
- Creates quantifiable action recommendations

**Output:**
```json
{
  "summary": "2-3 sentence assessment",
  "warnings": ["Critical issues"],
  "opportunities": ["Growth opportunities"],
  "recommended_actions": [
    {
      "action": "Description",
      "estimated_impact_rm": 5000,
      "timeframe": "This week"
    }
  ]
}
```

Includes mock generators for testing before Z.AI integration.

---

### Routes/Mediator Layer
**File:** `lib/application/routes/forecast.routes.js`

**Endpoints:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/forecast/generate` | Generate 8-week forecast from historical data |
| GET | `/api/forecast/:businessId` | Fetch latest active forecast |
| GET | `/api/forecast/report/:forecastId` | Get detailed forecast report |
| POST | `/api/forecast/optimize` | Generate optimization strategies |

**Flow Control:**
- Coordinates between logic, AI engine, and repositories
- No business logic inside routes (passes to logic)
- No database queries inside logic/AI (passes to repos)
- Validates inputs and error handling

---

### Data Models & Storage
**File:** `lib/data/models/forecast.model.js`

**MongoDB Collections:**
```javascript
{
  business_id: String,
  current_balance: Number (RM),
  projection_start_date: String (ISO),
  
  daily_projections: [
    { date, inflow, outflow, net_cash_flow, 
      projected_balance, is_at_risk }
  ], // 56 elements
  
  weekly_totals: [
    { week, total_inflow, total_outflow, 
      net_flow, end_of_week_balance }
  ], // 8 elements
  
  risk_summary: {
    risk_level, has_shortfall_risk, 
    projected_shortfall_date, minimum_projected_balance, ...
  },
  
  ai_insights: {
    summary, warnings, opportunities, recommended_actions
  },
  
  generated_at: Date,
  expires_at: Date // Auto-cleanup after 30 days (TTL index)
}
```

**TTL Index:** Automatically removes forecasts older than 30 days

---

### Repository Layer
**File:** `lib/data/repositories/forecastRepository.js`

**Database Operations:**
- `findLatestByBusinessId()` - Get current active forecast
- `getById()` - Fetch specific forecast
- `upsertForecast()` - Save new forecast (deactivates previous)
- `getBusinessFinancialSnapshot()` - Fetch current balance + historical data
- `findHistoryByBusinessId()` - Audit trail of all forecasts
- `deleteById()` - Manual deletion

**No Business Logic:** Only CRUD operations

---

### Prompts Template
**File:** `lib/application/prompts/forecast.prompts.js`

**Versioned Prompts:**
- System prompt setting context (Malaysian SME focus)
- User prompt template for forecast insights
- Optimization recommendation template

Allows easy updates without touching logic/routes code.

---

## 🔄 Data Flow Example

### Scenario: User clicks "Cash Flow Forecast"

```
1. [Flutter] User taps "Cash Flow Forecast" in sidebar
          ↓
2. [Frontend] ForecastContent calls: HTTP GET /api/forecast/businessId
          ↓
3. [Routes] forecast.routes.js receives request
          ├─→ [Repositories] Fetch latest forecast from MongoDB
          ├─→ Build response object
          └─→ Return JSON to frontend
          ↓
4. [Flutter] ForecastContent renders:
          ├─ Risk Summary Card
          ├─ Weekly Breakdown
          ├─ Daily Projection Chart
          └─ AI Insights
```

### Scenario: Generate New Forecast (POST /api/forecast/generate)

```
1. Backend Route receives: { businessId, projectionDays: 56 }
          ↓
2. [Repositories] Fetch:
          ├─ Current balance
          ├─ Historical inflows (last 90 days)
          └─ Historical outflows (last 90 days)
          ↓
3. [Logic] Calculate projections:
          ├─ identifyPatterns() from historical data
          ├─ projectCashFlow() for 56 days
          ├─ calculateWeeklySummary() for UI display
          └─ calculateRiskMetrics() for alerts
          ↓
4. [AI Engine] Generate insights:
          ├─ Call Z.AI GLM 5.1 with projection data
          ├─ Validate JSON response structure
          └─ Return structured recommendations
          ↓
5. [Logic] buildForecastDoc() packages everything
          ↓
6. [Repositories] Save to MongoDB with TTL
          ↓
7. Return complete forecast to frontend
```

---

## 🏗️ Architecture Principles (Strict Separation)

### ✅ Daily Projections
- **Routes** can call **Logic** and **Repositories** ✅
- **Logic** cannot call **Routes** or **Repositories** ✅
- **Repositories** cannot call **Logic** or **Routes** ✅
- **AI Engine** isolated from **Repositories** ✅

### ✅ No Circular Dependencies
- No frontend imports of app_layout
- No backend modules importing each other directly
- All communication flows downhill through routes

### ✅ Replaceability
- Swap MongoDB with PostgreSQL → Only change repo layer ✅
- Replace Z.AI with different LLM → Only change ai_engine ✅
- Redesign UI → Only change forecast_page.dart ✅
- Update algorithm → Only change forecast.logic.js ✅

---

## 📈 Key Calculations Explained

### Risk Level Determination
```
Low:    0-6 days at-risk
Medium: 7-14 days at-risk
High:   15+ days at-risk
```

Threshold: Balance drops below RM 5,000

### Daily Projection Algorithm
```
1. Calculate average daily inflow/outflow
2. Identify seasonal patterns (day-of-week, week-of-month)
3. For each of 56 days:
   ├─ Apply day-of-week factor
   ├─ Add ±20% variance (random)
   ├─ Calculate net flow (inflow - outflow)
   ├─ Update running balance
   └─ Mark as at-risk if balance < RM 5,000
```

Result: Realistic projection accounting for business cycles

---

## 🔧 Integration Checklist

- [ ] Backend Node.js server running
- [ ] MongoDB Atlas (AWS Singapore) connected
- [ ] Forecast routes registered in Express
- [ ] Transaction data repository implemented
- [ ] Flutter app configured with backend URL
- [ ] Navigation integrated (✅ already done in app_layout.dart)
- [ ] Z.AI SDK installed and configured (production)
- [ ] Forecast page rendering correctly
- [ ] Test: POST /api/forecast/generate
- [ ] Test: GET /api/forecast/:businessId
- [ ] Verify AI insights display

---

## 📱 User Journey

1. **Dashboard** → Click "Cash Flow Forecast" in sidebar
2. **Forecast Page Loads** → Shows latest 8-week projection
3. **View Analysis** → Risk level, weekly breakdown, daily trends
4. **Read AI Insights** → Warnings, opportunities, recommended actions
5. **Take Action** → Implement recommendations in business
6. **Refresh** → Click refresh button to regenerate with latest data

---

## 🎁 What You Can Do With This Feature

### For SME Owners
- **Identify cash gaps** 2+ months in advance
- **Plan major expenses** without going negative
- **Negotiate better payment terms** with confidence
- **Build appropriate reserves** before risky periods
- **Make data-driven decisions** on hiring, inventory, investments

### For Accountants/Financial Advisors
- **Monitor client cash health** proactively
- **Suggest working capital optimization**
- **Plan seasonal adjustments**
- **Quantify impact** of recommendations (in RM)

### For FinSight AI Platform
- **Demonstrates AI value** (GLM 5.1 insights)
- **Reduces financial stress** for businesses
- **Enables proactive interventions** before crises
- **Differentiates from competitors**

---

## 📞 Support & Next Steps

For questions or implementation help, refer to:
- **Setup Guide:** `CASHFLOW_FORECAST_SETUP.md`
- **API Documentation:** See forecast.routes.js comments
- **Architecture:** See AGENTS.md for N-Tier principles

Key files to review:
1. `lib/application/routes/forecast.routes.js` - API structure
2. `lib/application/logic/forecast.logic.js` - Calculations
3. `lib/presentation/forecast/forecast_page.dart` - UI/UX
4. `lib/data/models/forecast.model.js` - Database schema
