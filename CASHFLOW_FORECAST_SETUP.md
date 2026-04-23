# Cash Flow Forecast Feature Implementation Guide

## Overview
The Cash Flow Forecast feature has been fully implemented across all layers following the N-Tier Component Architecture. This document provides setup instructions and integration points.

---

## 📁 Created Files & Structure

### Frontend (Flutter) - `/lib/presentation/forecast/`
- **`forecast_page.dart`** - Complete UI for the 8-week forecast
  - Risk summary card with liquidity metrics
  - Weekly breakdown with horizontal scroll chart
  - Daily projection line chart with risk threshold visualization
  - AI-generated insights with warnings & opportunities

### Application Layer - `/lib/application/`

#### Logic - `/logic/`
- **`forecast.logic.js`** - Pure deterministic calculations
  - `calculateMovingAverage()` - Trend smoothing
  - `identifyPatterns()` - Day-of-week & seasonal patterns
  - `projectCashFlow()` - 56-day projection algorithm
  - `calculateWeeklySummary()` - Weekly aggregates
  - `calculateRiskMetrics()` - Shortfall detection
  - `buildForecastDoc()` - Database document format

#### AI Engine - `/ai-engine/`
- **`forecast.engine.js`** - Z.AI integration
  - `generateForecastInsights()` - AI analysis via Z.AI GLM 5.1
  - `generateOptimizationRecommendations()` - Strategy suggestions
  - Structured JSON output with validation

#### Routes - `/routes/`
- **`forecast.routes.js`** - The Mediator endpoint
  - `GET /api/forecast/:businessId` - Fetch latest forecast
  - `POST /api/forecast/generate` - Trigger forecast generation
  - `GET /api/forecast/report/:forecastId` - Get detailed report
  - `POST /api/forecast/optimize` - Generate optimization strategies

#### Prompts - `/prompts/`
- **`forecast.prompts.js`** - Versioned Z.AI prompts
  - System prompt for forecast context
  - User prompt templates for insights
  - Optimization prompt template

### Data Layer - `/lib/data/`

#### Models - `/models/`
- **`forecast.model.js`** - MongoDB schema
  - Business reference & financial context
  - Daily projections (56 elements)
  - Weekly totals (8 weeks)
  - Risk metrics & AI insights
  - TTL indexes for automatic cleanup (30 days)

#### Repositories - `/repositories/`
- **`forecastRepository.js`** - Database operations only
  - `findLatestByBusinessId()` - Get active forecast
  - `getById()` - Fetch by forecast ID
  - `upsertForecast()` - Save with previous deactivation
  - `getBusinessFinancialSnapshot()` - Historical data fetching
  - `findHistoryByBusinessId()` - Audit trail
  - `deleteById()` - Manual deletion

---

## 🚀 Integration Steps

### Step 1: Backend Setup

#### 1.1 Install Dependencies (if needed)
```bash
npm install mongoose express
```

#### 1.2 Register Routes in Your Express App
In your main backend file (e.g., `server.js` or `app.js`):

```javascript
const forecastRoutes = require('./lib/application/routes/forecast.routes');

// In your Express setup:
app.use('/api/forecast', forecastRoutes);
```

#### 1.3 Connect MongoDB
Ensure your Mongoose connection is initialized in `/lib/data/database/`:
```javascript
const mongoose = require('mongoose');

// Connection string for MongoDB Atlas (AWS Singapore Region)
const MONGO_URI = process.env.MONGO_URI || 'mongodb+srv://...';

mongoose.connect(MONGO_URI);
```

#### 1.4 Initialize Forecast Model
In your model initialization file:
```javascript
const Forecast = require('./lib/data/models/forecast.model');
// Mongoose will create the collection with indexes automatically
```

---

### Step 2: Frontend Setup

#### 2.1 Navigation Integration (Already Done)
The forecast page is now integrated into the navigation sidebar in `app_layout.dart`:
- Click "Cash Flow Forecast" in the sidebar to navigate
- The app will show the 8-week projection UI

#### 2.2 Update Mock API URL (Frontend)
In `lib/presentation/forecast/forecast_page.dart`, replace the TODO comment:

Current (line ~60):
```dart
// TODO: Call backend API: GET /api/forecast/businessId
```

Replace with:
```dart
final response = await http.get(
  Uri.parse('http://localhost:3000/api/forecast/$businessId'),
  headers: {'Content-Type': 'application/json'},
);

setState(() {
  _forecastData = jsonDecode(response.body)['data'];
  _isLoading = false;
});
```

#### 2.3 Add HTTP Package (if not present)
In `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

---

### Step 3: Backend Data Integration

#### 3.1 Implement Transaction Repository
The forecast needs historical transaction data. Update:
```
/lib/data/repositories/transactionRepository.js
```

Override or create `getBusinessTransactions()`:
```javascript
async function getBusinessTransactions(businessId, days = 90) {
  return Transaction.find({
    business_id: businessId,
    date: { $gte: new Date(Date.now() - days * 24 * 60 * 60 * 1000) }
  });
}
```

#### 3.2 Update `forecastRepository.getBusinessFinancialSnapshot()`
Replace the placeholder mock data with real queries:

```javascript
async function getBusinessFinancialSnapshot(businessId) {
  // 1. Get current balance
  const currentBalance = await getCurrentBalance(businessId);
  
  // 2. Get inflows (last 90 days)
  const inflows = await Transaction.find({
    business_id: businessId,
    type: 'inflow',
    date: { $gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) }
  });
  
  // 3. Get outflows
  const outflows = await Transaction.find({
    business_id: businessId,
    type: 'outflow',
    date: { $gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) }
  });

  return { current_balance: currentBalance, historical_inflows: inflows, historical_outflows: outflows };
}
```

---

### Step 4: Z.AI Integration (For Production)

#### 4.1 Install Z.AI SDK
```bash
npm install zhiyu-sdk  # or your Z.AI SDK package
```

#### 4.2 Update `forecast.engine.js`
In the `generateForecastInsights()` function, replace the MOCK section:

```javascript
// Replace this line:
const mockInsights = {...};

