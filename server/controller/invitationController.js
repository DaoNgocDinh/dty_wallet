var Fund = require('../model/Fund');
var FundInvitation = require('../model/FundInvitation');
var Notification = require('../model/Notification');
var User = require('../model/User');
var fundRules = require('../utils/fundRules');

function isFundMember(fund, userId) {
  if (!fund || !userId) return false;
  var uid = userId.toString();
  if (fund.userId && fund.userId.toString() === uid) return true;
  if (Array.isArray(fund.members)) {
    return fund.members.some(function(m) {
      var mId = m.userId ? (m.userId._id || m.userId).toString() : m.toString();
      return mId === uid;
    });
  }
  return false;
}

// Lấy danh sách ứng viên (đề xuất hoặc tìm kiếm theo tên / số điện thoại)
exports.getCandidates = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findById(fundId);
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại' });
  }

  // Pre-condition: Người dùng phải là thành viên của quỹ (E1)
  if (!isFundMember(fund, req.user.id)) {
    return res.status(403).json({
      error: 'Bạn không phải là thành viên của quỹ',
      code: 'NOT_FUND_MEMBER'
    });
  }

  // Pre-condition: Quỹ không phải là quỹ cá nhân (E2)
  if (fund.fundType === 'Cá nhân') {
    return res.status(400).json({
      error: 'Quỹ cá nhân không thể mời thành viên',
      code: 'PERSONAL_FUND_CANNOT_INVITE'
    });
  }

  // Quỹ cặp đôi chỉ được có 2 người dùng nên không thể mời thêm
  var coupleBlocked = await fundRules.checkCoupleFundCapacity(fund);
  if (coupleBlocked) {
    return res.status(coupleBlocked.status).json(coupleBlocked.body);
  }

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

  var users = await User.find(userFilter).limit(30).select('name email phoneNumber walletBalance role');

  // Ẩn tài khoản admin khỏi danh sách đề xuất và tìm kiếm ứng viên
  users = users.filter(function(u) {
    var r = String(u.role || '').toLowerCase();
    var n = String(u.name || '').trim().toLowerCase();
    var e = String(u.email || '').trim().toLowerCase();
    return r !== 'admin' && n !== 'admin' && !e.startsWith('admin@');
  });

  // Luồng con 4.2 / E3: Không tìm thấy người dùng phù hợp với thông tin tìm kiếm
  if (query && users.length === 0) {
    return res.status(200).json({
      count: 0,
      data: [],
      error: 'Không tìm thấy người dùng phù hợp',
      message: 'Không tìm thấy người dùng phù hợp',
      code: 'NO_USER_FOUND'
    });
  }

  // Lấy các lời mời đang chờ của quỹ này để đánh dấu
  var pendingInvites = await FundInvitation.find({
    fundId: fund._id,
    status: 'pending'
  });
  var pendingInviteeIds = new Set(pendingInvites.map(function(inv) {
    return inv.inviteeId.toString();
  }));

  var memberIds = new Set();
  if (fund.userId) memberIds.add(fund.userId.toString());
  if (Array.isArray(fund.members)) {
    fund.members.forEach(function(m) {
      var mid = m.userId ? (m.userId._id || m.userId).toString() : m.toString();
      memberIds.add(mid);
    });
  }

  var candidateList = users.map(function(u) {
    var uIdStr = u._id.toString();
    var isMember = memberIds.has(uIdStr);
    var hasPendingInvite = pendingInviteeIds.has(uIdStr);
    return {
      id: u._id,
      _id: u._id,
      name: u.name,
      email: u.email,
      phoneNumber: u.phoneNumber || '',
      isMember: isMember,
      hasPendingInvite: hasPendingInvite,
      canInvite: !isMember && !hasPendingInvite
    };
  });

  res.json({
    count: candidateList.length,
    data: candidateList,
    fund: {
      id: fund._id,
      name: fund.name,
      fundType: fund.fundType
    }
  });
};

