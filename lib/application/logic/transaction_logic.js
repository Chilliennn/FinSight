'use strict';

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function parseDate(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

function normalizeType(type) {
  const raw = String(type || '').trim().toLowerCase();
  if (raw === 'debit' || raw === 'outflow' || raw === 'expense') {
    return 'Outflow';
  }
  return 'Inflow';
}

function normalizeCategory(category, fallbackType) {
  const value = String(category || '').trim();
  if (value) return value;
  return fallbackType === 'Inflow' ? 'Revenue' : 'Utilities';
}

function deriveStatus(isPaid, dueDate) {
  if (isPaid) return 'Paid';
  if (dueDate && dueDate.getTime() < Date.now()) return 'Overdue';
  return 'Pending';
}

function deriveSource(type, isPaid) {
  if (!isPaid) return 'Invoice';
  return type === 'Inflow' ? 'Bank Statement' : 'Receipt';
}

function buildDescription(txn, category) {
  const vendor = String(txn.vendor_name || '').trim();
  if (vendor) return vendor;
  const doc = String(txn.document_id || '').trim();
  if (doc) return doc;
  return category;
}

function normalizeTransaction(txn) {
  const amount = Math.abs(toNumber(txn.amount));
  const type = normalizeType(txn.type);
  const txnDate = parseDate(txn.txn_date) || new Date();
  const dueDate = parseDate(txn.due_date);
  const isPaid = txn.is_paid === true;
  const status = deriveStatus(isPaid, dueDate);
  const category = normalizeCategory(txn.category, type);

  return {
    id: String(txn._id || ''),
    business_id: String(txn.business_id || ''),
    document_id: txn.document_id ? String(txn.document_id) : null,
    description: buildDescription(txn, category),
    vendor_name: String(txn.vendor_name || '').trim() || null,
    category,
    amount,
    type,
    status,
    source: deriveSource(type, isPaid),
    is_paid: isPaid,
    is_recurring: txn.is_recurring === true,
    txn_date: txnDate.toISOString(),
    due_date: dueDate ? dueDate.toISOString() : null,
  };
}

function matchesSearch(row, query) {
  const q = String(query || '').trim().toLowerCase();
  if (!q) return true;

  return [
    row.description,
    row.vendor_name || '',
    row.category,
    row.source,
    row.status,
    row.document_id || '',
    row.txn_date.slice(0, 10),
  ]
    .join(' ')
    .toLowerCase()
    .includes(q);
}

function matchesFilters(row, { category, type, source }) {
  const cat = String(category || 'All');
  const t = String(type || 'All');
  const s = String(source || 'All');

  if (cat !== 'All' && row.category !== cat) return false;
  if (t !== 'All' && row.type !== t) return false;
  if (s !== 'All' && row.source !== s) return false;
  return true;
}

function buildCategoryOptions(rows) {
  const preferred = [
    'Rent',
    'Revenue',
    'Ingredients & Supplies',
    'Utilities',
    'Salaries',
    'Marketing',
    'Equipment',
  ];

  const present = new Set(rows.map((r) => r.category).filter(Boolean));
  const ordered = preferred.filter((name) => present.has(name));
  const remaining = [...present]
    .filter((name) => !ordered.includes(name))
    .sort((a, b) => a.localeCompare(b));

  return ['All', ...ordered, ...remaining];
}

function buildSummary(rows) {
  const totalInflow = rows
    .filter((r) => r.type === 'Inflow')
    .reduce((sum, r) => sum + r.amount, 0);
  const totalOutflow = rows
    .filter((r) => r.type === 'Outflow')
    .reduce((sum, r) => sum + r.amount, 0);
  const netAmount = totalInflow - totalOutflow;
  const overdueInvoices = rows.filter((r) => r.status === 'Overdue').length;

  return {
    total_inflow: totalInflow,
    total_outflow: totalOutflow,
    net_amount: netAmount,
    total_transactions: rows.length,
    overdue_invoices: overdueInvoices,
  };
}

function buildTransactionView(rawTransactions, filters = {}) {
  const normalized = rawTransactions
    .map(normalizeTransaction)
    .sort((a, b) => new Date(b.txn_date).getTime() - new Date(a.txn_date).getTime());

  const filtered = normalized.filter(
    (row) => matchesSearch(row, filters.query) && matchesFilters(row, filters),
  );

  return {
    summary: buildSummary(normalized),
    rows: filtered,
    filter_options: {
      category: buildCategoryOptions(normalized),
      type: ['All', 'Inflow', 'Outflow'],
      source: ['All', 'Bank Statement', 'Invoice', 'Receipt'],
    },
  };
}

module.exports = {
  buildTransactionView,
};
