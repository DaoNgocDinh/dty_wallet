var bcrypt = require('bcryptjs');
var crypto = require('crypto');
var SpendingJar = require('../model/SpendingJar');
var Transaction = require('../model/Transaction');
var User = require('../model/User');

exports.list = async function(req, res) {
  var jars = await SpendingJar.find({ userId: req.user.id }).sort({ createdAt: -1 });
  res.json({ count: jars.length, data: jars });
};

exports.create = async function(req, res) {
  var name = String(req.body.name || '').trim();
  var amount = Number(req.body.amount);
  if (!name || !Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'name and positive amount are required' });
  }
  var user = await verifyPin(req, res);
  if (!user) return;
  var debited = await User.findOneAndUpdate({ _id: user.id, walletBalance: { $gte: amount } }, { $inc: { walletBalance: -amount } }, { new: true });
  if (!debited) return res.status(400).json({ error: 'Insufficient wallet balance' });
  var jar;
  try {
    jar = await SpendingJar.create({ userId: user.id, name: name, balance: amount });
    await Transaction.create({
      transactionCode: code(), userId: user.id, account: user.email,
      type: 'jar_contribution', amount: amount, sender: user.email, recipient: name,
      status: 'completed', metadata: { jarId: jar.id }
    });
    res.status(201).json({ jar: jar, walletBalance: debited.walletBalance });
  } catch (error) {
    if (jar) await SpendingJar.deleteOne({ _id: jar.id });
    await User.updateOne({ _id: user.id }, { $inc: { walletBalance: amount } });
    throw error;
  }
};

exports.details = async function(req, res) {
  var jar = await SpendingJar.findOne({ _id: req.params.id, userId: req.user.id });
  if (!jar) return res.status(404).json({ error: 'Spending jar not found' });
  var year = Number(req.query.year);
  var month = Number(req.query.month);
  var filter = { userId: req.user.id, 'metadata.jarId': jar.id };
  if (req.query.year || req.query.month) {
    if (!Number.isInteger(year) || year < 1970 || !Number.isInteger(month) || month < 1 || month > 12) {
      return res.status(400).json({ error: 'Provide both a valid year and month (1-12)' });
    }
    var start = new Date(year, month - 1, 1);
    var end = new Date(year, month, 1);
    filter.createdAt = { $gte: start, $lt: end };
  }
  var transactions = await Transaction.find(filter).sort({ createdAt: -1 });
  res.json({ jar: jar, period: req.query.year ? { year: year, month: month } : null, transactions: transactions });
};

async function verifyPin(req, res) {
  var user = await User.findById(req.user.id).select('+pinHash');
  if (!user.pinHash) {
    res.status(409).json({ error: 'Set a transaction PIN before creating a spending jar' });
    return null;
  }
  if (!(await bcrypt.compare(String(req.body.pin || ''), user.pinHash))) {
    res.status(401).json({ error: 'Transaction PIN is incorrect' });
    return null;
  }
  return user;
}

function code() { return 'TX-' + crypto.randomUUID(); }