// Unit / Integration test cho quy tắc Quỹ cặp đôi:
// - Bắt buộc chọn người dùng khác ngay từ lúc lập quỹ
// - Quỹ cặp đôi chỉ được có 2 người dùng
// - Quỹ chỉ được xoá khi số dư còn 0đ
require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Fund = require('../model/Fund');
var FundInvitation = require('../model/FundInvitation');
var Notification = require('../model/Notification');
var Transaction = require('../model/Transaction');
var fundController = require('../controller/fundController');
var invitationController = require('../controller/invitationController');
var fundRules = require('../utils/fundRules');

var TEST_EMAILS = [
  'couple_owner@gmail.com',
  'couple_partner@gmail.com',
  'couple_third@gmail.com',
  'couple_outsider@gmail.com'
];

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

function call(fn, req) {
  var res = mockResponse();
  return fn(req, res).then(function() {
    return res;
  });
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử quy tắc Quỹ cặp đôi (tối đa 2 người dùng & xoá khi số dư 0đ) ===');
  await connectDatabase();

  await User.deleteMany({ email: { $in: TEST_EMAILS } });
  await Fund.deleteMany({ name: { $regex: '^Quỹ Test Cặp Đôi' } });
  await FundInvitation.deleteMany({ fundName: { $regex: '^Quỹ Test Cặp Đôi' } });

  var owner = await User.create({
    name: 'Chủ Quỹ Cặp Đôi',
    email: 'couple_owner@gmail.com',
    phoneNumber: '0911000001',
    passwordHash: 'dummy',
    walletBalance: 3000000
  });

  var partner = await User.create({
    name: 'Người Yêu Cặp Đôi',
    email: 'couple_partner@gmail.com',
    phoneNumber: '0911000002',
    passwordHash: 'dummy',
    walletBalance: 1000000
  });

  var third = await User.create({
    name: 'Người Thứ Ba',
    email: 'couple_third@gmail.com',
    phoneNumber: '0911000003',
    passwordHash: 'dummy',
    walletBalance: 500000
  });

  var outsider = await User.create({
    name: 'Người Ngoài Cặp Đôi',
    email: 'couple_outsider@gmail.com',
    phoneNumber: '0911000004',
    passwordHash: 'dummy',
    walletBalance: 0
  });

  console.log('[OK] Khởi tạo dữ liệu test');

  // Test 1: Lập quỹ cặp đôi mà không chọn người dùng khác -> 400 PARTNER_REQUIRED
  {
    var res = await call(fundController.create, {
      user: { id: owner._id.toString() },
      body: { name: 'Quỹ Test Cặp Đôi Du Lịch', fundType: 'Cặp đôi' }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PARTNER_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng chọn người dùng khác để lập quỹ cặp đôi');
    assert.strictEqual(res.data.field, 'partnerId');
    console.log('[PASS] Test 1: Lập quỹ cặp đôi mà chưa chọn người dùng khác bị từ chối');
  }

  // Test 2: Chọn chính mình làm người cùng lập quỹ -> 400 CANNOT_INVITE_SELF
  {
    var res = await call(fundController.create, {
      user: { id: owner._id.toString() },
      body: {
        name: 'Quỹ Test Cặp Đôi Du Lịch',
        fundType: 'Cặp đôi',
        partnerId: owner._id.toString()
      }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'CANNOT_INVITE_SELF');
    console.log('[PASS] Test 2: Không thể chọn chính mình làm người cùng lập quỹ');
  }

  // Test 3: Chọn người dùng không tồn tại -> 400 USER_NOT_FOUND
  {
    var res = await call(fundController.create, {
      user: { id: owner._id.toString() },
      body: {
        name: 'Quỹ Test Cặp Đôi Du Lịch',
        fundType: 'Cặp đôi',
        partnerId: '65f000000000000000000088'
      }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'USER_NOT_FOUND');
    console.log('[PASS] Test 3: Người dùng được chọn không tồn tại bị từ chối');
  }

  // Test 4: Chọn tài khoản quản trị viên -> 400 CANNOT_INVITE_ADMIN
  {
    var admin = await User.findOne({ role: 'admin' });
    if (admin) {
      var res = await call(fundController.create, {
        user: { id: owner._id.toString() },
        body: {
          name: 'Quỹ Test Cặp Đôi Du Lịch',
          fundType: 'Cặp đôi',
          partnerId: admin._id.toString()
        }
      });
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.code, 'CANNOT_INVITE_ADMIN');
      console.log('[PASS] Test 4: Không thể chọn tài khoản quản trị viên làm người cùng lập quỹ');
    } else {
      console.log('[SKIP] Test 4: Không có tài khoản admin trong hệ thống');
    }
  }

  // Test 5: Lập quỹ cặp đôi thành công khi đã chọn người dùng khác
  {
    var res = await call(fundController.create, {
      user: { id: owner._id.toString(), name: owner.name, email: owner.email },
      body: {
        name: 'Quỹ Test Cặp Đôi Du Lịch',
        fundType: 'Cặp đôi',
        partnerId: partner._id.toString()
      }
    });
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.fundType, 'Cặp đôi');
    assert.strictEqual(res.data.status, 'pending_partner');
    assert.strictEqual(res.data.members.length, 1);
    assert.strictEqual(res.data.partner.name, partner.name);

    var invitation = await FundInvitation.findOne({ fundId: res.data._id, inviteeId: partner._id });
    assert(invitation);
    assert.strictEqual(invitation.status, 'pending');
    console.log('[PASS] Test 5: Lập quỹ cặp đôi thành công ở trạng thái chờ đồng ý, đã gửi lời mời');
  }

  var fund = await Fund.findOne({ name: 'Quỹ Test Cặp Đôi Du Lịch' });

  // Test 6: Trong lúc chờ đồng ý không được mời thêm người thứ ba
  {
    var res = await call(invitationController.sendInvite, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: third._id.toString() }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COUPLE_FUND_PENDING');
    console.log('[PASS] Test 6: Quỹ cặp đôi đang chờ đồng ý không thể mời thêm người thứ ba');
  }

  // Test 7: Người được chọn đồng ý -> quỹ chính thức có 2 người dùng
  {
    var invitation = await FundInvitation.findOne({ fundId: fund._id, inviteeId: partner._id });
    var res = await call(invitationController.acceptInvite, {
      params: { id: invitation._id.toString() },
      user: { id: partner._id.toString() }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Tham gia quỹ cặp đôi thành công');

    var updated = await Fund.findById(fund._id);
    assert.strictEqual(updated.status, 'active');
    assert.strictEqual(fundRules.countMembers(updated), 2);
    console.log('[PASS] Test 7: Người được chọn đồng ý, quỹ cặp đôi chính thức có 2 người dùng');
  }

  // Test 8: Quỹ cặp đôi đã đủ 2 người dùng -> không mời thêm được nữa
  {
    var res = await call(invitationController.sendInvite, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: third._id.toString() }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COUPLE_FUND_FULL');
    assert.strictEqual(res.data.error, 'Quỹ cặp đôi chỉ có 2 người dùng');

    var resCandidates = await call(invitationController.getCandidates, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      query: {}
    });
    assert.strictEqual(resCandidates.statusCode, 400);
    assert.strictEqual(resCandidates.data.code, 'COUPLE_FUND_FULL');
    console.log('[PASS] Test 8: Quỹ cặp đôi đã đủ 2 người dùng, không thể mời thêm');
  }

  // Test 9: Thành viên thứ hai cũng không thể mời thêm người thứ ba
  {
    var res = await call(invitationController.sendInvite, {
      params: { id: fund._id.toString() },
      user: { id: partner._id.toString() },
      body: { inviteeId: third._id.toString() }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COUPLE_FUND_FULL');
    console.log('[PASS] Test 9: Cả thành viên thứ hai cũng không thể mời thêm người thứ ba');
  }

  // Test 10: Người ngoài quỹ không xem được danh sách ứng viên
  {
    var res = await call(invitationController.getCandidates, {
      params: { id: fund._id.toString() },
      user: { id: outsider._id.toString() },
      query: {}
    });
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(res.data.code, 'NOT_FUND_MEMBER');
    console.log('[PASS] Test 10: Người ngoài quỹ không được xem danh sách ứng viên');
  }

  // Test 11: Tìm kiếm người dùng để chọn làm người cùng lập quỹ (trước khi tạo quỹ)
  {
    var res = await call(fundController.partnerCandidates, {
      user: { id: owner._id.toString() },
      query: { query: 'Người Thứ Ba' }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.count, 1);
    assert.strictEqual(res.data.data[0].name, third.name);

    var resNone = await call(fundController.partnerCandidates, {
      user: { id: owner._id.toString() },
      query: { query: 'khong-ton-tai-xyz' }
    });
    assert.strictEqual(resNone.statusCode, 200);
    assert.strictEqual(resNone.data.count, 0);
    assert.strictEqual(resNone.data.code, 'NO_USER_FOUND');
    console.log('[PASS] Test 11: Tìm kiếm người dùng để chọn làm người cùng lập quỹ hoạt động đúng');
  }

  // Test 12: Quỹ cặp đôi đang có tiền không được xoá
  {
    await Fund.updateOne({ _id: fund._id }, { $set: { currentAmount: 250000 } });

    var res = await call(fundController.delete, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NOT_EMPTY');
    assert.strictEqual(res.data.error, 'Chỉ được xoá quỹ khi số dư quỹ bằng 0');

    var stillExists = await Fund.findById(fund._id);
    assert(stillExists !== null);
    console.log('[PASS] Test 12: Quỹ cặp đôi còn 250.000đ không được xoá');
  }

  // Test 13: Rút đúng toàn bộ số dư quỹ rồi xoá được
  {
    var resWithdraw = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 250000 }
    });
    assert.strictEqual(resWithdraw.statusCode, 200);
    assert.strictEqual(resWithdraw.data.fund.currentAmount, 0);

    var res = await call(fundController.delete, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Xoá quỹ thành công');
    console.log('[PASS] Test 13: Rút hết tiền (quỹ về 0đ) rồi xoá quỹ cặp đôi thành công');
  }

  // Dọn dẹp dữ liệu test
  await Transaction.deleteMany({ userId: { $in: [owner._id, partner._id, third._id, outsider._id] } });
  await FundInvitation.deleteMany({ fundName: { $regex: '^Quỹ Test Cặp Đôi' } });
  await Notification.deleteMany({
    userId: { $in: [owner._id, partner._id, third._id, outsider._id] }
  });
  await User.deleteMany({ _id: { $in: [owner._id, partner._id, third._id, outsider._id] } });
  await User.db.close();

  console.log('--- TẤT CẢ CÁC BÀI TEST QUỸ CẶP ĐÔI ĐÃ VƯỢT QUA THÀNH CÔNG (13/13) ---');
}

runTests().catch(function(err) {
  console.error('Test thất bại:', err);
  process.exit(1);
});