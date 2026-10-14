var bcrypt = require('bcryptjs');
var Fund = require('../model/Fund');
var FundInvitation = require('../model/FundInvitation');
var Notification = require('../model/Notification');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var fundRules = require('../utils/fundRules');
var crypto = require('crypto');
var mongoose = require('mongoose');

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
    // Quỹ tích luỹ: Ngày hoàn thành mục tiêu phải sau ngày hiện tại (từ ngày mai trở đi)
    var now = new Date();
    var todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    var compDay = new Date(completionDate.getFullYear(), completionDate.getMonth(), completionDate.getDate());
    if (compDay.getTime() <= todayStart.getTime()) {
      return res.status(400).json({
        error: 'Ngày hoàn thành mục tiêu phải sau ngày hiện tại',
        field: 'completionDate',
        code: 'COMPLETION_DATE_MUST_BE_FUTURE'
      });
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

  // Quỹ cặp đôi: bắt buộc phải chọn người dùng khác ngay từ lúc lập quỹ
  var partner = null;
  if (fundType === fundRules.COUPLE_FUND_TYPE) {
    var lookup = await resolvePartner(req);
    if (lookup.error) {
      return res.status(400).json(lookup.error);
    }
    partner = lookup.user;
  }

  var fund = await Fund.create({
    userId: req.user.id,
    name: name,
    fundType: fundType,
    targetAmount: targetAmount,
    completionDate: completionDate,
    currentAmount: 0,
    status: partner ? 'pending_partner' : 'active',
    members: [{ userId: req.user.id, role: 'owner', joinedAt: new Date() }]
  });

  // Quỹ cặp đôi chỉ được lập chính thức khi người được chọn đồng ý tham gia
  var invitation = null;
  if (partner) {
    invitation = await FundInvitation.create({
      fundId: fund._id,
      fundName: fund.name,
      fundType: fund.fundType,
      inviterId: req.user.id,
      inviterName: req.user.name || req.user.email,
      inviteeId: partner._id,
      inviteeName: partner.name,
      inviteePhone: partner.phoneNumber || '',
      status: 'pending'
    });

    await Notification.create({
      userId: partner._id,
      title: 'Lời mời lập quỹ cặp đôi',
      message: (req.user.name || req.user.email) + ' đã mời bạn lập quỹ cặp đôi "' + fund.name + '"',
      type: 'fund_invitation',
      metadata: {
        invitationId: invitation._id,
        fundId: fund._id,
        fundName: fund.name,
        fundType: fund.fundType,
        inviterName: req.user.name || req.user.email
      }
    });
  }

  var result = fund.toObject();
  result.message = partner
    ? 'Đã gửi lời mời, quỹ cặp đôi sẽ được lập khi người được chọn đồng ý'
    : 'Tạo quỹ thành công';
  if (partner) {
    result.status = 'pending_partner';
    result.invitation = invitation;
    result.partner = {
      id: partner._id,
      name: partner.name,
      email: partner.email,
      phoneNumber: partner.phoneNumber || ''
    };
  }
  res.status(201).json(result);
};

// Tìm người dùng được chọn làm người cùng lập quỹ cặp đôi
async function resolvePartner(req) {
  var partnerId = req.body.partnerId || req.body.inviteeId;
  var partnerPhone = req.body.partnerPhoneNumber || req.body.phoneNumber || req.body.phone;
  var partnerName = req.body.partnerName;

  if (!partnerId && !partnerPhone && !partnerName) {
    return {
      error: {
        error: 'Vui lòng chọn người dùng khác để lập quỹ cặp đôi',
        field: 'partnerId',
        code: 'PARTNER_REQUIRED'
      }
    };
  }

  var targetUser = null;
  if (partnerId) {
    targetUser = await User.findById(partnerId);
  } else if (partnerPhone) {
    targetUser = await User.findOne({ phoneNumber: String(partnerPhone).trim() });
  } else if (partnerName) {
    targetUser = await User.findOne({ name: String(partnerName).trim() });
  }

  if (!targetUser) {
    return {
      error: {
        error: 'Người dùng chưa đăng ký tài khoản ví điện tử hoặc không tồn tại',
        code: 'USER_NOT_FOUND'
      }
    };
  }

  if (targetUser._id.toString() === req.user.id.toString()) {
    return {
      error: {
        error: 'Bạn không thể chọn chính mình làm người cùng lập quỹ',
        code: 'CANNOT_INVITE_SELF'
      }
    };
  }

  if (targetUser.role === 'admin' || (targetUser.name && targetUser.name.toLowerCase() === 'admin')) {
    return {
      error: {
        error: 'Không thể chọn tài khoản quản trị viên',
        code: 'CANNOT_INVITE_ADMIN'
      }
    };
  }

  return { user: targetUser };
}

