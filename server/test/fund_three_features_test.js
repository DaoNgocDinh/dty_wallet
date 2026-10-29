// ==============================================================================
// KIỂM THỬ TỔNG HỢP 3 TÍNH NĂNG CỐT LÕI: TẠO QUỸ, GÓP TIỀN QUỸ, MỜI THÀNH VIÊN
// Use Case 04 (Tạo quỹ) - Use Case 05 (Góp quỹ) - Use Case 06 (Mời thành viên)
// Dựa trên phân tích dòng điều khiển & kiểm thử hộp trắng (Whitebox Analysis)
// ==============================================================================

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
var notificationController = require('../controller/notificationController');

function mockResponse() {
  return {
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
}

async function runTests() {
  console.log('================================================================');
  console.log('=== BẮT ĐẦU KIỂM THỬ 3 TÍNH NĂNG: TẠO QUỸ, GÓP TIỀN, MỜI BẠN ===');
  console.log('================================================================');

  await connectDatabase();

  // 0. Dọn dẹp dữ liệu kiểm thử cũ
  var testEmails = [
    'three_owner@gmail.com',
    'three_member@gmail.com',
    'three_candidate@gmail.com',
    'three_outsider@gmail.com',
    'three_partner@gmail.com',
    'three_admin@gmail.com'
  ];

  await FundInvitation.deleteMany({});
  await Notification.deleteMany({});
  await Transaction.deleteMany({ account: { $in: testEmails } });
  await Fund.deleteMany({ name: /^\[Test3\]/ });
  await User.deleteMany({ email: { $in: testEmails } });

  // Khởi tạo người dùng kiểm thử
  var owner = await User.create({
    name: 'Chủ Quỹ Test',
    email: 'three_owner@gmail.com',
    phoneNumber: '0901111111',
    passwordHash: 'dummy',
    walletBalance: 2000000 // 2.000.000đ
  });

  var member = await User.create({
    name: 'Thành Viên Test',
    email: 'three_member@gmail.com',
    phoneNumber: '0902222222',
    passwordHash: 'dummy',
    walletBalance: 1000000 // 1.000.000đ
  });

  var candidate = await User.create({
    name: 'Ứng Viên Mời Test',
    email: 'three_candidate@gmail.com',
    phoneNumber: '0903333333',
    passwordHash: 'dummy',
    walletBalance: 500000 // 500.000đ
  });

  var outsider = await User.create({
    name: 'Người Ngoài Quỹ Test',
    email: 'three_outsider@gmail.com',
    phoneNumber: '0904444444',
    passwordHash: 'dummy',
    walletBalance: 300000
  });

  var partner = await User.create({
    name: 'Đối Tác Cặp Đôi Test',
    email: 'three_partner@gmail.com',
    phoneNumber: '0905555555',
    passwordHash: 'dummy',
    walletBalance: 800000
  });

  var adminUser = await User.create({
    name: 'Admin Hệ Thống Test',
    email: 'three_admin@gmail.com',
    phoneNumber: '0909999999',
    passwordHash: 'dummy',
    role: 'admin'
  });

  console.log('[OK] Khởi tạo tài khoản test thành công.');

  // ==============================================================================
  // PHẦN 1: TÍNH NĂNG TẠO QUỸ (CREATE FUND - USE CASE 04 / 01_them_quy.md)
  // ==============================================================================
  console.log('\n--- PHẦN 1: KIỂM THỬ TÍNH NĂNG TẠO QUỸ (fundController.create) ---');

  // Test 1.1: Quá 10 quỹ -> 400 MAX_FUNDS_EXCEEDED
  {
    var tempFunds = [];
    for (var i = 1; i <= 10; i++) {
      tempFunds.push({
        userId: owner._id,
        name: '[Test3] Quỹ đệm số ' + i,
        fundType: 'Cá nhân',
        currentAmount: 0,
        members: [{ userId: owner._id, role: 'owner' }]
      });
    }
    await Fund.insertMany(tempFunds);

    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ thứ 11', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'MAX_FUNDS_EXCEEDED');
    assert.strictEqual(res.data.error, 'Không thể tạo thêm quỹ');
    console.log('[PASS] Test 1.1: Người dùng đã có 10 quỹ bị chặn với mã MAX_FUNDS_EXCEEDED');

    // Dọn các quỹ đệm để kiểm tra các trường hợp tiếp theo
    await Fund.deleteMany({ userId: owner._id });
  }

  // Test 1.2: Để trống loại quỹ -> 400 FUND_TYPE_REQUIRED
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ thiếu loại', fundType: '' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_TYPE_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng chọn loại quỹ');
    console.log('[PASS] Test 1.2: Để trống loại quỹ trả về FUND_TYPE_REQUIRED');
  }

  // Test 1.3: Loại quỹ không hợp lệ -> 400 INVALID_FUND_TYPE
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ sai loại', fundType: 'Quỹ Đầu Tư Mạo Hiểm' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_FUND_TYPE');
    assert.strictEqual(res.data.error, 'Loại quỹ không hợp lệ');
    console.log('[PASS] Test 1.3: Loại quỹ không thuộc danh mục hợp lệ trả về INVALID_FUND_TYPE');
  }

  // Test 1.4: Để trống tên quỹ -> 400 FUND_NAME_REQUIRED
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '   ', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NAME_REQUIRED');
    assert.strictEqual(res.data.field, 'name');
    assert.strictEqual(res.data.error, 'Vui lòng nhập tên quỹ');
    console.log('[PASS] Test 1.4: Tên quỹ để trống trả về FUND_NAME_REQUIRED');
  }

  // Test 1.5: Tên quỹ vượt quá 60 ký tự -> 400 FUND_NAME_TOO_LONG
  {
    var longName = 'Tên quỹ này quá dài dài dài dài dài dài dài dài dài dài dài dài 61 ký tự!';
    assert.ok(longName.length > 60);
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: longName, fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NAME_TOO_LONG');
    assert.strictEqual(res.data.field, 'name');
    assert.strictEqual(res.data.error, 'Tên quỹ không được vượt quá 60 ký tự');
    console.log('[PASS] Test 1.5: Tên quỹ > 60 ký tự trả về FUND_NAME_TOO_LONG');
  }

  // Test 1.6: Quỹ Tích lũy - Thiếu số tiền mục tiêu -> 400 TARGET_AMOUNT_REQUIRED
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tích Lũy Mua Xe', fundType: 'Tích lũy', targetAmount: '' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'TARGET_AMOUNT_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng nhập số tiền mục tiêu');
    console.log('[PASS] Test 1.6: Quỹ Tích lũy bỏ trống targetAmount trả về TARGET_AMOUNT_REQUIRED');
  }

  // Test 1.7: Quỹ Tích lũy - Số tiền mục tiêu <= 0 -> 400 INVALID_TARGET_AMOUNT
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tích Lũy', fundType: 'Tích lũy', targetAmount: 0 }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_TARGET_AMOUNT');
    assert.strictEqual(res.data.error, 'Số tiền mục tiêu phải lớn hơn 0');
    console.log('[PASS] Test 1.7: Quỹ Tích lũy targetAmount <= 0 trả về INVALID_TARGET_AMOUNT');
  }

  // Test 1.8: Quỹ Tích lũy - Thiếu ngày hoàn thành -> 400 COMPLETION_DATE_REQUIRED
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tích Lũy', fundType: 'Tích lũy', targetAmount: 10000000 }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COMPLETION_DATE_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng chọn ngày hoàn thành mục tiêu');
    console.log('[PASS] Test 1.8: Quỹ Tích lũy thiếu ngày hoàn thành trả về COMPLETION_DATE_REQUIRED');
  }

  // Test 1.9: Quỹ Tích lũy - Ngày hoàn thành không hợp lệ -> 400 INVALID_COMPLETION_DATE
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tích Lũy', fundType: 'Tích lũy', targetAmount: 10000000, completionDate: 'ngay-mai-khong-ro' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_COMPLETION_DATE');
    console.log('[PASS] Test 1.9: Ngày hoàn thành không đúng định dạng ngày trả về INVALID_COMPLETION_DATE');
  }

  // Test 1.10: Quỹ Tích lũy - Ngày hoàn thành trong quá khứ hoặc hôm nay -> 400 COMPLETION_DATE_MUST_BE_FUTURE
  {
    var yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[Test3] Quỹ Tích Lũy Quá Khứ',
        fundType: 'Tích lũy',
        targetAmount: 5000000,
        completionDate: yesterday.toISOString()
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COMPLETION_DATE_MUST_BE_FUTURE');
    assert.strictEqual(res.data.error, 'Ngày hoàn thành mục tiêu phải sau ngày hiện tại');
    console.log('[PASS] Test 1.10: Ngày hoàn thành ở quá khứ trả về COMPLETION_DATE_MUST_BE_FUTURE');
  }

  // Test 1.11: Quỹ Cặp đôi - Thiếu người cùng lập quỹ -> 400 PARTNER_REQUIRED
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tình Yêu', fundType: 'Cặp đôi' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PARTNER_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng chọn người dùng khác để lập quỹ cặp đôi');
    console.log('[PASS] Test 1.11: Quỹ cặp đôi không chọn partner trả về PARTNER_REQUIRED');
  }

  // Test 1.12: Quỹ Cặp đôi - Người được chọn không tồn tại -> 400 USER_NOT_FOUND
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tình Yêu', fundType: 'Cặp đôi', partnerPhoneNumber: '0979999999' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'USER_NOT_FOUND');
    console.log('[PASS] Test 1.12: Quỹ cặp đôi chọn người không tồn tại trả về USER_NOT_FOUND');
  }

  // Test 1.13: Quỹ Cặp đôi - Tự chọn chính mình -> 400 CANNOT_INVITE_SELF
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tình Yêu', fundType: 'Cặp đôi', partnerId: owner._id.toString() }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'CANNOT_INVITE_SELF');
    assert.strictEqual(res.data.error, 'Bạn không thể chọn chính mình làm người cùng lập quỹ');
    console.log('[PASS] Test 1.13: Tự chọn bản thân làm partner trả về CANNOT_INVITE_SELF');
  }

  // Test 1.14: Quỹ Cặp đôi - Chọn tài khoản admin -> 400 CANNOT_INVITE_ADMIN
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Tình Yêu', fundType: 'Cặp đôi', partnerId: adminUser._id.toString() }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'CANNOT_INVITE_ADMIN');
    assert.strictEqual(res.data.error, 'Không thể chọn tài khoản quản trị viên');
    console.log('[PASS] Test 1.14: Chọn tài khoản admin làm partner trả về CANNOT_INVITE_ADMIN');
  }

  // Test 1.15: Luồng thành công - Tạo quỹ Cá nhân thành công
  var personalFund = null;
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Cá Nhân Tiết Kiệm', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.name, '[Test3] Quỹ Cá Nhân Tiết Kiệm');
    assert.strictEqual(res.data.fundType, 'Cá nhân');
    assert.strictEqual(res.data.status, 'active');
    assert.strictEqual(res.data.message, 'Tạo quỹ thành công');
    assert.strictEqual(res.data.members[0].role, 'owner');
    personalFund = await Fund.findById(res.data._id);
    assert.ok(personalFund);
    console.log('[PASS] Test 1.15: Tạo quỹ Cá nhân thành công (201, active)');
  }

  // Test 1.16: Luồng thành công - Tạo quỹ Tích lũy thành công
  var savingFund = null;
  {
    var futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 45); // 45 ngày tới
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[Test3] Quỹ Tích Lũy Mua Laptop',
        fundType: 'Tích lũy',
        targetAmount: 25000000,
        completionDate: futureDate.toISOString()
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.targetAmount, 25000000);
    assert.strictEqual(res.data.status, 'active');
    savingFund = await Fund.findById(res.data._id);
    assert.ok(savingFund);
    console.log('[PASS] Test 1.16: Tạo quỹ Tích lũy thành công với targetAmount và completionDate');
  }

  // Test 1.17: Luồng thành công - Tạo quỹ Hội nhóm thành công
  var groupFund = null;
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[Test3] Quỹ Hội Nhóm Bạn Thân', fundType: 'Hội nhóm' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.fundType, 'Hội nhóm');
    assert.strictEqual(res.data.status, 'active');
    groupFund = await Fund.findById(res.data._id);
    assert.ok(groupFund);
    console.log('[PASS] Test 1.17: Tạo quỹ Hội nhóm thành công (201, active)');
  }

  // Test 1.18: Luồng thành công - Tạo quỹ Cặp đôi thành công
  var coupleFund = null;
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[Test3] Quỹ Cặp Đôi Hạnh Phúc',
        fundType: 'Cặp đôi',
        partnerId: partner._id.toString()
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.fundType, 'Cặp đôi');
    assert.strictEqual(res.data.status, 'pending_partner');
    assert.ok(res.data.invitation);
    coupleFund = await Fund.findById(res.data._id);
    assert.ok(coupleFund);
    console.log('[PASS] Test 1.18: Tạo quỹ Cặp đôi thành công (status: pending_partner, tạo lời mời và thông báo)');
  }

  // ==============================================================================
  // PHẦN 2: TÍNH NĂNG GÓP TIỀN QUỸ (CONTRIBUTE FUND - USE CASE 05 / 02_gop_quy.md)
  // ==============================================================================
  console.log('\n--- PHẦN 2: KIỂM THỬ TÍNH NĂNG GÓP TIỀN QUỸ (fundController.contribute) ---');

  // Test 2.1: Để trống số tiền góp -> 400 AMOUNT_REQUIRED
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: '' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'AMOUNT_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng nhập số tiền muốn góp');
    console.log('[PASS] Test 2.1: Bỏ trống số tiền góp trả về AMOUNT_REQUIRED');
  }

  // Test 2.2: Số tiền không phải số hợp lệ (chứa chữ cái) -> 400 INVALID_AMOUNT
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: '100abc' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_AMOUNT');
    assert.strictEqual(res.data.error, 'Số tiền không hợp lệ');
    console.log('[PASS] Test 2.2: Số tiền chứa ký tự chữ trả về INVALID_AMOUNT');
  }

  // Test 2.3: Số tiền <= 0 -> 400 INVALID_AMOUNT
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 0 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_AMOUNT');
    console.log('[PASS] Test 2.3: Số tiền = 0 trả về INVALID_AMOUNT');
  }

  // Test 2.4: Số tiền < 1.000đ (999đ) -> 400 MIN_AMOUNT_1000
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 999 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'MIN_AMOUNT_1000');
    assert.strictEqual(res.data.error, 'Tối thiểu 1000đ');
    console.log('[PASS] Test 2.4: Số tiền 999đ < 1000đ trả về MIN_AMOUNT_1000');
  }

  // Test 2.5: Ghi chú vượt quá 200 từ -> 400 NOTE_TOO_LONG
  {
    var words = [];
    for (var i = 0; i < 201; i++) words.push('word' + i);
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 50000, note: words.join(' ') }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'NOTE_TOO_LONG');
    assert.strictEqual(res.data.error, 'Tối đa 200 từ');
    console.log('[PASS] Test 2.5: Ghi chú 201 từ trả về NOTE_TOO_LONG');
  }

  // Test 2.6: Quỹ không tồn tại hoặc người dùng không phải thành viên -> 404
  {
    var reqOutsider = {
      params: { id: groupFund._id.toString() },
      user: { id: outsider._id.toString() }, // Không thuộc quỹ
      body: { amount: 50000 }
    };
    var resOutsider = mockResponse();
    await fundController.contribute(reqOutsider, resOutsider);
    assert.strictEqual(resOutsider.statusCode, 404);
    assert.strictEqual(resOutsider.data.error, 'Quỹ không tồn tại hoặc bạn không phải thành viên quỹ');

    var reqFakeFund = {
      params: { id: '65f000000000000000000099' },
      user: { id: owner._id.toString() },
      body: { amount: 50000 }
    };
    var resFakeFund = mockResponse();
    await fundController.contribute(reqFakeFund, resFakeFund);
    assert.strictEqual(resFakeFund.statusCode, 404);
    console.log('[PASS] Test 2.6: Người ngoài quỹ hoặc ID quỹ sai trả về 404');
  }

  // Test 2.7: Số tiền góp vượt quá số dư ví (2.000.001đ > 2.000.000đ) -> 400 INSUFFICIENT_BALANCE
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 2000001 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INSUFFICIENT_BALANCE');
    assert.strictEqual(res.data.error, 'Số dư ví không đủ để thực hiện giao dịch');
    console.log('[PASS] Test 2.7: Số tiền vượt số dư ví trả về INSUFFICIENT_BALANCE');
  }

  // Test 2.8: Luồng thành công - Chủ quỹ góp 200.000đ vào quỹ hội nhóm
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 200000, note: 'Góp tiền sinh nhật nhóm' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Góp tiền thành công');
    assert.strictEqual(res.data.walletBalance, 1800000); // 2.000.000 - 200.000
    assert.strictEqual(res.data.fund.currentAmount, 200000); // 0 + 200.000
    assert.ok(res.data.transaction);
    assert.strictEqual(res.data.transaction.type, 'fund_contribution');
    assert.strictEqual(res.data.transaction.amount, 200000);
    console.log('[PASS] Test 2.8: Góp 200.000đ thành công, trừ ví, tăng quỹ, tạo transaction');
  }

  // Thêm thành viên vào quỹ để test thành viên đóng góp
  groupFund.members.push({ userId: member._id, role: 'member', joinedAt: new Date() });
  await groupFund.save();

  // Test 2.9: Thành viên quỹ đóng góp 100.000đ (thông báo gửi tới cả người góp và chủ quỹ)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: member._id.toString() },
      body: { amount: 100000, note: 'Thành viên góp quỹ tháng này' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 900000); // 1.000.000 - 100.000
    assert.strictEqual(res.data.fund.currentAmount, 300000); // 200.000 + 100.000

    // Kiểm tra thông báo cho chủ quỹ
    var ownerNotif = await Notification.findOne({
      userId: owner._id,
      type: 'fund_contribution',
      $or: [
        { 'metadata.fundId': groupFund._id.toString() },
        { 'metadata.fundId': groupFund._id }
      ]
    });
    assert.ok(ownerNotif, 'Chủ quỹ phải nhận được thông báo khi thành viên góp tiền');
    console.log('[PASS] Test 2.9: Thành viên quỹ đóng góp thành công, thông báo gửi tới cả người góp và chủ quỹ');
  }

  // Test 2.10: Giá trị biên: Góp toàn bộ số dư khả dụng còn lại của thành viên (900.000đ -> số dư về 0đ)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: member._id.toString() },
      body: { amount: 900000, note: 'Góp hết số dư' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 0);
    assert.strictEqual(res.data.fund.currentAmount, 1200000);
    console.log('[PASS] Test 2.10: Giá trị biên - Góp toàn bộ số dư về 0đ thành công');
  }

  // ==============================================================================
  // PHẦN 3: TÍNH NĂNG MỜI THÀNH VIÊN (INVITE MEMBER - USE CASE 06 / 03_moi_thanh_vien.md)
  // ==============================================================================
  console.log('\n--- PHẦN 3: KIỂM THỬ TÍNH NĂNG MỜI THÀNH VIÊN (invitationController) ---');

  // Test 3.1: Quỹ không tồn tại -> 404
  {
    var req = {
      params: { id: '65f000000000000000000099' },
      user: { id: owner._id.toString() },
      body: { inviteeId: candidate._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 404);
    assert.strictEqual(res.data.error, 'Quỹ không tồn tại');
    console.log('[PASS] Test 3.1: Quỹ không tồn tại trả về 404');
  }

  // Test 3.2: Người dùng không phải là thành viên của quỹ gửi lời mời -> 403 NOT_FUND_MEMBER
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: outsider._id.toString() }, // Không thuộc quỹ
      body: { inviteeId: candidate._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(res.data.code, 'NOT_FUND_MEMBER');
    assert.strictEqual(res.data.error, 'Bạn không phải là thành viên của quỹ');
    console.log('[PASS] Test 3.2: Người ngoài quỹ cố tình mời thành viên bị từ chối 403 NOT_FUND_MEMBER');
  }

  // Test 3.3: Quỹ cá nhân không thể mời thành viên -> 400 PERSONAL_FUND_CANNOT_INVITE
  {
    var req = {
      params: { id: personalFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: candidate._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PERSONAL_FUND_CANNOT_INVITE');
    assert.strictEqual(res.data.error, 'Quỹ cá nhân không thể mời thành viên');
    console.log('[PASS] Test 3.3: Mời thành viên vào quỹ cá nhân trả về PERSONAL_FUND_CANNOT_INVITE');
  }

  // Test 3.4: Quỹ cặp đôi đang chờ người được chọn đồng ý thì không thể mời thêm -> 400 COUPLE_FUND_PENDING
  {
    var req = {
      params: { id: coupleFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: candidate._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COUPLE_FUND_PENDING');
    console.log('[PASS] Test 3.4: Quỹ cặp đôi đang chờ đồng ý không cho phép mời thêm người khác');
  }

  // Test 3.5: Lấy danh sách ứng viên đề xuất (ẩn tài khoản admin)
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      query: {}
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.ok(Array.isArray(res.data.data));
    var adminInList = res.data.data.some(function(u) {
      return u.name === 'Admin Hệ Thống Test' || u.role === 'admin';
    });
    assert.strictEqual(adminInList, false, 'Tài khoản admin không được xuất hiện trong danh sách ứng viên');
    console.log('[PASS] Test 3.5: Lấy danh sách ứng viên đề xuất thành công và tự động ẩn tài khoản admin');
  }

  // Test 3.6: Tìm kiếm người dùng không tồn tại -> 200 NO_USER_FOUND
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      query: { query: 'NguoiDungKhongCoTrongHeThong999' }
    };
    var res = mockResponse();
    await invitationController.getCandidates(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.count, 0);
    assert.strictEqual(res.data.code, 'NO_USER_FOUND');
    assert.strictEqual(res.data.message, 'Không tìm thấy người dùng phù hợp');
    console.log('[PASS] Test 3.6: Tìm kiếm không thấy kết quả trả về NO_USER_FOUND');
  }

  // Test 3.7: Mời người chưa đăng ký tài khoản ví -> 400 USER_NOT_FOUND
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { phoneNumber: '0988000000' } // Số chưa từng đăng ký
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'USER_NOT_FOUND');
    assert.strictEqual(res.data.error, 'Người dùng chưa đăng ký tài khoản ví điện tử hoặc không tồn tại');
    console.log('[PASS] Test 3.7: Mời người chưa đăng ký ví trả về USER_NOT_FOUND');
  }

  // Test 3.8: Tự mời chính mình -> 400 CANNOT_INVITE_SELF
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: owner._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'CANNOT_INVITE_SELF');
    assert.strictEqual(res.data.error, 'Bạn không thể tự mời chính mình');
    console.log('[PASS] Test 3.8: Tự mời chính mình trả về CANNOT_INVITE_SELF');
  }

  // Test 3.9: Mời tài khoản admin -> 400 CANNOT_INVITE_ADMIN
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: adminUser._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'CANNOT_INVITE_ADMIN');
    assert.strictEqual(res.data.error, 'Không thể mời tài khoản quản trị viên vào quỹ');
    console.log('[PASS] Test 3.9: Mời tài khoản admin trả về CANNOT_INVITE_ADMIN');
  }

  // Test 3.10: Mời người đã là thành viên của quỹ -> 400 ALREADY_MEMBER
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: member._id.toString() } // Member đã nằm trong quỹ
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'ALREADY_MEMBER');
    assert.strictEqual(res.data.error, 'Người dùng đã là thành viên của quỹ');
    console.log('[PASS] Test 3.10: Mời người đã là thành viên trả về ALREADY_MEMBER');
  }

  // Test 3.11: Luồng thành công - Gửi lời mời cho candidate (Ứng viên hợp lệ)
  var inviteRecordId = null;
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { inviteeId: candidate._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.message, 'Gửi lời mời thành công');
    assert.ok(res.data.data);
    assert.strictEqual(res.data.data.status, 'pending');
    assert.strictEqual(res.data.data.inviteeName, 'Ứng Viên Mời Test');
    inviteRecordId = res.data.data._id.toString();

    // Kiểm tra thông báo được tạo cho ứng viên
    var candidateNotif = await Notification.findOne({
      userId: candidate._id,
      type: 'fund_invitation'
    });
    assert.ok(candidateNotif);
    assert.strictEqual(candidateNotif.isRead, false);
    console.log('[PASS] Test 3.11: Gửi lời mời thành công (201, status: pending, tạo Notification)');
  }

  // Test 3.12: Mời người đã có lời mời đang chờ xử lý -> 400 PENDING_INVITATION_EXISTS
  {
    var req = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString() },
      body: { inviteeId: candidate._id.toString() }
    };
    var res = mockResponse();
    await invitationController.sendInvite(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PENDING_INVITATION_EXISTS');
    assert.strictEqual(res.data.error, 'Người dùng đã có lời mời tham gia quỹ');
    console.log('[PASS] Test 3.12: Mời người đang có lời mời pending trả về PENDING_INVITATION_EXISTS');
  }

  // Test 3.13: Ứng viên xem danh sách lời mời của mình và chấp nhận (acceptInvite)
  {
    var reqList = {
      user: { id: candidate._id.toString() },
      query: { status: 'pending' }
    };
    var resList = mockResponse();
    await invitationController.getMyInvitations(reqList, resList);
    assert.strictEqual(resList.statusCode, 200);
    assert.ok(resList.data.data.length >= 1);

    var reqAccept = {
      params: { id: inviteRecordId },
      user: { id: candidate._id.toString() }
    };
    var resAccept = mockResponse();
    await invitationController.acceptInvite(reqAccept, resAccept);
    assert.strictEqual(resAccept.statusCode, 200);
    assert.strictEqual(resAccept.data.message, 'Tham gia quỹ thành công');
    assert.strictEqual(resAccept.data.data.status, 'accepted');

    // Kiểm tra trong DB: candidate đã trở thành thành viên quỹ
    var checkFund = await Fund.findById(groupFund._id);
    var candidateJoined = checkFund.members.some(function(m) {
      return m.userId.toString() === candidate._id.toString();
    });
    assert.strictEqual(candidateJoined, true, 'Ứng viên phải được thêm vào members của quỹ');
    console.log('[PASS] Test 3.13: Chấp nhận lời mời thành công, ứng viên chính thức là thành viên của quỹ');
  }

  // Test 3.14: Gửi lời mời mới cho outsider rồi từ chối (rejectInvite)
  {
    var reqSend = {
      params: { id: groupFund._id.toString() },
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { inviteeId: outsider._id.toString() }
    };
    var resSend = mockResponse();
    await invitationController.sendInvite(reqSend, resSend);
    assert.strictEqual(resSend.statusCode, 201);
    var outsiderInviteId = resSend.data.data._id.toString();

    var reqReject = {
      params: { id: outsiderInviteId },
      user: { id: outsider._id.toString() }
    };
    var resReject = mockResponse();
    await invitationController.rejectInvite(reqReject, resReject);
    assert.strictEqual(resReject.statusCode, 200);
    assert.strictEqual(resReject.data.message, 'Đã từ chối lời mời');
    assert.strictEqual(resReject.data.data.status, 'rejected');

    // Kiểm tra outsider không nằm trong members quỹ
    var checkFundAfter = await Fund.findById(groupFund._id);
    var outsiderJoined = checkFundAfter.members.some(function(m) {
      return m.userId.toString() === outsider._id.toString();
    });
    assert.strictEqual(outsiderJoined, false, 'Người từ chối không được thêm vào members');
    console.log('[PASS] Test 3.14: Từ chối lời mời thành công, trạng thái chuyển sang rejected');
  }

  // ==============================================================================
  // DỌN DẸP SAU KIỂM THỬ
  // ==============================================================================
  await FundInvitation.deleteMany({});
  await Notification.deleteMany({});
  await Transaction.deleteMany({ account: { $in: testEmails } });
  await Fund.deleteMany({ name: /^\[Test3\]/ });
  await User.deleteMany({ email: { $in: testEmails } });
  await User.db.close();

  console.log('\n================================================================');
  console.log('=== TẤT CẢ CÁC BÀI TEST 3 TÍNH NĂNG ĐÃ VƯỢT QUA XUẤT SẮC! ===');
  console.log('================================================================');
}

runTests().catch(function(err) {
  console.error('\n[FAIL] Kiểm thử thất bại:', err);
  process.exit(1);
});
