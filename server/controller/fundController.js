var bcrypt = require('bcryptjs');
var Fund = require('../model/Fund');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var crypto = require('crypto');

exports.list = async function(req, res) {
  var funds = await Fund.find({
    $or: [
      { userId: req.user.id },
      { 'members.userId': req.user.id }
    ]
  }).sort({ createdAt: -1 });
  res.json({ count: funds.length, data: funds });
};

exports.create = async function(req, res) {
  // Pre-condition: Người dùng đang làm chủ dưới 10 quỹ (Exceptions 1.1)
  var fundCount = await Fund.countDocuments({ userId: req.user.id });
  if (fundCount >= 10) {
    return res.status(400).json({ error: 'Không thể tạo thêm quỹ', code: 'MAX_FUNDS_EXCEEDED' });
  }

  var fundType = req.body.fundType !== undefined && req.body.fundType !== null ? String(req.body.fundType).trim() : '';
  if (!fundType) {
    return res.status(400).json({ error: 'Vui lòng chọn loại quỹ', code: 'FUND_TYPE_REQUIRED' });
  }
  var allowedTypes = ['Cá nhân', 'Cặp đôi', 'Tích lũy', 'Hội nhóm'];
  if (!allowedTypes.includes(fundType)) {
    return res.status(400).json({ error: 'Loại quỹ không hợp lệ', code: 'INVALID_FUND_TYPE' });
  }

  var name = req.body.name !== undefined && req.body.name !== null ? String(req.body.name).trim() : '';
  if (!name) {
    return res.status(400).json({ error: 'Vui lòng nhập tên quỹ', field: 'name', code: 'FUND_NAME_REQUIRED' });
  }
  if (name.length > 60) {
    return res.status(400).json({ error: 'Tên quỹ không được vượt quá 60 ký tự', field: 'name', code: 'FUND_NAME_TOO_LONG' });
  }

  var targetAmount = 0;
  var completionDate = undefined;

  if (fundType === 'Tích lũy') {
    if (req.body.targetAmount === undefined || req.body.targetAmount === null || String(req.body.targetAmount).trim() === '') {
      return res.status(400).json({ error: 'Vui lòng nhập số tiền mục tiêu', field: 'targetAmount', code: 'TARGET_AMOUNT_REQUIRED' });
    }
    targetAmount = Number(req.body.targetAmount);
    if (!Number.isFinite(targetAmount) || targetAmount <= 0) {
      return res.status(400).json({ error: 'Số tiền mục tiêu phải lớn hơn 0', field: 'targetAmount', code: 'INVALID_TARGET_AMOUNT' });
    }

    if (!req.body.completionDate) {
      return res.status(400).json({ error: 'Vui lòng chọn ngày hoàn thành mục tiêu', field: 'completionDate', code: 'COMPLETION_DATE_REQUIRED' });
    }
    completionDate = new Date(req.body.completionDate);
    if (Number.isNaN(completionDate.getTime())) {
      return res.status(400).json({ error: 'Vui lòng chọn ngày hoàn thành mục tiêu', field: 'completionDate', code: 'INVALID_COMPLETION_DATE' });
    }
  } else {
    if (req.body.targetAmount !== undefined && req.body.targetAmount !== null && String(req.body.targetAmount).trim() !== '') {
      targetAmount = Number(req.body.targetAmount);
      if (!Number.isFinite(targetAmount) || targetAmount < 0) {
        targetAmount = 0;
      }
    }
    if (req.body.completionDate) {
      var d = new Date(req.body.completionDate);
      if (!Number.isNaN(d.getTime())) {
        completionDate = d;
      }
    }
  }

  var fund = await Fund.create({
    userId: req.user.id,
    name: name,
    fundType: fundType,
    targetAmount: targetAmount,
    completionDate: completionDate,
    currentAmount: 0,
    members: [{ userId: req.user.id, role: 'owner', joinedAt: new Date() }]
  });

  var result = fund.toObject();
  result.message = 'Tạo quỹ thành công';
  res.status(201).json(result);
};

exports.details = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findOne({
    _id: fundId,
    $or: [
      { userId: req.user.id },
      { 'members.userId': req.user.id }
    ]
  }).populate('members.userId', 'name email phoneNumber');
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại hoặc bạn không có quyền xem quỹ này' });
  }

  var transactions = await Transaction.find({
    'metadata.fundId': fund.id
  }).sort({ createdAt: -1 });

  res.json({
    fund: fund,
    transactions: transactions
  });
};

