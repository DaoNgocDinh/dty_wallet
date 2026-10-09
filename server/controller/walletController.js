var bcrypt = require('bcryptjs');
var crypto = require('crypto');
var Transaction = require('../model/Transaction');
var User = require('../model/User');

exports.balance = async function(req, res) {
  res.json({ walletBalance: req.user.walletBalance });
};

exports.depositIntent = async function(req, res) {
  var amount = Number(req.body.amount);
  var source = String(req.body.source || '').trim();
  var paymentMethod = String(req.body.paymentMethod || '').trim();
  if (!source || !Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'source and positive amount are required' });
  }
  if (!paymentMethod && !req.body.qrInfo) {
    return res.status(400).json({ error: 'paymentMethod or qrInfo is required' });
  }
  var transaction = await Transaction.create({
    transactionCode: code(), userId: req.user.id, account: req.user.email,
    type: 'wallet_deposit', amount: amount, sender: source, recipient: req.user.email,
    status: 'pending', metadata: { paymentMethod: paymentMethod || 'qr', hasQrInfo: Boolean(req.body.qrInfo) }
  });
  res.status(202).json({ message: 'Deposit request created; wallet is credited after payment confirmation', transaction: transaction });
};

exports.mobileTopup = function(type) {
  return async function(req, res) {
    var amount = Number(req.body.amount || req.body.denomination);
    var carrier = String(req.body.carrier || '').trim();
    var phoneNumber = String(req.body.phoneNumber || '').trim();
    var denomination = Number(req.body.denomination || amount);
    if (!carrier || !/^\+?[0-9]{7,15}$/.test(phoneNumber) || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'carrier, valid phoneNumber, and positive amount are required' });
    }
    if (type === 'data_topup' && !String(req.body.dataPackage || '').trim()) {
      return res.status(400).json({ error: 'dataPackage is required for data top-up' });
    }
    var user = await verifyPin(req, res);
    if (!user) return;
    var txn = await createPaymentIntent(user, amount, {
      type: type, recipient: phoneNumber, note: req.body.note,
      metadata: { carrier: carrier, denomination: denomination, dataPackage: req.body.dataPackage || null }
    });
    res.status(202).json({ message: 'Top-up request recorded as pending; wallet is not debited before provider confirmation', transaction: txn, walletBalance: user.walletBalance });
  };
};

exports.payBill = async function(req, res) {
  var amount = Number(req.body.amount);
  var paymentMethod = String(req.body.paymentMethod || '').trim();
  var billType = String(req.body.billType || '').trim();
  var customerCode = String(req.body.customerCode || '').trim();
  if (!paymentMethod || !billType || !customerCode || !Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'paymentMethod, billType, customerCode, and positive amount are required' });
  }
  var user = await verifyPin(req, res);
  if (!user) return;
  var txn = await createPaymentIntent(user, amount, {
    type: 'bill_payment', recipient: customerCode, note: req.body.content,
    metadata: { paymentMethod: paymentMethod, billType: billType, hasQr: Boolean(req.body.qrCode) }
  });
  res.status(202).json({ message: 'Bill payment recorded as pending; wallet is not debited before provider confirmation', transaction: txn, walletBalance: user.walletBalance });
};

async function verifyPin(req, res) {
  var user = await User.findById(req.user.id).select('+pinHash');
  if (!user.pinHash) {
    res.status(409).json({ error: 'Set a transaction PIN before making this payment' });
    return null;
  }
  if (!(await bcrypt.compare(String(req.body.pin || ''), user.pinHash))) {
    res.status(401).json({ error: 'Transaction PIN is incorrect' });
    return null;
  }
  return user;
}

async function createPaymentIntent(user, amount, details) {
  return Transaction.create({
    transactionCode: code(), userId: user.id, account: user.email,
    type: details.type, amount: amount, sender: user.email,
    recipient: details.recipient, note: details.note,
    status: 'pending', metadata: details.metadata
  });
}

function code() { return 'TX-' + crypto.randomUUID(); }