// Danh sách người dùng có thể chọn làm người cùng lập quỹ cặp đôi
exports.partnerCandidates = async function(req, res) {
  var query = req.query.query !== undefined && req.query.query !== null ? String(req.query.query).trim() : '';

  var userFilter = {
    _id: { $ne: req.user.id },
    role: { $ne: 'admin' },
    name: { $not: /^admin$/i }
  };

  if (query) {
    var escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var regex = new RegExp(escaped, 'i');
    userFilter.$or = [
      { name: regex },
      { phoneNumber: regex },
      { email: regex }
    ];
  }

  var users = await User.find(userFilter).limit(30).select('name email phoneNumber role');
  users = users.filter(function(u) {
    var e = String(u.email || '').trim().toLowerCase();
    return e.indexOf('admin@') !== 0;
  });

  var list = users.map(function(u) {
    return {
      id: u._id,
      _id: u._id,
      name: u.name,
      email: u.email,
      phoneNumber: u.phoneNumber || ''
    };
  });

  if (query && list.length === 0) {
    return res.status(200).json({
      count: 0,
      data: [],
      error: 'Không tìm thấy người dùng phù hợp',
      message: 'Không tìm thấy người dùng phù hợp',
      code: 'NO_USER_FOUND'
    });
  }

  res.json({ count: list.length, data: list });
};

exports.details = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findOne({
    _id: fundId,
    $or: [
      { userId: req.user.id },
      { 'members.userId': req.user.id }
    ]
  }).populate('members.userId', 'name email phoneNumber')
    .populate('userId', 'name email phoneNumber');

  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại hoặc bạn không có quyền xem quỹ này' });
  }

  var fundObj = fund.toObject();
  if (!Array.isArray(fundObj.members)) {
    fundObj.members = [];
  }

  var ownerIdStr = fundObj.userId ? (fundObj.userId._id || fundObj.userId).toString() : '';
  var hasOwnerInMembers = fundObj.members.some(function(m) {
    var mid = m.userId ? (m.userId._id || m.userId).toString() : '';
    return mid === ownerIdStr;
  });

  if (!hasOwnerInMembers && fundObj.userId) {
    fundObj.members.unshift({
      userId: fundObj.userId,
      role: 'owner',
      joinedAt: fundObj.createdAt || new Date()
    });
  }

  // metadata.fundId có thể được lưu dưới dạng chuỗi hoặc ObjectId tuỳ phiên bản ghi
  var transactions = await Transaction.find({
    $or: [
      { 'metadata.fundId': fund.id },
      { 'metadata.fundId': fund._id }
    ]
  }).sort({ createdAt: -1 });

  var isOwner = fundRules.isFundOwner(fund, req.user.id);
  fundObj.isOwner = isOwner;
  // Quỹ chỉ được xoá khi số dư còn 0đ
  fundObj.canDelete = isOwner && Number(fundObj.currentAmount || 0) === 0;
  // Chỉ chủ quỹ được rút tiền từ quỹ
  fundObj.canWithdraw = isOwner && Number(fundObj.currentAmount || 0) > 0;

  res.json({
    fund: fundObj,
    transactions: transactions
  });
};

