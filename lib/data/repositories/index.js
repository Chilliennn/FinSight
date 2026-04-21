const business = require('./businessRepository');
const document = require('./documentRepository');
const transaction = require('./transactionRepository');
const riskAlert = require('./riskAlertRepository');
const recommendation = require('./recommendationRepository');
const forecastScenario = require('./forecastScenarioRepository');

module.exports = { business, document, transaction, riskAlert, recommendation, forecastScenario };
