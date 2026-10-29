var crypto = require('crypto');
var SpendingJar = require('../model/SpendingJar');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var Notification = require('../model/Notification');

exports.list = async function(req, res) {
  var jars = await SpendingJar.find({ userId: req.user.id }).sort({ createdAt: -1 });
  res.json({ count: jars.length, data: jars });
};

exports.create = async function(req, res) {
  var name = typeof req.body.name === 'string' ? req.body.name.trim() : '';
  if (!name) {
    return res.status(400).json({ error: 'Hãy nhập đầy đủ tên hũ' });
  }
  if (name.length > 50) {
    return res.status(400).json({ error: 'Tên hũ không hợp lệ' });
  }

  var amountValue = req.body.amount;
  if (amountValue === undefined || amountValue === null || String(amountValue).trim() === '') {
    return res.status(400).json({ error: 'Hãy cung cấp tiền cho hũ' });
  }

  var amount = typeof amountValue === 'number' || typeof amountValue === 'string'
    ? Number(amountValue)
    : NaN;

  if (!Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'Số tiền cung cấp phải lớn hơn 0' });
  }

  var escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  var existingJar = await SpendingJar.findOne({
    userId: req.user.id,
    name: new RegExp('^' + escapedName + '$', 'i')
  });
  if (existingJar) {
    return res.status(409).json({
      code: 'SPENDING_JAR_NAME_EXISTS',
      error: 'Tên hũ này đã tồn tại. Vui lòng chọn tên khác.'
    });
  }

  var debited = await User.findOneAndUpdate(
    { _id: req.user.id, walletBalance: { $gte: amount } },
    { $inc: { walletBalance: -amount } },
    { new: true }
  );
  if (!debited) {
    return res.status(400).json({ error: 'Bạn không đủ tiền trong ví để cung cấp cho hũ' });
  }
  var jar;
  try {
    var user = await User.findById(req.user.id);
    jar = await SpendingJar.create({ userId: req.user.id, name: name, balance: amount });
    await Transaction.create({
      transactionCode: code(), userId: req.user.id, account: user.email,
      type: 'jar_contribution', amount: amount, sender: user.email, recipient: name,
      status: 'completed', metadata: { jarId: jar.id, balanceAfter: amount }
    });
    try {
      await Notification.create({
        userId: req.user.id,
        title: 'Tạo hũ chi tiêu thành công',
        message: 'Bạn đã tạo hũ chi tiêu "' + name + '" với số tiền ban đầu ' + Number(amount).toLocaleString('vi-VN') + 'đ.',
        type: 'spending_jar',
        metadata: {
          jarId: jar.id,
          jarName: name,
          amount: amount
        }
      });
    } catch (_) {}
    res.status(201).json({ message: 'Tạo hũ mới thành công!', jar: jar, walletBalance: debited.walletBalance });
  } catch (error) {
    if (jar) await SpendingJar.deleteOne({ _id: jar.id });
    await User.updateOne({ _id: req.user.id }, { $inc: { walletBalance: amount } });
    throw error;
  }
};

exports.details = async function(req, res) {
  var jar = await SpendingJar.findOne({ _id: req.params.id, userId: req.user.id });
  if (!jar) return res.status(404).json({ error: 'Hũ chi tiêu không tồn tại' });
  var year = Number(req.query.year);
  var month = Number(req.query.month);
  var page = req.query.page === undefined ? 1 : Number(req.query.page);
  var limit = req.query.limit === undefined ? 10 : Math.min(Number(req.query.limit), 10);
  var filter = { userId: req.user.id, 'metadata.jarId': jar.id };
  if (req.query.year || req.query.month) {
    if (!Number.isInteger(year) || year < 1970 || !Number.isInteger(month) || month < 1 || month > 12) {
      return res.status(400).json({ error: 'Vui lòng chọn tháng và năm hợp lệ' });
    }
    var start = new Date(year, month - 1, 1);
    var end = new Date(year, month, 1);
    filter.createdAt = { $gte: start, $lt: end };
  }
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(limit) || limit < 1) {
    return res.status(400).json({ error: 'Số trang không hợp lệ' });
  }

  var count = await Transaction.countDocuments(filter);
  var transactions = await Transaction.find(filter)
    .sort({ createdAt: -1, _id: -1 })
    .skip((page - 1) * limit)
    .limit(limit);

  if (transactions.length) {
    var newest = transactions[0];
    var balanceAfter = newest.metadata && newest.metadata.balanceAfter;
    if (typeof balanceAfter !== 'number') {
      var newerTotals = await Transaction.aggregate([
        { $match: { userId: jar.userId, 'metadata.jarId': jar.id, createdAt: { $gt: newest.createdAt } } },
        {
          $group: {
            _id: null,
            balanceDelta: {
              $sum: {
                $cond: [
                  { $eq: ['$type', 'jar_contribution'] },
                  '$amount',
                  { $multiply: ['$amount', -1] }
                ]
              }
            }
          }
        }
      ]);
      balanceAfter = jar.balance - (newerTotals[0] ? newerTotals[0].balanceDelta : 0);
    }

    transactions = transactions.map(function(transaction, index) {
      var item = transaction.toObject();
      if (index > 0) {
        var previous = transactions[index - 1];
        var delta = previous.type === 'jar_contribution' ? previous.amount : -previous.amount;
        balanceAfter -= delta;
      }
      item.balanceAfter = balanceAfter;
      return item;
    });
  }

  res.json({
    jar: jar,
    period: req.query.year ? { year: year, month: month } : null,
    count: count,
    page: page,
    pageSize: limit,
    totalPages: Math.ceil(count / limit),
    transactions: transactions
  });
};

function code() { return 'TX-' + crypto.randomUUID(); }