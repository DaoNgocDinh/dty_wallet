var Transaction = require('../model/Transaction');

exports.search = async function(req, res) {
  var filter = { userId: req.user.id };
  ['transactionCode', 'type', 'status'].forEach(function(key) {
    if (req.query[key]) filter[key] = req.query[key];
  });
  if (req.query.sender) filter.sender = new RegExp(escapeRegex(req.query.sender), 'i');
  if (req.query.recipient) filter.recipient = new RegExp(escapeRegex(req.query.recipient), 'i');

  var createdAt = {};
  if (req.query.fromDate) createdAt.$gte = validDate(req.query.fromDate, false);
  if (req.query.toDate) createdAt.$lte = validDate(req.query.toDate, true);
  if (Object.keys(createdAt).length) filter.createdAt = createdAt;

  var page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  var limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);
  var total = await Transaction.countDocuments(filter);
  var transactions = await Transaction.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit);
  res.json({ data: transactions, pagination: { page: page, limit: limit, total: total, pages: Math.ceil(total / limit) } });
};

exports.history = async function(req, res) {
  return exports.search(req, res);
};

function validDate(value, endOfDay) {
  var date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    var error = new Error('Invalid date filter');
    error.status = 400;
    throw error;
  }
  if (endOfDay && /^\d{4}-\d{2}-\d{2}$/.test(value)) date.setHours(23, 59, 59, 999);
  return date;
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}