// Gửi lời mời tham gia quỹ (Use Case 06)
exports.sendInvite = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findById(fundId);
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại' });
  }

  // 1.1: Người dùng không phải là thành viên của quỹ -> E1
  if (!isFundMember(fund, req.user.id)) {
    return res.status(403).json({
      error: 'Bạn không phải là thành viên của quỹ',
      code: 'NOT_FUND_MEMBER'
    });
  }

  // 1.2: Quỹ là quỹ cá nhân -> E2
  if (fund.fundType === 'Cá nhân') {
    return res.status(400).json({
      error: 'Quỹ cá nhân không thể mời thành viên',
      code: 'PERSONAL_FUND_CANNOT_INVITE'
    });
  }

  // Quỹ cặp đôi chỉ được có 2 người dùng: đã đủ 2 người hoặc đang chờ người được chọn đồng ý
  var coupleBlocked = await fundRules.checkCoupleFundCapacity(fund);
  if (coupleBlocked) {
    return res.status(coupleBlocked.status).json(coupleBlocked.body);
  }

  var inviteeId = req.body.inviteeId;
  var inviteePhone = req.body.phoneNumber || req.body.phone;
  var inviteeName = req.body.name;

  var targetUser = null;
  if (inviteeId) {
    targetUser = await User.findById(inviteeId);
  } else if (inviteePhone) {
    targetUser = await User.findOne({ phoneNumber: String(inviteePhone).trim() });
  } else if (inviteeName) {
    targetUser = await User.findOne({ name: String(inviteeName).trim() });
  }

  // Không chọn người dùng hoặc Người dùng chưa đăng ký tài khoản ví
  if (!targetUser) {
    return res.status(400).json({
      error: 'Người dùng chưa đăng ký tài khoản ví điện tử hoặc không tồn tại',
      code: 'USER_NOT_FOUND'
    });
  }

  // Không thể tự mời chính mình
  if (targetUser._id.toString() === req.user.id.toString()) {
    return res.status(400).json({
      error: 'Bạn không thể tự mời chính mình',
      code: 'CANNOT_INVITE_SELF'
    });
  }

  // Không thể mời tài khoản quản trị viên vào quỹ
  if (targetUser.role === 'admin' || (targetUser.name && targetUser.name.toLowerCase() === 'admin')) {
    return res.status(400).json({
      error: 'Không thể mời tài khoản quản trị viên vào quỹ',
      code: 'CANNOT_INVITE_ADMIN'
    });
  }

  // 6.1: Người được chọn đã là thành viên của quỹ -> E4
  if (isFundMember(fund, targetUser._id)) {
    return res.status(400).json({
      error: 'Người dùng đã là thành viên của quỹ',
      code: 'ALREADY_MEMBER'
    });
  }

  // 6.2: Người được chọn đã có lời mời đang chờ xử lý -> E5
  var existingInvite = await FundInvitation.findOne({
    fundId: fund._id,
    inviteeId: targetUser._id,
    status: 'pending'
  });
  if (existingInvite) {
    return res.status(400).json({
      error: 'Người dùng đã có lời mời tham gia quỹ',
      code: 'PENDING_INVITATION_EXISTS'
    });
  }

  // 7. Gửi lời mời & lưu thông tin lời mời
  try {
    var inviter = await User.findById(req.user.id);
    var inviterDisplayName = (inviter && inviter.name) ? inviter.name : 'Thành viên quỹ';

    var invitation = await FundInvitation.create({
      fundId: fund._id,
      fundName: fund.name,
      fundType: fund.fundType,
      inviterId: req.user.id,
      inviterName: inviterDisplayName,
      inviteeId: targetUser._id,
      inviteeName: targetUser.name,
      inviteePhone: targetUser.phoneNumber || '',
      status: 'pending'
    });

    // Tạo thông báo cho người được mời
    await Notification.create({
      userId: targetUser._id,
      title: 'Lời mời tham gia quỹ',
      message: inviterDisplayName + ' đã mời bạn tham gia quỹ "' + fund.name + '" (' + fund.fundType + ')',
      type: 'fund_invitation',
      metadata: {
        invitationId: invitation._id,
        fundId: fund._id,
        fundName: fund.name,
        fundType: fund.fundType,
        inviterName: inviterDisplayName
      }
    });

    res.status(201).json({
      message: 'Gửi lời mời thành công',
      data: invitation
    });
  } catch (error) {
    // 7.1: Xảy ra lỗi khi gửi lời mời -> E6
    return res.status(500).json({
      error: 'Gửi lời mời không thành công',
      code: 'INVITE_FAILED'
    });
  }
};

