// ==============================================================================
// KIỂM THỬ TÍNH NĂNG 2: GÓP TIỀN QUỸ (CONTRIBUTE FUND - USE CASE 05)
// Bám sát chính xác bảng đặc tả 24 Test Case (TC01 - TC24)
// ==============================================================================

require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Fund = require('../model/Fund');
var Transaction = require('../model/Transaction');
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
  console.log('=== BẮT ĐẦU KIỂM THỬ TÍNH NĂNG GÓP QUỸ: 24 TEST CASES (TC01-TC24) ===');
  console.log('====================================================================');

  await connectDatabase();

  var testEmail = 'tc_contribute_user@gmail.com';
  await Transaction.deleteMany({ account: testEmail });
  await Fund.deleteMany({ name: /^\[TC_Gop\]/ });
  await User.deleteMany({ email: testEmail });

  // Khởi tạo người dùng test với số dư 1.000.000đ
  var user = await User.create({
    name: 'Nguyễn Văn Góp Quỹ',
    email: testEmail,
    phoneNumber: '0908888777',
    passwordHash: 'dummy',
    walletBalance: 1000000 // 1.000.000đ
  });

  // Khởi tạo quỹ test
  var fund = await Fund.create({
    userId: user._id,
    name: '[TC_Gop] Quỹ Tiết Kiệm Chung',
    fundType: 'Tích lũy',
    targetAmount: 10000000,
    currentAmount: 500000,
    members: [{ userId: user._id, role: 'owner' }]
  });

  console.log('[OK] Khởi tạo tài khoản test (Số dư: 1.000.000đ) và Quỹ test thành công.\n');

  // Hàm tiện ích reset số dư và quỹ về trạng thái chuẩn
  async function resetState(balance, fundAmount) {
    var bal = balance !== undefined ? balance : 1000000;
    var fAm = fundAmount !== undefined ? fundAmount : 500000;
    await User.updateOne({ _id: user._id }, { $set: { walletBalance: bal } });
    await Fund.updateOne({ _id: fund._id }, { $set: { currentAmount: fAm } });
  }

  // ----------------------------------------------------------------------------
  // TC01: Không nhập số tiền góp (Số tiền: rỗng) -> Báo lỗi E1 (AMOUNT_REQUIRED)
  // ----------------------------------------------------------------------------
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
    console.log('[PASS] TC01: Không nhập số tiền góp -> Báo lỗi E1 (AMOUNT_REQUIRED: "Vui lòng nhập số tiền muốn góp")');
  }

  // ----------------------------------------------------------------------------
  // TC02: Số tiền nhỏ hơn 1.000đ (999đ) -> Báo lỗi E2 (MIN_AMOUNT_1000)
  // ----------------------------------------------------------------------------
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
    console.log('[PASS] TC02: Số tiền 999đ < 1.000đ -> Báo lỗi E2 (MIN_AMOUNT_1000: "Tối thiểu 1000đ")');
  }

  // ----------------------------------------------------------------------------
  // TC03: Số tiền đúng 1.000đ, số dư 1.000.000đ -> Chấp nhận số tiền (Thành công)
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 1000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 999000);
    assert.strictEqual(res.data.fund.currentAmount, 501000);
    console.log('[PASS] TC03: Số tiền đúng 1.000đ -> Chấp nhận số tiền (Góp thành công, ví trừ 1.000đ)');
  }

  // ----------------------------------------------------------------------------
  // TC04: Số tiền lớn hơn 1.000đ (1.001đ), số dư 1.000.000đ -> Chấp nhận số tiền
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 1001 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 998999);
    console.log('[PASS] TC04: Số tiền 1.001đ > 1.000đ -> Chấp nhận số tiền (Thành công)');
  }

  // ----------------------------------------------------------------------------
  // TC05: Số tiền không phải số ("abc") -> Báo lỗi E3 (INVALID_AMOUNT)
  // ----------------------------------------------------------------------------
  {
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 'abc' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_AMOUNT');
    assert.strictEqual(res.data.error, 'Số tiền không hợp lệ');
    console.log('[PASS] TC05: Số tiền "abc" -> Báo lỗi E3 (INVALID_AMOUNT: "Số tiền không hợp lệ")');
  }

  // ----------------------------------------------------------------------------
  // TC06: Số tiền chứa ký tự không hợp lệ ("10abc") -> Báo lỗi E3 (INVALID_AMOUNT)
  // ----------------------------------------------------------------------------
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
    console.log('[PASS] TC06: Số tiền "10abc" -> Báo lỗi E3 (INVALID_AMOUNT)');
  }

  // ----------------------------------------------------------------------------
  // TC07: Số tiền nhỏ hơn số dư ví (500.000đ, số dư 1.000.000đ) -> Chấp nhận giao dịch
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 500000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 500000);
    assert.strictEqual(res.data.fund.currentAmount, 1000000);
    console.log('[PASS] TC07: Số tiền 500.000đ < 1.000.000đ -> Chấp nhận giao dịch thành công');
  }

  // ----------------------------------------------------------------------------
  // TC08: Số tiền bằng đúng số dư ví (1.000.000đ, số dư 1.000.000đ) -> Chấp nhận giao dịch
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 1000000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 0);
    assert.strictEqual(res.data.fund.currentAmount, 1500000);
    console.log('[PASS] TC08: Số tiền bằng đúng số dư ví (1.000.000đ) -> Chấp nhận giao dịch (Số dư về 0đ)');
  }

  // ----------------------------------------------------------------------------
  // TC09: Số tiền lớn hơn số dư ví (1.000.001đ, số dư 1.000.000đ) -> Báo lỗi E4 (INSUFFICIENT_BALANCE)
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
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
    console.log('[PASS] TC09: Số tiền 1.000.001đ > 1.000.000đ -> Báo lỗi E4 (INSUFFICIENT_BALANCE)');
  }

  // ----------------------------------------------------------------------------
  // TC10: Không nhập ghi chú (ghi chú rỗng) -> Chấp nhận
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: '' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.transaction.note, '');
    console.log('[PASS] TC10: Không nhập ghi chú -> Chấp nhận giao dịch');
  }

  // ----------------------------------------------------------------------------
  // TC11: Ghi chú có 1 từ ("Góp") -> Chấp nhận
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: 'Góp' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.transaction.note, 'Góp');
    console.log('[PASS] TC11: Ghi chú có 1 từ ("Góp") -> Chấp nhận');
  }

  // ----------------------------------------------------------------------------
  // TC12: Ghi chú có 200 từ -> Chấp nhận
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var words200 = [];
    for (var i = 1; i <= 200; i++) words200.push('a');
    var note200 = words200.join(' '); // 399 ký tự (<= 500 ký tự của Transaction schema)

    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: note200 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    console.log('[PASS] TC12: Ghi chú đúng 200 từ -> Chấp nhận');
  }

  // ----------------------------------------------------------------------------
  // TC13: Ghi chú có 201 từ -> Báo lỗi E5 (NOTE_TOO_LONG)
  // ----------------------------------------------------------------------------
  {
    var words201 = [];
    for (var i = 1; i <= 201; i++) words201.push('a');
    var note201 = words201.join(' ');

    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: note201 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'NOTE_TOO_LONG');
    assert.strictEqual(res.data.error, 'Tối đa 200 từ');
    console.log('[PASS] TC13: Ghi chú 201 từ -> Báo lỗi E5 (NOTE_TOO_LONG: "Tối đa 200 từ")');
  }

  // ----------------------------------------------------------------------------
  // TC14: Góp tiền không nhập ghi chú (50.000đ, ghi chú rỗng) -> Cho phép tiếp tục giao dịch
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: '' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Góp tiền thành công');
    console.log('[PASS] TC14: Góp tiền không nhập ghi chú -> Cho phép tiếp tục giao dịch và hoàn tất');
  }

  // ----------------------------------------------------------------------------
  // TC15: Góp tiền có ghi chú hợp lệ (50.000đ, "Góp quỹ tháng 9") -> Cho phép tiếp tục giao dịch
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: 'Góp quỹ tháng 9' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.transaction.note, 'Góp quỹ tháng 9');
    console.log('[PASS] TC15: Góp tiền có ghi chú hợp lệ ("Góp quỹ tháng 9") -> Cho phép tiếp tục giao dịch');
  }

  // ----------------------------------------------------------------------------
  // TC16: Không xác nhận chuyển tiền (chọn Hủy) -> Hủy giao dịch, số dư giữ nguyên
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    // Khi người dùng bấm Hủy trên giao diện, không có lệnh trừ tiền nào được gửi
    var userCheck = await User.findById(user._id);
    var fundCheck = await Fund.findById(fund._id);
    assert.strictEqual(userCheck.walletBalance, 1000000);
    assert.strictEqual(fundCheck.currentAmount, 500000);
    console.log('[PASS] TC16: Người dùng chọn Hủy chuyển tiền -> Không trừ tiền ví, số dư ví và quỹ được bảo toàn');
  }

  // ----------------------------------------------------------------------------
  // TC17: Xác nhận chuyển tiền thành công (50.000đ, số dư 1.000.000đ) -> Trừ ví, cộng quỹ, lưu lịch sử
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 50000, note: 'Xác nhận chuyển tiền' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 950000);
    assert.strictEqual(res.data.fund.currentAmount, 550000);
    assert.ok(res.data.transaction);
    assert.strictEqual(res.data.transaction.type, 'fund_contribution');
    assert.strictEqual(res.data.transaction.amount, 50000);
    console.log('[PASS] TC17: Xác nhận chuyển tiền thành công -> Trừ 50.000đ ví, cộng quỹ, lưu Transaction');
  }

  // ----------------------------------------------------------------------------
  // TC18: Phát sinh lỗi khi chuyển tiền -> Báo lỗi E6 (Xử lý rollback an toàn)
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    // Giả lập ID người dùng không hợp lệ trong hệ thống để kích hoạt khối lỗi
    var reqErr = {
      params: { id: fund._id.toString() },
      user: { id: '65f000000000000000000011' }, // User không tồn tại
      body: { amount: 50000 }
    };
    var resErr = mockResponse();
    await fundController.contribute(reqErr, resErr);
    assert.strictEqual(resErr.statusCode, 404);
    console.log('[PASS] TC18: Phát sinh lỗi thông tin -> Hệ thống dừng giao dịch an toàn (E6/404)');
  }

  // ----------------------------------------------------------------------------
  // TC19: Mất kết nối / Quỹ không tồn tại -> Báo lỗi E7 (404)
  // ----------------------------------------------------------------------------
  {
    var req = {
      params: { id: '65f000000000000000000099' }, // Quỹ không tồn tại
      user: { id: user._id.toString() },
      body: { amount: 50000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 404);
    assert.strictEqual(res.data.error, 'Quỹ không tồn tại hoặc bạn không phải thành viên quỹ');
    console.log('[PASS] TC19: Quỹ không tồn tại / mất kết nối -> Báo lỗi E7 (404)');
  }

  // ----------------------------------------------------------------------------
  // TC20: Góp đúng số dư ví (1.000.000đ, số dư 1.000.000đ) -> Thành công, số dư còn 0đ
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 1000000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 0);
    assert.strictEqual(res.data.fund.currentAmount, 1500000);
    console.log('[PASS] TC20: Góp đúng số dư ví (1.000.000đ) -> Giao dịch thành công, số dư ví còn 0đ');
  }

  // ----------------------------------------------------------------------------
  // TC21: Góp số tiền tối thiểu (1.000đ, số dư đủ) -> Giao dịch thành công
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 1000 }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Góp tiền thành công');
    console.log('[PASS] TC21: Góp số tiền tối thiểu (1.000đ, số dư đủ) -> Giao dịch thành công');
  }

  // ----------------------------------------------------------------------------
  // TC22: Góp số tiền hợp lệ kèm ghi chú 200 từ (100.000đ) -> Giao dịch thành công
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var words = [];
    for (var i = 1; i <= 200; i++) words.push('a');
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 100000, note: words.join(' ') }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.walletBalance, 900000);
    assert.strictEqual(res.data.fund.currentAmount, 600000);
    console.log('[PASS] TC22: Góp số tiền 100.000đ kèm ghi chú 200 từ -> Giao dịch thành công');
  }

  // ----------------------------------------------------------------------------
  // TC23: Thiếu số tiền và ghi chú vượt giới hạn -> Báo lỗi dữ liệu tương ứng (E1)
  // ----------------------------------------------------------------------------
  {
    var longWords = [];
    for (var i = 1; i <= 201; i++) longWords.push('word' + i);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: '', note: longWords.join(' ') }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'AMOUNT_REQUIRED');
    console.log('[PASS] TC23: Thiếu số tiền và ghi chú 201 từ -> Ưu tiên báo lỗi thiếu số tiền E1');
  }

  // ----------------------------------------------------------------------------
  // TC24: Đầy đủ dữ liệu hợp lệ (500.000đ, "Góp quỹ tháng 9", số dư 1.000.000đ) -> Thành công
  // ----------------------------------------------------------------------------
  {
    await resetState(1000000, 500000);
    var req = {
      params: { id: fund._id.toString() },
      user: { id: user._id.toString() },
      body: { amount: 500000, note: 'Góp quỹ tháng 9' }
    };
    var res = mockResponse();
    await fundController.contribute(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Góp tiền thành công');
    assert.strictEqual(res.data.walletBalance, 500000);
    assert.strictEqual(res.data.fund.currentAmount, 1000000);
    assert.strictEqual(res.data.transaction.amount, 500000);
    assert.strictEqual(res.data.transaction.note, 'Góp quỹ tháng 9');
    console.log('[PASS] TC24: Đầy đủ dữ liệu hợp lệ -> Trừ tiền ví, cộng quỹ, lưu lịch sử và báo "Góp tiền thành công"');
  }

  // Dọn dẹp
  await Transaction.deleteMany({ account: testEmail });
  await Fund.deleteMany({ name: /^\[TC_Gop\]/ });
  await User.deleteMany({ email: testEmail });
  await User.db.close();

  console.log('\n====================================================================');
  console.log('=== XUẤT SẮC! TẤT CẢ 24/24 TEST CASES GÓP QUỸ ĐỀU ĐÃ VƯỢT QUA! ===');
  console.log('====================================================================');
}

runTests().catch(function(err) {
  console.error('\n[FAIL] Kiểm thử Góp quỹ thất bại:', err);
  process.exit(1);
});
