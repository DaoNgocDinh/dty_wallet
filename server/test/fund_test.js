// Unit / Integration test cho API Quỹ (Xem chi tiết quỹ & Góp tiền vào quỹ - Use Case 05)
require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Fund = require('../model/Fund');
var Transaction = require('../model/Transaction');
var fundController = require('../controller/fundController');

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
  console.log('--- Bắt đầu kiểm thử Backend Use Case 05: Góp tiền vào quỹ & Chi tiết quỹ ---');
  await connectDatabase();

  // Tạo người dùng test
  var user = await User.findOne({ email: 'test_contribute@gmail.com' });
  if (user) {
    await User.deleteOne({ _id: user._id });
  }
  user = await User.create({
    name: 'Test Contributor',
    email: 'test_contribute@gmail.com',
    passwordHash: 'dummy',
    walletBalance: 1000000 // 1.000.000đ
  });

  // Tạo quỹ test
  var fund = await Fund.create({
    userId: user._id,
    name: 'Quỹ Du Lịch Hè',
    fundType: 'Tích lũy',
    targetAmount: 5000000,
    currentAmount: 500000
  });

  console.log('[OK] Khởi tạo dữ liệu người dùng test (Số dư: 1.000.000đ) và Quỹ test');

  // Test 1: Xem chi tiết quỹ thành công
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() }
    };
    var res = mockResponse();
    await fundController.details(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.fund.name, 'Quỹ Du Lịch Hè');
    assert.strictEqual(res.data.fund.currentAmount, 500000);
    assert(Array.isArray(res.data.transactions));
    console.log('[PASS] Test 1: GET /funds/:id - Xem chi tiết quỹ thành công');
  }

  // Test 2: Xem chi tiết quỹ không tồn tại -> 404
  {
    var req = {
      params: { id: '65f000000000000000000099' },
      user: { id: user._id.toString() }
    };
    var res = mockResponse();
    await fundController.details(req, res);
    assert.strictEqual(res.statusCode, 404);
    assert.strictEqual(res.data.error, 'Quỹ không tồn tại hoặc bạn không có quyền xem quỹ này');
    console.log('[PASS] Test 2: GET /funds/:id - Quỹ không tồn tại trả về 404');
  }

  // Test 3: E1: Để trống số tiền góp -> 400 "Vui lòng nhập số tiền muốn góp"
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: '' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'AMOUNT_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng nhập số tiền muốn góp');
    console.log('[PASS] Test 3: E1 - Để trống số tiền góp trả về lỗi "Vui lòng nhập số tiền muốn góp"');
  }

  // Test 4: E2 & Giá trị biên: Nhập số tiền < 1.000đ (999đ) -> 400 "Tối thiểu 1000đ"
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 999 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'MIN_AMOUNT_1000');
    assert.strictEqual(res.data.error, 'Tối thiểu 1000đ');
    console.log('[PASS] Test 4: E2 - Số tiền 999đ < 1.000đ trả về lỗi "Tối thiểu 1000đ"');
  }

  // Test 5: E3: Số tiền không hợp lệ ("abc", "10abc") -> 400 "Số tiền không hợp lệ"
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: '10abc' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_AMOUNT');
    assert.strictEqual(res.data.error, 'Số tiền không hợp lệ');
    console.log('[PASS] Test 5: E3 - Số tiền không phải số trả về lỗi "Số tiền không hợp lệ"');
  }

  // Test 6: E4 & Giá trị biên: Số tiền lớn hơn số dư khả dụng (1.000.001đ > 1.000.000đ) -> 400
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 1000001 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INSUFFICIENT_BALANCE');
    assert.strictEqual(res.data.error, 'Số dư ví không đủ để thực hiện giao dịch');
    console.log('[PASS] Test 6: E4 - Số tiền vượt quá số dư trả về "Số dư ví không đủ để thực hiện giao dịch"');
  }

  // Test 7: E5: Ghi chú quá 200 từ -> 400 "Tối đa 200 từ"
  {
    var longWords = [];
    for (var i = 0; i < 201; i++) longWords.push('tu' + i);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: longWords.join(' ') }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'NOTE_TOO_LONG');
    assert.strictEqual(res.data.error, 'Tối đa 200 từ');
    console.log('[PASS] Test 7: E5 - Ghi chú 201 từ trả về lỗi "Tối đa 200 từ"');
  }

  // Test 8: Luồng thành công Miền 1: Góp 50.000đ với ghi chú 1-200 từ
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: 'Góp tiền tháng 9' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Góp tiền thành công');
    assert.strictEqual(res.data.walletBalance, 950000); // 1.000.000 - 50.000 = 950.000
    assert.strictEqual(res.data.fund.currentAmount, 550000); // 500.000 + 50.000 = 550.000
    assert(res.data.transaction);
    assert.strictEqual(res.data.transaction.type, 'fund_contribution');
    assert.strictEqual(res.data.transaction.amount, 50000);
    assert.strictEqual(res.data.transaction.note, 'Góp tiền tháng 9');
    console.log('[PASS] Test 8: Thành công - Góp 50.000đ, số dư ví trừ 50.000đ, quỹ tăng 50.000đ, tạo giao dịch');
  }

  // Test 9: Giá trị biên: Góp đúng bằng số dư khả dụng còn lại (950.000đ)
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 950000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 0); // Về 0đ
    assert.strictEqual(res.data.fund.currentAmount, 1500000); // 550.000 + 950.000 = 1.500.000
    console.log('[PASS] Test 9: Giá trị biên - Góp toàn bộ số dư còn lại (950.000đ) thành công, số dư về 0đ');
  }

  // Test 10: Xem chi tiết quỹ sau khi góp có danh sách giao dịch
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() }
    };
    var res = mockResponse();
    await fundController.details(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.fund.currentAmount, 1500000);
    assert.strictEqual(res.data.transactions.length, 2);
    console.log('[PASS] Test 10: Xem chi tiết quỹ sau khi góp hiển thị 2 giao dịch đóng góp');
  }

  // Dọn dẹp dữ liệu test
  await Transaction.deleteMany({ userId: user._id });
  await Fund.deleteOne({ _id: fund._id });
  await User.deleteOne({ _id: user._id });
  await User.db.close();

  console.log('--- TẤT CẢ CÁC BÀI TEST BACKEND ĐÃ VƯỢT QUA THÀNH CÔNG (10/10) ---');
}

runTests().catch(function(err) {
  console.error('Test thất bại:', err);
  process.exit(1);
});
