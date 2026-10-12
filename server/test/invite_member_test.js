// Unit / Integration test cho API Mời thành viên (Use Case 06)
require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Fund = require('../model/Fund');
var FundInvitation = require('../model/FundInvitation');
var Notification = require('../model/Notification');
var invitationController = require('../controller/invitationController');
var notificationController = require('../controller/notificationController');

function mockResponse() {
  var res = {
    statusCode: 200,
    headers: {},
    data: null,
    status: function(code) {
      this.statusCode = code;
      return this;
    },
    json: function(payload) {
      this.data = payload;
      return this;
    }
  };
  return res;
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử Backend Use Case 06: Mời thành viên (Đào Ngọc Đình) ===');
  await connectDatabase();

  // Dọn dẹp dữ liệu cũ nếu có
  await FundInvitation.deleteMany({});
  await Notification.deleteMany({});
  await Fund.deleteMany({ name: { $in: ['Quỹ Test Hội Nhóm', 'Quỹ Test Cá Nhân'] } });
  await User.deleteMany({
    email: {
      $in: [
        'dinh_test@gmail.com',
        'user_a_test@gmail.com',
        'tran_b_test@gmail.com',
        'le_d_test@gmail.com',
        'pham_e_test@gmail.com'
      ]
    }
  });

  // Khởi tạo người dùng theo đặc tả phân vùng test:
  // 1. Đào Ngọc Đình: thành viên / chủ quỹ
  var userDinh = await User.create({
    name: 'Đào Ngọc Đình',
    email: 'dinh_test@gmail.com',
    phoneNumber: '0988888888',
    passwordHash: 'dummy',
    walletBalance: 2000000
  });

  // 2. Nguyễn Văn A: không thuộc quỹ
  var userA = await User.create({
    name: 'Nguyễn Văn A',
    email: 'user_a_test@gmail.com',
    phoneNumber: '0911111111',
    passwordHash: 'dummy',
    walletBalance: 1000000
  });

  // 3. Trần Văn B: có ví, chưa là thành viên, chưa có lời mời (Miền 1 hợp lệ)
  var userB = await User.create({
    name: 'Trần Văn B',
    email: 'tran_b_test@gmail.com',
    phoneNumber: '0912345678',
    passwordHash: 'dummy',
    walletBalance: 1500000
  });

  // 4. Lê Văn D: đã là thành viên của quỹ (Miền 3)
  var userD = await User.create({
    name: 'Lê Văn D',
    email: 'le_d_test@gmail.com',
    phoneNumber: '0987654321',
    passwordHash: 'dummy',
    walletBalance: 800000
  });

  // 5. Phạm Văn E: đã có lời mời đang chờ xử lý (Miền 4)
  var userE = await User.create({
    name: 'Phạm Văn E',
    email: 'pham_e_test@gmail.com',
    phoneNumber: '0911223344',
    passwordHash: 'dummy',
    walletBalance: 500000
  });

  // Khởi tạo quỹ:
  // Quỹ Hội nhóm (hợp lệ)
  var groupFund = await Fund.create({
    userId: userDinh._id,
    name: 'Quỹ Test Hội Nhóm',
    fundType: 'Hội nhóm',
    targetAmount: 10000000,
    currentAmount: 1000000,
    members: [
      { userId: userDinh._id, role: 'owner', joinedAt: new Date() },
      { userId: userD._id, role: 'member', joinedAt: new Date() } // Lê Văn D đã là thành viên
    ]
  });

  // Quỹ Cá nhân (không hợp lệ để mời thành viên)
  var personalFund = await Fund.create({
    userId: userDinh._id,
    name: 'Quỹ Test Cá Nhân',
    fundType: 'Cá nhân',
    targetAmount: 5000000,
    currentAmount: 500000,
    members: [{ userId: userDinh._id, role: 'owner', joinedAt: new Date() }]
  });

  // Tạo sẵn một lời mời pending cho Phạm Văn E
  var existingInviteE = await FundInvitation.create({
    fundId: groupFund._id,
    fundName: groupFund.name,
    fundType: groupFund.fundType,
    inviterId: userDinh._id,
    inviterName: userDinh.name,
    inviteeId: userE._id,
    inviteeName: userE.name,
    inviteePhone: userE.phoneNumber,
    status: 'pending'
  });

  console.log('[OK] Đã chuẩn bị toàn bộ dữ liệu mẫu theo đặc tả.');

  // Test 1: Exception 1.1 / E1: Người dùng không phải là thành viên của quỹ
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userA._id.toString() }, // Nguyễn Văn A không thuộc quỹ
      query: {}
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(res.data.code, 'NOT_FUND_MEMBER');
    assert.strictEqual(res.data.error, 'Bạn không phải là thành viên của quỹ');
    console.log('[PASS] Test 1: E1 - Người dùng không phải thành viên quỹ bị từ chối với thông báo "Bạn không phải là thành viên của quỹ"');
  }

  // Test 2: Exception 1.2 / E2: Quỹ là quỹ cá nhân
  {
    var req = {
      params: { id: personalFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: {}
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PERSONAL_FUND_CANNOT_INVITE');
    assert.strictEqual(res.data.error, 'Quỹ cá nhân không thể mời thành viên');
    console.log('[PASS] Test 2: E2 - Quỹ cá nhân không cho phép mời thành viên với thông báo "Quỹ cá nhân không thể mời thành viên"');
  }

  // Test 3: Luồng 4.1 & Đề xuất: Không nhập thông tin tìm kiếm -> Hiển thị danh sách đề xuất
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: {}
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert(res.data.count > 0);
    assert(Array.isArray(res.data.data));
    console.log('[PASS] Test 3: Luồng 4.1 - Không nhập tìm kiếm, hiển thị danh sách người dùng đề xuất (' + res.data.count + ' người)');
  }

  // Test 3b: Ẩn admin khỏi danh sách đề xuất và tìm kiếm
  {
    var adminUser = await User.findOne({ name: 'admin' });
    if (!adminUser) {
      adminUser = await User.create({
        name: 'admin',
        email: 'admin_invite_test@gmail.com',
        phoneNumber: '0900000000',
        passwordHash: 'dummy',
        role: 'admin'
      });
    }
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: {}
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    var hasAdminInCandidates = res.data.data.some(function(u) {
      return u.name === 'admin' || (u.role && u.role === 'admin');
    });
    assert.strictEqual(hasAdminInCandidates, false, 'Admin must not appear in suggested candidates list');

    // Tìm kiếm cụm từ admin cũng không được trả về
    var reqAdminQuery = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: { query: 'admin' }
    };
    var resAdminQuery = mockResponse();
    await invitationController.getCandidates(reqAdminQuery, resAdminQuery);
    assert.strictEqual(resAdminQuery.data.count, 0);

    // Không thể mời tài khoản admin vào quỹ
    var reqInviteAdmin = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      body: { inviteeId: adminUser._id.toString() }
    };
    var resInviteAdmin = mockResponse();
    await invitationController.sendInvite(reqInviteAdmin, resInviteAdmin);
    assert.strictEqual(resInviteAdmin.statusCode, 400);
    assert.strictEqual(resInviteAdmin.data.code, 'CANNOT_INVITE_ADMIN');
    console.log('[PASS] Test 3b: Ẩn admin khỏi danh sách đề xuất và chặn gửi lời mời vào quỹ cho admin');
  }

  // Test 4: Luồng con 4.1 / Tên tìm kiếm có kết quả hợp lệ
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: { query: 'Trần Văn B' }
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert(res.data.count >= 1);
    var found = res.data.data.find(function(u) { return u.name === 'Trần Văn B'; });
    assert(found);
    assert.strictEqual(found.canInvite, true);
    console.log('[PASS] Test 4: Luồng con 4.1 - Tìm kiếm theo tên "Trần Văn B" thành công');
  }

  // Test 5: Luồng con 4.2 / SĐT tìm kiếm có kết quả hợp lệ (0912345678)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: { query: '0912345678' }
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert(res.data.count >= 1);
    var found = res.data.data.find(function(u) { return u.phoneNumber === '0912345678'; });
    assert(found);
    assert.strictEqual(found.name, 'Trần Văn B');
    console.log('[PASS] Test 5: Luồng con 4.2 - Tìm kiếm theo SĐT "0912345678" thành công');
  }

  // Test 6: Exception 4.2 / E3: Không tìm thấy người dùng phù hợp (Tên: "Nguyễn Văn XYZ", SĐT: "0999999999")
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: { query: 'Nguyễn Văn XYZ' }
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.count, 0);
    assert.strictEqual(res.data.code, 'NO_USER_FOUND');
    assert.strictEqual(res.data.message, 'Không tìm thấy người dùng phù hợp');

    var reqPhone = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      query: { query: '0999999999' }
    };
    var resPhone = mockResponse();
    await invitationController.getCandidates(reqPhone, resPhone);
    assert.strictEqual(resPhone.data.count, 0);
    assert.strictEqual(resPhone.data.message, 'Không tìm thấy người dùng phù hợp');
    console.log('[PASS] Test 6: E3 - Không tìm thấy người dùng phù hợp theo tên hoặc SĐT hiển thị "Không tìm thấy người dùng phù hợp"');
  }

  // Test 7: Exception 6.1 / E4: Người được chọn đã là thành viên của quỹ (Lê Văn D)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      body: { inviteeId: userD._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'ALREADY_MEMBER');
    assert.strictEqual(res.data.error, 'Người dùng đã là thành viên của quỹ');
    console.log('[PASS] Test 7: E4 - Mời người đã là thành viên quỹ trả về lỗi "Người dùng đã là thành viên của quỹ"');
  }

  // Test 8: Exception 6.2 / E5: Người được chọn đã có lời mời đang chờ xử lý (Phạm Văn E)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      body: { inviteeId: userE._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PENDING_INVITATION_EXISTS');
    assert.strictEqual(res.data.error, 'Người dùng đã có lời mời tham gia quỹ');
    console.log('[PASS] Test 8: E5 - Mời người đã có lời mời đang chờ trả về lỗi "Người dùng đã có lời mời tham gia quỹ"');
  }

  // Test 9: Người chưa đăng ký tài khoản ví điện tử (Nguyễn Văn C)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      body: { phoneNumber: '0933333333' } // Chưa đăng ký
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'USER_NOT_FOUND');
    console.log('[PASS] Test 9: Mời người chưa đăng ký tài khoản ví bị từ chối');
  }

  // Test 10: Luồng thành công Miền 1: Mời người đủ điều kiện (Trần Văn B)
  var createdInviteId = null;
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: userDinh._id.toString() },
      body: { inviteeId: userB._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.message, 'Gửi lời mời thành công');
    assert(res.data.data);
    assert.strictEqual(res.data.data.status, 'pending');
    assert.strictEqual(res.data.data.inviteeName, 'Trần Văn B');
    createdInviteId = res.data.data._id.toString();
    console.log('[PASS] Test 10: Luồng thành công - Gửi lời mời cho Trần Văn B thành công thông báo "Gửi lời mời thành công"');
  }

  // Test 11: Kiểm tra Thông báo & Chấm đỏ cho người được mời (Trần Văn B)
  var notifId = null;
  {
    var req = {
      user: { id: userB._id.toString() }
    };
    var res = mockResponse();
    await notificationController.list(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert(res.data.unreadCount >= 1);
    assert(res.data.data.length >= 1);
    var inviteNotif = res.data.data.find(function(n) { return n.type === 'fund_invitation'; });
    assert(inviteNotif);
    assert.strictEqual(inviteNotif.isRead, false);
    notifId = inviteNotif._id.toString();
    console.log('[PASS] Test 11: Thông báo - Trần Văn B nhận được thông báo lời mời, unreadCount = ' + res.data.unreadCount + ' (hiển thị chấm đỏ)');
  }

  // Test 12: Đánh dấu thông báo đã đọc
  {
    var req = {
      params: { id: notifId },
      user: { id: userB._id.toString() }
    };
    var res = mockResponse();
    await notificationController.markRead(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.notification.isRead, true);
    console.log('[PASS] Test 12: Đọc thông báo - Đánh dấu thông báo đã đọc thành công');
  }

  // Test 13: Giao diện kiểm tra lời mời hiện có của người được mời (Trần Văn B)
  {
    var req = {
      user: { id: userB._id.toString() },
      query: { status: 'pending' }
    };
    var res = mockResponse();
    await invitationController.getMyInvitations(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert(res.data.data.length >= 1);
    var inv = res.data.data.find(function(i) { return i._id.toString() === createdInviteId; });
    assert(inv);
    assert.strictEqual(inv.fundName, 'Quỹ Test Hội Nhóm');
    console.log('[PASS] Test 13: Kiểm tra lời mời hiện có - Trần Văn B thấy lời mời đang chờ từ Quỹ Test Hội Nhóm');
  }

  // Test 14: Đồng ý (Chấp nhận) lời mời -> Người dùng trở thành thành viên của quỹ
  {
    var req = {
      params: { id: createdInviteId },
      user: { id: userB._id.toString() }
    };
    var res = mockResponse();
    await invitationController.acceptInvite(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Tham gia quỹ thành công');
    assert.strictEqual(res.data.data.status, 'accepted');

    // Kiểm tra trong DB xem Trần Văn B đã là thành viên quỹ chưa
    var updatedFund = await Fund.findById(groupFund._id);
    var isNowMember = updatedFund.members.some(function(m) {
      return m.userId.toString() === userB._id.toString();
    });
    assert(isNowMember, 'Trần Văn B phải có trong danh sách thành viên của quỹ');
    console.log('[PASS] Test 14: Chấp nhận lời mời - Trần Văn B chính thức trở thành thành viên quỹ');
  }

  // Test 15: Từ chối lời mời (Phạm Văn E từ chối lời mời)
  {
    var req = {
      params: { id: existingInviteE._id.toString() },
      user: { id: userE._id.toString() }
    };
    var res = mockResponse();
    await invitationController.rejectInvite(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Đã từ chối lời mời');
    assert.strictEqual(res.data.data.status, 'rejected');
    console.log('[PASS] Test 15: Từ chối lời mời - Phạm Văn E từ chối lời mời thành công, trạng thái chuyển thành rejected');
  }

  // Dọn dẹp sau kiểm thử
  await FundInvitation.deleteMany({});
  await Notification.deleteMany({});
  await Fund.deleteMany({ name: { $in: ['Quỹ Test Hội Nhóm', 'Quỹ Test Cá Nhân'] } });
  await User.deleteMany({
    email: {
      $in: [
        'dinh_test@gmail.com',
        'user_a_test@gmail.com',
        'tran_b_test@gmail.com',
        'le_d_test@gmail.com',
        'pham_e_test@gmail.com'
      ]
    }
  });

  await User.db.close();
  console.log('=== TẤT CẢ 15/15 BÀI TEST BACKEND USE CASE 06 ĐÃ THÀNH CÔNG RỰC RỠ! ===');
}

runTests().catch(function(err) {
  console.error('Test thất bại:', err);
  process.exit(1);
});