exports.contribute = async function(req, res) {
  var rawAmount = req.body.amount;
  // 3.1: Người dùng để trống số tiền góp -> E1
  if (rawAmount === undefined || rawAmount === null || String(rawAmount).trim() === '') {
    return res.status(400).json({ error: 'Vui lòng nhập số tiền muốn góp', code: 'AMOUNT_REQUIRED' });
  }

  var amountStr = String(rawAmount).trim().replace(/,/g, '');
  // 3.3: Số tiền không hợp lệ, không phải là số hoặc chứa ký tự không hợp lệ -> E3
  if (!/^\d+(\.\d+)?$/.test(amountStr)) {
    return res.status(400).json({ error: 'Số tiền không hợp lệ', code: 'INVALID_AMOUNT' });
  }

  var amount = Number(amountStr);
  if (!Number.isFinite(amount) || isNaN(amount) || amount <= 0) {
    return res.status(400).json({ error: 'Số tiền không hợp lệ', code: 'INVALID_AMOUNT' });
  }

  // 3.2: Người dùng nhập số tiền nhỏ hơn 1.000đ -> E2
  if (amount < 1000) {
    return res.status(400).json({ error: 'Tối thiểu 1000đ', code: 'MIN_AMOUNT_1000' });
  }

  // 3.5: Ghi chú quá 200 từ -> E5
  var note = String(req.body.note || '').trim();
  if (note) {
    var words = note.split(/\s+/).filter(Boolean);
    if (words.length > 200) {
      return res.status(400).json({ error: 'Tối đa 200 từ', code: 'NOTE_TOO_LONG' });
    }
  }

  // Kiểm tra quyền thành viên / sở hữu quỹ
  var fund = await Fund.findOne({
    _id: req.params.id,
    $or: [
      { userId: req.user.id },
      { 'members.userId': req.user.id }
    ]
  });
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại hoặc bạn không phải thành viên quỹ' });
  }

  var user = await User.findById(req.user.id);
  if (!user) {
    return res.status(404).json({ error: 'Người dùng không tồn tại' });
  }

  // 3.4: Số tiền lớn hơn số dư khả dụng trong ví -> E4
  if (user.walletBalance < amount) {
    return res.status(400).json({ error: 'Số dư ví không đủ để thực hiện giao dịch', code: 'INSUFFICIENT_BALANCE' });
  }

  var debited = await User.findOneAndUpdate(
    { _id: user.id, walletBalance: { $gte: amount } },
    { $inc: { walletBalance: -amount } },
    { new: true }
  );
  if (!debited) {
    return res.status(400).json({ error: 'Số dư ví không đủ để thực hiện giao dịch', code: 'INSUFFICIENT_BALANCE' });
  }

  var updatedFund;
  try {
    updatedFund = await Fund.findOneAndUpdate(
      { _id: fund.id },
      { $inc: { currentAmount: amount } },
      { new: true }
    );
    if (!updatedFund) {
      var missingFund = new Error('Quỹ không tồn tại');
      missingFund.status = 404;
      throw missingFund;
    }

    var txn = await Transaction.create({
      transactionCode: code(),
      userId: user.id,
      account: user.email,
      type: 'fund_contribution',
      amount: amount,
      sender: user.name || user.email,
      recipient: fund.name,
      note: note,
      status: 'completed',
      metadata: { fundId: fund.id, fundName: fund.name }
    });

    res.json({
      message: 'Góp tiền thành công',
      fund: updatedFund,
      walletBalance: debited.walletBalance,
      transaction: txn
    });
  } catch (error) {
    // 7.1: Phát sinh lỗi trong quá trình chuyển tiền -> E6
    if (updatedFund) await Fund.updateOne({ _id: fund.id }, { $inc: { currentAmount: -amount } });
    await User.updateOne({ _id: user.id }, { $inc: { walletBalance: amount } });
    return res.status(500).json({ error: 'Góp quỹ không thành công', code: 'CONTRIBUTION_FAILED' });
  }
};

exports.delete = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findOne({ _id: fundId, userId: req.user.id });
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại hoặc bạn không có quyền xóa quỹ này' });
  }
  await Fund.deleteOne({ _id: fund._id });
  res.json({ message: 'Xoá quỹ thành công', id: fund._id });
};

function code() { return 'TX-' + crypto.randomUUID(); }