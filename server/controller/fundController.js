var bcrypt = require('bcryptjs');
var Fund = require('../model/Fund');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var crypto = require('crypto');

exports.list = async function(req, res) {
  var funds = await Fund.find({ userId: req.user.id }).sort({ createdAt: -1 });
  res.json({ count: funds.length, data: funds });
};

exports.create = async function(req, res) {
  var name = String(req.body.name || '').trim();
  var fundType = String(req.body.fundType || '').trim();
  var targetAmount = Number(req.body.targetAmount);
  var completionDate = req.body.completionDate ? new Date(req.body.completionDate) : undefined;
  if (!name || !fundType || !Number.isFinite(targetAmount) || targetAmount <= 0) {
    return res.status(400).json({ error: 'name, fundType, and positive targetAmount are required' });
  }
  if (completionDate && Number.isNaN(completionDate.getTime())) {
    return res.status(400).json({ error: 'completionDate must be a valid date' });
  }
  var fund = await Fund.create({ userId: req.user.id, name: name, fundType: fundType, targetAmount: targetAmount, completionDate: completionDate });
  res.status(201).json(fund);
};

exports.contribute = async function(req, res) {
  var amount = Number(req.body.amount);
  var note = String(req.body.note || '').trim();
  if (!Number.isFinite(amount) || amount <= 0) return res.status(400).json({ error: 'A positive amount is required' });

  var fund = await Fund.findOne({ _id: req.params.id, userId: req.user.id });
  if (!fund) return res.status(404).json({ error: 'Fund not found' });
  var user = await User.findById(req.user.id).select('+pinHash');
  if (!user.pinHash) return res.status(409).json({ error: 'Set a transaction PIN before contributing' });
  if (!(await bcrypt.compare(String(req.body.pin || ''), user.pinHash))) return res.status(401).json({ error: 'Transaction PIN is incorrect' });

  var debited = await User.findOneAndUpdate(
    { _id: user.id, walletBalance: { $gte: amount } },
    { $inc: { walletBalance: -amount } },
    { new: true }
  );
  if (!debited) return res.status(400).json({ error: 'Insufficient wallet balance' });
  var updatedFund;
  try {
    updatedFund = await Fund.findOneAndUpdate(
      { _id: fund.id, userId: user.id },
      { $inc: { currentAmount: amount } },
      { new: true }
    );
    if (!updatedFund) {
      var missingFund = new Error('Fund not found');
      missingFund.status = 404;
      throw missingFund;
    }
    await Transaction.create({
      transactionCode: code(), userId: user.id, account: user.email,
      type: 'fund_contribution', amount: amount, sender: user.email,
      recipient: fund.name, note: note, status: 'completed', metadata: { fundId: fund.id }
    });
  } catch (error) {
    if (updatedFund) await Fund.updateOne({ _id: fund.id }, { $inc: { currentAmount: -amount } });
    await User.updateOne({ _id: user.id }, { $inc: { walletBalance: amount } });
    throw error;
  }
  res.json({ fund: updatedFund, walletBalance: debited.walletBalance });
};

function code() { return 'TX-' + crypto.randomUUID(); }