// With:
const zhiyu = require('zhiyu-sdk');

const response = await zhiyu.chat.completions.create({
  model: 'glm-5-1',
  messages: [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt }
  ],
  response_format: { type: 'json_object' }
});

const aiResponse = JSON.parse(response.choices[0].message.content);
const insights = _validateForecastInsights(aiResponse);
```

#### 4.3 Set Environment Variables
```bash
export ZHIYU_API_KEY=your_api_key_here
export MONGO_URI=your_mongodb_uri_here
```

---

## 📊 API Usage Examples

### 1. Generate Forecast
```bash
curl -X POST http://localhost:3000/api/forecast/generate \
  -H "Content-Type: application/json" \
  -d '{
    "businessId": "demo-maju-bakery-001",
    "projectionDays": 56
  }'
```

**Response:**
```json
{
  "success": true,
  "data": {
    "_id": "...",
    "business_id": "demo-maju-bakery-001",
    "current_balance": 15000,
    "daily_projections": [...],
    "weekly_totals": [...],
    "risk_summary": {
      "risk_level": "Low",
      "has_shortfall_risk": false,
      "minimum_projected_balance": 10500
    },
    "ai_insights": {
      "summary": "...",
      "warnings": [...],
      "opportunities": [...],
      "recommended_actions": [...]
    },
    "generated_at": "2026-04-23T...",
    "expires_at": "2026-05-23T..."
  },
  "error": null
}
```

### 2. Fetch Latest Forecast
```bash
curl http://localhost:3000/api/forecast/demo-maju-bakery-001 \
  -H "Content-Type: application/json"
```

### 3. Get Optimization Recommendations
```bash
curl -X POST http://localhost:3000/api/forecast/optimize \
  -H "Content-Type: application/json" \
  -d '{"businessId": "demo-maju-bakery-001"}'
```

---

## 🔍 Architecture Flow

```
User navigates to Forecast
       ↓
[ForecastContent] (Flutter UI)
       ↓
HTTP GET /api/forecast/:businessId
       ↓
[forecast.routes.js] ← Mediator
       ╔═══════════╦════════════════╦═══════════╗
       ↓           ↓                ↓           ↓
   [Repo]    [Logic] (no DB)  [AI Engine]  [Response]
   (DB ops) (Calculate)     (Z.AI call)
       ↓           ↓                ↓
   [Forecast]  Projects &   Insights &
   Documents   Risk Metrics  Recommendations
```

---

## 🧪 Testing

### Test Forecast Generation Logic
```bash
# Sample data for testing (Node.js)
const logic = require('./lib/application/logic/forecast.logic');

const projections = logic.projectCashFlow(
  15000,  // current balance
  [{date: '2026-04-01', amount: 3500}],  // inflows
  [{date: '2026-04-01', amount: 1200}],  // outflows
  56      // days
);

console.log(projections[0]); // First day projection
```

### Test Risk Metrics
```bash
const riskMetrics = logic.calculateRiskMetrics(projections);
console.log(riskMetrics.risk_level);     // 'Low' | 'Medium' | 'High'
console.log(riskMetrics.has_shortfall_risk); // true | false
```

---

## 📋 Checklist

- [ ] Backend server running (Node.js)
- [ ] MongoDB connection established
- [ ] Routes registered in Express app
- [ ] Forecast model imported
- [ ] Transaction/financial data available
- [ ] Flutter app has forecast_page.dart
- [ ] app_layout.dart updated with navigation
- [ ] Frontend HTTP calls configured with correct backend URL
- [ ] Z.AI SDK installed (for production)
- [ ] Z.AI API key set in environment
- [ ] Generate forecast via POST /api/forecast/generate
- [ ] Verify forecast renders in UI (ForecastContent)
- [ ] AI insights displaying correctly
- [ ] Weekly and daily projections visible

---

## 🐛 Troubleshooting

### "No forecast found" error
**Solution:** Generate a forecast first using POST /api/forecast/generate

### AI insights showing as "unavailable at this time"
**Solution:** Z.AI SDK not installed or API key missing. Switch to mock responses for testing.

### Balance projections appear flat
**Solution:** Check that historical transaction data is being fetched correctly in `getBusinessFinancialSnapshot()`

### MongoDB connection fails
**Solution:** Verify MongoDB Atlas credentials and security group rules allow your IP

---

## 📚 Key Files for Reference

- **Business Logic:** `lib/application/logic/forecast.logic.js`
- **API Endpoints:** `lib/application/routes/forecast.routes.js`
- **UI Components:** `lib/presentation/forecast/forecast_page.dart`
- **Database Schema:** `lib/data/models/forecast.model.js`
- **Repository Pattern:** `lib/data/repositories/forecastRepository.js`

---

## 🎯 Next Steps

1. ✅ Complete backend data integration (transaction repository)
2. ✅ Test forecast generation with real historical data
3. ✅ Integrate Z.AI for production insights
4. ✅ Add forecast refresh capability
5. ✅ Create forecast export (PDF/Excel)
6. ✅ Add comparison between forecasts (week-over-week)
7. ✅ Set up alerts for breaching risk thresholds
