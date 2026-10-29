require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Fund = require('../model/Fund');
var FundInvitation = require('../model/FundInvitation');
var Notification = require('../model/Notification');
var fundController = require('../controller/fundController');

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
  console.log('====================================================================');
  console.log('=== BẮT ĐẦU KIỂM THỬ TÍNH NĂNG TẠO QUỸ: 28 TEST CASES (TC01-TC28) ===');
  console.log('====================================================================');

  await connectDatabase();

  var testEmails = [
    'tc_owner_fund@gmail.com',
    'tc_partner_fund@gmail.com',
    'tc_admin_fund@gmail.com'
  ];

  await Fund.deleteMany({ name: /^\[TC\]/ });
  await FundInvitation.deleteMany({});
  await Notification.deleteMany({});
  await User.deleteMany({ email: { $in: testEmails } });

  // Khởi tạo tài khoản kiểm thử
  var owner = await User.create({
    name: 'Nguyễn Văn Chủ Quỹ',
    email: 'tc_owner_fund@gmail.com',
    phoneNumber: '0912111222',
    passwordHash: 'dummy',
    walletBalance: 2000000
  });

  var partner = await User.create({
    name: 'Trần Thị Bạn Đời',
    email: 'tc_partner_fund@gmail.com',
    phoneNumber: '0912333444',
    passwordHash: 'dummy',
    walletBalance: 1500000
  });

  var admin = await User.create({
    name: 'admin',
    email: 'tc_admin_fund@gmail.com',
    phoneNumber: '0912999888',
    passwordHash: 'dummy',
    role: 'admin'
  });

  console.log('[OK] Khởi tạo tài khoản test thành công.\n');
  {
    await Fund.deleteMany({ userId: owner._id });
    var dummyFunds = [];
    for (var i = 1; i <= 9; i++) {
      dummyFunds.push({
        userId: owner._id,
        name: '[TC] Quỹ có sẵn số ' + i,
        fundType: 'Cá nhân',
        members: [{ userId: owner._id, role: 'owner' }]
      });
    }
    await Fund.insertMany(dummyFunds);

    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[TC] Quỹ cá nhân thứ 10', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.name, '[TC] Quỹ cá nhân thứ 10');
    console.log('[PASS] TC01: Người dùng đang có 9 quỹ -> Tạo quỹ thứ 10 thành công');
  }

  // ----------------------------------------------------------------------------
  // TC02: Người dùng đạt giới hạn 10 quỹ -> Báo lỗi E1 (MAX_FUNDS_EXCEEDED)
  // ----------------------------------------------------------------------------
  {
    var count = await Fund.countDocuments({ userId: owner._id });
    assert.strictEqual(count, 10);

    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[TC] Quỹ thứ 11 vượt giới hạn', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'MAX_FUNDS_EXCEEDED');
    assert.strictEqual(res.data.error, 'Không thể tạo thêm quỹ');
    console.log('[PASS] TC02: Đạt giới hạn 10 quỹ -> Báo lỗi E1 (MAX_FUNDS_EXCEEDED: "Không thể tạo thêm quỹ")');

    // Dọn dẹp các quỹ đệm để kiểm tra các test case tiếp theo
    await Fund.deleteMany({ userId: owner._id });
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: { name: '[TC] Quỹ tiết kiệm', fundType: '' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_TYPE_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng chọn loại quỹ');
    console.log('[PASS] TC03: Không chọn loại quỹ -> Báo lỗi E2 (FUND_TYPE_REQUIRED: "Vui lòng chọn loại quỹ")');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: { name: '[TC] Quỹ tiết kiệm', fundType: 'Đầu tư' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_FUND_TYPE');
    assert.strictEqual(res.data.error, 'Loại quỹ không hợp lệ');
    console.log('[PASS] TC04: Chọn loại quỹ ngoài danh sách ("Đầu tư") -> Báo lỗi E3 (INVALID_FUND_TYPE)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[TC] Quỹ cá nhân hợp lệ', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.fundType, 'Cá nhân');
    assert.strictEqual(res.data.status, 'active');
    console.log('[PASS] TC05: Chọn loại quỹ Cá nhân hợp lệ -> Tạo quỹ thành công (201, active)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ của chúng tôi',
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
    console.log('[PASS] TC06: Chọn loại quỹ Cặp đôi (đối tác hợp lệ) -> Tạo quỹ thành công (status: pending_partner)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ mua laptop',
        fundType: 'Tích lũy',
        targetAmount: 20000000,
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.fundType, 'Tích lũy');
    assert.strictEqual(res.data.targetAmount, 20000000);
    console.log('[PASS] TC07: Chọn loại quỹ Tích lũy đầy đủ thông tin -> Tạo quỹ thành công');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[TC] Quỹ lớp KTPM', fundType: 'Hội nhóm' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.fundType, 'Hội nhóm');
    assert.strictEqual(res.data.status, 'active');
    console.log('[PASS] TC08: Chọn loại quỹ Hội nhóm hợp lệ -> Tạo quỹ thành công');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: { name: '   ', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NAME_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng nhập tên quỹ');
    console.log('[PASS] TC09: Tên quỹ để trống -> Báo lỗi E4 (FUND_NAME_REQUIRED)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: 'A', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.name, 'A');
    console.log('[PASS] TC10: Tên quỹ có 1 ký tự ("A") -> Chấp nhận tên quỹ');
  }
  {
    var name60 = 'Q'.repeat(60);
    assert.strictEqual(name60.length, 60);
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: name60, fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.name, name60);
    console.log('[PASS] TC11: Tên quỹ đúng 60 ký tự -> Chấp nhận tên quỹ');
  }
  {
    var name61 = 'Q'.repeat(61);
    assert.strictEqual(name61.length, 61);
    var req = {
      user: { id: owner._id.toString() },
      body: { name: name61, fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NAME_TOO_LONG');
    assert.strictEqual(res.data.error, 'Tên quỹ không được vượt quá 60 ký tự');
    console.log('[PASS] TC12: Tên quỹ vượt 60 ký tự (61 ký tự) -> Báo lỗi E5 (FUND_NAME_TOO_LONG)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: '',
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'TARGET_AMOUNT_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng nhập số tiền mục tiêu');
    console.log('[PASS] TC13: Tích lũy bỏ trống số tiền -> Báo lỗi E6 (TARGET_AMOUNT_REQUIRED)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: 0,
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_TARGET_AMOUNT');
    assert.strictEqual(res.data.error, 'Số tiền mục tiêu phải lớn hơn 0');
    console.log('[PASS] TC14: Số tiền mục tiêu bằng 0 -> Báo lỗi E7 (INVALID_TARGET_AMOUNT)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: -100000,
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_TARGET_AMOUNT');
    console.log('[PASS] TC15: Số tiền mục tiêu âm (-100.000) -> Báo lỗi E7 (INVALID_TARGET_AMOUNT)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: 'abc',
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_TARGET_AMOUNT');
    console.log('[PASS] TC16: Số tiền mục tiêu không phải số ("abc") -> Báo lỗi E7 (INVALID_TARGET_AMOUNT)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ mua xe nhỏ nhất',
        fundType: 'Tích lũy',
        targetAmount: 1,
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.targetAmount, 1);
    console.log('[PASS] TC17: Số tiền mục tiêu nhỏ nhất hợp lệ (1đ) -> Chấp nhận số tiền (Tạo quỹ thành công)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: 20000000,
        completionDate: ''
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COMPLETION_DATE_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng chọn ngày hoàn thành mục tiêu');
    console.log('[PASS] TC18: Không chọn ngày hoàn thành -> Báo lỗi E8 (COMPLETION_DATE_REQUIRED)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: 20000000,
        completionDate: 'ngay-sai'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_COMPLETION_DATE');
    assert.strictEqual(res.data.error, 'Vui lòng chọn ngày hoàn thành mục tiêu');
    console.log('[PASS] TC19: Chọn ngày sai định dạng ("ngay-sai") -> Báo lỗi E8 (INVALID_COMPLETION_DATE)');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: 20000000,
        completionDate: '2025-01-01T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COMPLETION_DATE_MUST_BE_FUTURE');
    assert.strictEqual(res.data.error, 'Ngày hoàn thành mục tiêu phải sau ngày hiện tại');
    console.log('[PASS] TC20: Ngày hoàn thành ở quá khứ (01/01/2025) -> Báo lỗi E9 (COMPLETION_DATE_MUST_BE_FUTURE)');
  }
  {
    var today = new Date();
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ mua xe',
        fundType: 'Tích lũy',
        targetAmount: 20000000,
        completionDate: today.toISOString()
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'COMPLETION_DATE_MUST_BE_FUTURE');
    console.log('[PASS] TC21: Ngày hoàn thành trùng ngày hôm nay -> Báo lỗi E9 (COMPLETION_DATE_MUST_BE_FUTURE)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ mua xe hợp lệ',
        fundType: 'Tích lũy',
        targetAmount: 20000000,
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.status, 'active');
    console.log('[PASS] TC22: Ngày hoàn thành hợp lệ trong tương lai (30/12/2026) -> Tạo quỹ thành công');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '',
        fundType: 'Tích lũy',
        targetAmount: '',
        completionDate: ''
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NAME_REQUIRED');
    console.log('[PASS] TC23: Thiếu nhiều thông tin -> Bắt lỗi tuần tự, ưu tiên báo lỗi tên quỹ E4');
  }
  {
    await Fund.deleteMany({ userId: owner._id });
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: { name: '[TC] Quỹ cá nhân tự do', fundType: 'Cá nhân' }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.targetAmount, 0);
    assert.strictEqual(res.data.completionDate, undefined);
    console.log('[PASS] TC24: Quỹ Cá nhân không cần số tiền và ngày -> Tạo quỹ thành công');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ cá nhân tiền âm',
        fundType: 'Cá nhân',
        targetAmount: -10000
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.targetAmount, 0);
    console.log('[PASS] TC25: Quỹ Cá nhân nhập số tiền âm -> Tự động đặt lại targetAmount = 0 và Tạo quỹ thành công');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ lớp du lịch',
        fundType: 'Hội nhóm',
        targetAmount: 10000000,
        completionDate: '2026-12-30T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.targetAmount, 10000000);
    assert.ok(res.data.completionDate);
    console.log('[PASS] TC26: Hội nhóm có nhập số tiền và ngày tùy chọn -> Lưu đúng thông tin và Tạo quỹ thành công');
  }
  {
    var req = {
      user: { id: owner._id.toString() },
      body: {
        name: '[TC] Quỹ hai người',
        fundType: 'Cặp đôi',
        partnerId: admin._id.toString() // Chọn admin
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'CANNOT_INVITE_ADMIN');
    assert.strictEqual(res.data.error, 'Không thể chọn tài khoản quản trị viên');
    console.log('[PASS] TC27: Cặp đôi đối tác không hợp lệ (admin) -> Báo lỗi E10 (CANNOT_INVITE_ADMIN)');
  }
  {
    var req = {
      user: { id: owner._id.toString(), email: owner.email, name: owner.name },
      body: {
        name: '[TC] Quỹ du lịch cuối năm',
        fundType: 'Tích lũy',
        targetAmount: 10000000,
        completionDate: '2026-12-31T00:00:00.000Z'
      }
    };
    var res = mockResponse();
    await fundController.create(req, res);
    assert.strictEqual(res.statusCode, 201);
    assert.strictEqual(res.data.name, '[TC] Quỹ du lịch cuối năm');
    assert.strictEqual(res.data.targetAmount, 10000000);
    assert.strictEqual(res.data.status, 'active');
    console.log('[PASS] TC28: Tạo quỹ Tích lũy với đầy đủ dữ liệu hợp lệ -> Tạo quỹ thành công');
  }
  await Fund.deleteMany({ name: /^\[TC\]/ });
  await FundInvitation.deleteMany({});
  await Notification.deleteMany({});
  await User.deleteMany({ email: { $in: testEmails } });
  await User.db.close();

  console.log('\n====================================================================');
  console.log('=== XUẤT SẮC! TẤT CẢ 28/28 TEST CASES TẠO QUỸ ĐỀU ĐÃ VƯỢT QUA! ===');
  console.log('====================================================================');
}

runTests().catch(function(err) {
  console.error('\n[FAIL] Kiểm thử Tạo quỹ thất bại:', err);
  process.exit(1);
});