// Rút tiền từ quỹ về ví cá nhân (chỉ chủ quỹ)
exports.withdraw = async function(req, res) {
  var fundId = String(req.params.id || '');
  if (!mongoose.Types.ObjectId.isValid(fundId)) {
    return res.status(404).json({ error: 'Quỹ không tồn tại', code: 'FUND_NOT_FOUND' });
  }

  var fund = await Fund.findById(fundId);
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại', code: 'FUND_NOT_FOUND' });
  }

  // Chỉ chủ quỹ mới được rút tiền
  if (!fundRules.isFundOwner(fund, req.user.id)) {
    return res.status(403).json({
      error: 'Chỉ chủ quỹ mới được rút tiền',
      code: 'NOT_FUND_OWNER'
    });
  }

  var rawAmount = req.body.amount;
  if (rawAmount === undefined || rawAmount === null || String(rawAmount).trim() === '') {
    return res.status(400).json({ error: 'Vui lòng nhập số tiền muốn rút', code: 'AMOUNT_REQUIRED' });
  }

  var amountStr = String(rawAmount).trim().replace(/,/g, '');
  if (!/^\d+(\.\d+)?$/.test(amountStr)) {
    return res.status(400).json({ error: 'Số tiền không hợp lệ', code: 'INVALID_AMOUNT' });
  }

  var amount = Number(amountStr);
  if (!Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'Số tiền không hợp lệ', code: 'INVALID_AMOUNT' });
  }

  if (amount < 1000) {
    return res.status(400).json({ error: 'Tối thiểu 1000đ', code: 'MIN_AMOUNT_1000' });
  }

  // Số tiền rút không được vượt quá số dư của quỹ
  if (amount > Number(fund.currentAmount || 0)) {
    return res.status(400).json({
      error: 'Số dư quỹ không đủ để rút',
      code: 'INSUFFICIENT_FUND_BALANCE',
      currentAmount: fund.currentAmount
    });
  }

  var note = String(req.body.note || '').trim();
  if (note) {
    var words = note.split(/\s+/).filter(Boolean);
    if (words.length > 200) {
      return res.status(400).json({ error: 'Tối đa 200 từ', code: 'NOTE_TOO_LONG' });
    }
  }

  var user = await User.findById(req.user.id);
  if (!user) {
    return res.status(404).json({ error: 'Người dùng không tồn tại' });
  }

  // Trừ tiền khỏi quỹ (kèm điều kiện currentAmount >= amount để không rút quá số dư)
  var updatedFund = await Fund.findOneAndUpdate(
    { _id: fund._id, currentAmount: { $gte: amount } },
    { $inc: { currentAmount: -amount } },
    { new: true }
  );
  if (!updatedFund) {
    return res.status(400).json({
      error: 'Số dư quỹ không đủ để rút',
      code: 'INSUFFICIENT_FUND_BALANCE',
      currentAmount: fund.currentAmount
    });
  }

  try {
    // Cộng tiền vào ví cá nhân của chủ quỹ
    var credited = await User.findOneAndUpdate(
      { _id: user._id },
      { $inc: { walletBalance: amount } },
      { new: true }
    );

    var txn = await Transaction.create({
      transactionCode: code(),
      userId: user._id,
      account: user.email,
      type: 'fund_withdrawal',
      amount: amount,
      sender: fund.name,
      recipient: user.name || user.email,
      note: note,
      status: 'completed',
      metadata: { fundId: fund.id, fundName: fund.name }
    });

    res.json({
      message: 'Rút tiền thành công',
      fund: updatedFund,
      walletBalance: credited.walletBalance,
      transaction: txn
    });
  } catch (error) {
    // Hoàn tác khi phát sinh lỗi trong quá trình rút tiền
    await Fund.updateOne({ _id: fund._id }, { $inc: { currentAmount: amount } });
    await User.updateOne({ _id: user._id }, { $inc: { walletBalance: -amount } });
    return res.status(500).json({ error: 'Rút tiền không thành công', code: 'WITHDRAWAL_FAILED' });
  }
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

exports.leave = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findById(fundId);
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại', code: 'FUND_NOT_FOUND' });
  }

  // Chủ quỹ không thể dùng chức năng rời quỹ (chủ quỹ phải chọn xoá quỹ)
  if (fund.userId && fund.userId.toString() === req.user.id.toString()) {
    return res.status(400).json({
      error: 'Chủ quỹ không thể rời quỹ. Bạn có thể chọn xoá quỹ.',
      code: 'OWNER_CANNOT_LEAVE'
    });
  }

  // Kiểm tra xem người dùng có phải là thành viên trong mảng members hay không
  var memberIndex = -1;
  if (Array.isArray(fund.members)) {
    memberIndex = fund.members.findIndex(function(m) {
      var mId = m.userId ? (m.userId._id || m.userId).toString() : m.toString();
      return mId === req.user.id.toString();
    });
  }

  if (memberIndex === -1) {
    return res.status(400).json({
      error: 'Bạn không phải là thành viên của quỹ này',
      code: 'NOT_A_MEMBER'
    });
  }

  // Xoá thành viên khỏi quỹ
  fund.members.splice(memberIndex, 1);
  await fund.save();

  // Thông báo cho chủ quỹ biết thành viên đã rời quỹ
  try {
    var leaver = await User.findById(req.user.id);
    var leaverName = leaver ? leaver.name : 'Một thành viên';
    await Notification.create({
      userId: fund.userId,
      title: 'Thành viên đã rời quỹ',
      message: leaverName + ' đã rời khỏi quỹ "' + fund.name + '"',
      type: 'member_left',
      metadata: {
        fundId: fund._id,
        fundName: fund.name,
        leaverId: req.user.id,
        leaverName: leaverName
      }
    });
  } catch (_) {}

  res.json({
    message: 'Rời quỹ thành công',
    fundId: fund._id
  });
};

exports.delete = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findOne({ _id: fundId, userId: req.user.id });
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại hoặc bạn không có quyền xóa quỹ này' });
  }

  // Quỹ chỉ được xoá khi số dư của quỹ còn 0đ
  if (Number(fund.currentAmount || 0) > 0) {
    return res.status(400).json({
      error: 'Chỉ được xoá quỹ khi số dư quỹ bằng 0',
      code: 'FUND_NOT_EMPTY',
      currentAmount: fund.currentAmount
    });
  }

  await FundInvitation.deleteMany({ fundId: fund._id });
  await Fund.deleteOne({ _id: fund._id });
  res.json({ message: 'Xoá quỹ thành công', id: fund._id });
};

function code() { return 'TX-' + crypto.randomUUID(); }