// Xem danh sách lời mời của quỹ (đối với thành viên trong quỹ)
exports.listFundInvitations = async function(req, res) {
  var fundId = req.params.id;
  var fund = await Fund.findById(fundId);
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không tồn tại' });
  }
  if (!isFundMember(fund, req.user.id)) {
    return res.status(403).json({ error: 'Bạn không phải là thành viên của quỹ', code: 'NOT_FUND_MEMBER' });
  }
  var list = await FundInvitation.find({ fundId: fund._id }).sort({ createdAt: -1 });
  res.json({ count: list.length, data: list });
};

// Lấy danh sách lời mời mà người dùng hiện tại nhận được (giao diện kiểm tra lời mời hiện có)
exports.getMyInvitations = async function(req, res) {
  var filter = { inviteeId: req.user.id };
  if (req.query.status) {
    filter.status = req.query.status;
  }
  var list = await FundInvitation.find(filter).sort({ createdAt: -1 });
  res.json({ count: list.length, data: list });
};

// Đồng ý lời mời tham gia quỹ
exports.acceptInvite = async function(req, res) {
  var invitationId = req.params.id;
  var invitation = await FundInvitation.findOne({
    _id: invitationId,
    inviteeId: req.user.id
  });

  if (!invitation) {
    return res.status(404).json({ error: 'Lời mời không tồn tại hoặc bạn không có quyền' });
  }

  if (invitation.status !== 'pending') {
    return res.status(400).json({ error: 'Lời mời này đã được xử lý hoặc không còn hiệu lực' });
  }

  var fund = await Fund.findById(invitation.fundId);
  if (!fund) {
    return res.status(404).json({ error: 'Quỹ không còn tồn tại' });
  }

  // Quỹ cặp đôi chỉ có tối đa 2 người dùng
  if (fundRules.isCoupleFund(fund) && fundRules.countMembers(fund) >= fundRules.COUPLE_FUND_MAX_MEMBERS) {
    return res.status(400).json({
      error: 'Quỹ cặp đôi chỉ có 2 người dùng',
      code: 'COUPLE_FUND_FULL'
    });
  }

  // Thêm thành viên vào quỹ
  if (!isFundMember(fund, req.user.id)) {
    fund.members.push({
      userId: req.user.id,
      role: 'member',
      joinedAt: new Date()
    });
    await fund.save();
  }

  // Quỹ cặp đôi chỉ được lập chính thức khi đã có đủ 2 người dùng
  if (fundRules.isCoupleFund(fund) && fund.status !== 'active') {
    fund.status = 'active';
    await fund.save();
  }

  invitation.status = 'accepted';
  await invitation.save();

  // Tạo thông báo cho người đã gửi lời mời
  var currentUser = await User.findById(req.user.id);
  await Notification.create({
    userId: invitation.inviterId,
    title: 'Lời mời được chấp nhận',
    message: (currentUser ? currentUser.name : 'Thành viên') + ' đã đồng ý tham gia quỹ "' + fund.name + '"',
    type: 'invitation_accepted',
    metadata: {
      invitationId: invitation._id,
      fundId: fund._id,
      fundName: fund.name
    }
  });

  res.json({
    message: fundRules.isCoupleFund(fund)
      ? 'Tham gia quỹ cặp đôi thành công'
      : 'Tham gia quỹ thành công',
    data: invitation,
    fund: fund
  });
};

// Từ chối lời mời tham gia quỹ
exports.rejectInvite = async function(req, res) {
  var invitationId = req.params.id;
  var invitation = await FundInvitation.findOne({
    _id: invitationId,
    inviteeId: req.user.id
  });

  if (!invitation) {
    return res.status(404).json({ error: 'Lời mời không tồn tại hoặc bạn không có quyền' });
  }

  if (invitation.status !== 'pending') {
    return res.status(400).json({ error: 'Lời mời này đã được xử lý hoặc không còn hiệu lực' });
  }

  invitation.status = 'rejected';
  await invitation.save();

  try {
    var rejectUser = await User.findById(req.user.id);
    await Notification.create({
      userId: invitation.inviterId,
      title: 'Lời mời bị từ chối',
      message: (rejectUser ? rejectUser.name : 'Người dùng') + ' đã từ chối tham gia quỹ "' + invitation.fundName + '"',
      type: 'invitation_rejected',
      metadata: {
        invitationId: invitation._id,
        fundId: invitation.fundId,
        fundName: invitation.fundName
      }
    });
  } catch (_) {}

  res.json({
    message: 'Đã từ chối lời mời',
    data: invitation
  });
};
