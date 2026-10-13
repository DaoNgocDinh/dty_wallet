// Unit / Integration test riêng cho tính năng RÚT TIỀN từ quỹ (chỉ chủ quỹ)
// và quy tắc chỉ được xoá quỹ khi số dư quỹ còn 0đ
require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Fund = require('../model/Fund');
var Transaction = require('../model/Transaction');
var FundInvitation = require('../model/FundInvitation');
var Notification = require('../model/Notification');
var fundController = require('../controller/fundController');

var TEST_EMAILS = [
  'withdraw_owner@gmail.com',
  'withdraw_member@gmail.com',
  'withdraw_outsider@gmail.com'
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
  console.log('=== Bắt đầu kiểm thử tính năng Rút tiền từ quỹ ===');
  await connectDatabase();

  // Dọn dẹp dữ liệu cũ nếu có
  await User.deleteMany({ email: { $in: TEST_EMAILS } });
  await Fund.deleteMany({ name: { $regex: '^Quỹ Test Rút Tiền' } });
  await Transaction.deleteMany({ account: { $in: TEST_EMAILS } });

  // Khởi tạo dữ liệu test
  var owner = await User.create({
    name: 'Chủ Quỹ Rút Tiền',
    email: 'withdraw_owner@gmail.com',
    phoneNumber: '0900000001',
    passwordHash: 'dummy',
    walletBalance: 500000 // 500.000đ
  });

  var member = await User.create({
    name: 'Thành Viên Rút Tiền',
    email: 'withdraw_member@gmail.com',
    phoneNumber: '0900000002',
    passwordHash: 'dummy',
    walletBalance: 200000
  });

  var outsider = await User.create({
    name: 'Người Ngoài Rút Tiền',
    email: 'withdraw_outsider@gmail.com',
    phoneNumber: '0900000003',
    passwordHash: 'dummy',
    walletBalance: 100000
  });

  var fund = await Fund.create({
    userId: owner._id,
    name: 'Quỹ Test Rút Tiền Cặp Đôi',
    fundType: 'Cặp đôi',
    status: 'active',
    targetAmount: 0,
    currentAmount: 2000000, // 2.000.000đ
    members: [
      { userId: owner._id, role: 'owner', joinedAt: new Date() },
      { userId: member._id, role: 'member', joinedAt: new Date() }
    ]
  });

  console.log('[OK] Khởi tạo dữ liệu test (Chủ quỹ số dư 500.000đ, quỹ có 2.000.000đ)');

  // Test 1: Rút tiền thành công 500.000đ
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 500000, note: 'Rút tiền chi phí gia đình' }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Rút tiền thành công');
    assert.strictEqual(res.data.fund.currentAmount, 1500000); // 2.000.000 - 500.000
    assert.strictEqual(res.data.walletBalance, 1000000); // 500.000 + 500.000
    assert.strictEqual(res.data.transaction.type, 'fund_withdrawal');
    assert.strictEqual(res.data.transaction.amount, 500000);
    assert.strictEqual(res.data.transaction.note, 'Rút tiền chi phí gia đình');
    assert.strictEqual(res.data.transaction.status, 'completed');
    assert(String(res.data.transaction.transactionCode).indexOf('TX-') === 0);

    var ownerAfter = await User.findById(owner._id);
    assert.strictEqual(ownerAfter.walletBalance, 1000000);
    console.log('[PASS] Test 1: Chủ quỹ rút 500.000đ - quỹ còn 1.500.000đ, ví tăng lên 1.000.000đ, tạo giao dịch fund_withdrawal');
  }

  // Test 2: Để trống số tiền rút -> 400 AMOUNT_REQUIRED
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: '' }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'AMOUNT_REQUIRED');
    assert.strictEqual(res.data.error, 'Vui lòng nhập số tiền muốn rút');
    console.log('[PASS] Test 2: E1 - Để trống số tiền rút trả về "Vui lòng nhập số tiền muốn rút"');
  }

  // Test 3: Số tiền không hợp lệ -> 400 INVALID_AMOUNT
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: '100abc' }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_AMOUNT');
    assert.strictEqual(res.data.error, 'Số tiền không hợp lệ');
    console.log('[PASS] Test 3: E2 - Số tiền không phải số trả về "Số tiền không hợp lệ"');
  }

  // Test 4: Giá trị biên - Rút 999đ (< 1.000đ) -> 400 MIN_AMOUNT_1000
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 999 }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'MIN_AMOUNT_1000');
    assert.strictEqual(res.data.error, 'Tối thiểu 1000đ');
    console.log('[PASS] Test 4: E3 - Rút 999đ < 1.000đ trả về "Tối thiểu 1000đ"');
  }

  // Test 5: Số tiền lớn hơn số dư quỹ (1.500.001đ > 1.500.000đ) -> 400 INSUFFICIENT_FUND_BALANCE
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 1500001 }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INSUFFICIENT_FUND_BALANCE');
    assert.strictEqual(res.data.error, 'Số dư quỹ không đủ để rút');
    assert.strictEqual(res.data.currentAmount, 1500000);
    console.log('[PASS] Test 5: E4 - Số tiền vượt quá số dư quỹ trả về "Số dư quỹ không đủ để rút"');
  }

  // Test 6: Thành viên quỹ (không phải chủ quỹ) rút tiền -> 403 NOT_FUND_OWNER
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: member._id.toString() },
      body: { amount: 100000 }
    });
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(res.data.code, 'NOT_FUND_OWNER');
    assert.strictEqual(res.data.error, 'Chỉ chủ quỹ mới được rút tiền');

    var fundAfter = await Fund.findById(fund._id);
    assert.strictEqual(fundAfter.currentAmount, 1500000);
    console.log('[PASS] Test 6: Thành viên quỹ rút tiền bị từ chối, số dư quỹ không thay đổi');
  }

  // Test 7: Người ngoài quỹ rút tiền -> 403 NOT_FUND_OWNER
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: outsider._id.toString() },
      body: { amount: 100000 }
    });
    assert.strictEqual(res.statusCode, 403);
    assert.strictEqual(res.data.code, 'NOT_FUND_OWNER');
    console.log('[PASS] Test 7: Người ngoài quỹ rút tiền bị từ chối');
  }

  // Test 8: Quỹ không tồn tại -> 404 FUND_NOT_FOUND
  {
    var res = await call(fundController.withdraw, {
      params: { id: '65f000000000000000000099' },
      user: { id: owner._id.toString() },
      body: { amount: 100000 }
    });
    assert.strictEqual(res.statusCode, 404);
    assert.strictEqual(res.data.code, 'FUND_NOT_FOUND');
    console.log('[PASS] Test 8: Rút tiền từ quỹ không tồn tại trả về 404');
  }

  // Test 9: Ghi chú quá 200 từ -> 400 NOTE_TOO_LONG
  {
    var longWords = [];
    for (var i = 0; i < 201; i++) longWords.push('tu' + i);
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 100000, note: longWords.join(' ') }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'NOTE_TOO_LONG');
    assert.strictEqual(res.data.error, 'Tối đa 200 từ');
    console.log('[PASS] Test 9: E5 - Ghi chú 201 từ trả về "Tối đa 200 từ"');
  }

  // Test 10: Rút toàn bộ số dư quỹ (giá trị biên 1.500.000đ) -> thành công, quỹ về 0đ
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 1500000 }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.fund.currentAmount, 0);
    assert.strictEqual(res.data.walletBalance, 2500000); // 1.000.000 + 1.500.000
    console.log('[PASS] Test 10: Giá trị biên - Rút toàn bộ số dư quỹ thành công, quỹ về 0đ');
  }

  // Test 11: Quỹ đã về 0đ thì không rút được nữa -> 400 INSUFFICIENT_FUND_BALANCE
  {
    var res = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 1000 }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INSUFFICIENT_FUND_BALANCE');
    assert.strictEqual(res.data.currentAmount, 0);
    console.log('[PASS] Test 11: Quỹ về 0đ không thể rút tiếp');
  }

  // Test 12: Chi tiết quỹ hiển thị đầy đủ giao dịch rút tiền
  {
    var res = await call(fundController.details, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.fund.currentAmount, 0);
    assert.strictEqual(res.data.fund.isOwner, true);
    assert.strictEqual(res.data.fund.canWithdraw, false);
    assert.strictEqual(res.data.fund.canDelete, true);
    assert.strictEqual(res.data.transactions.length, 2);
    assert.strictEqual(res.data.transactions[0].type, 'fund_withdrawal');
    assert.strictEqual(res.data.transactions[1].type, 'fund_withdrawal');
    console.log('[PASS] Test 12: Chi tiết quỹ hiển thị 2 giao dịch rút tiền và cờ quyền (canDelete = true)');
  }

  // Test 13: Xoá quỹ khi số dư quỹ khác 0 -> 400 FUND_NOT_EMPTY
  {
    await Fund.updateOne({ _id: fund._id }, { $inc: { currentAmount: 300000 } });

    var res = await call(fundController.delete, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() }
    });
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'FUND_NOT_EMPTY');
    assert.strictEqual(res.data.error, 'Chỉ được xoá quỹ khi số dư quỹ bằng 0');
    assert.strictEqual(res.data.currentAmount, 300000);

    var stillExists = await Fund.findById(fund._id);
    assert(stillExists !== null);
    console.log('[PASS] Test 13: Quỹ còn 300.000đ không được xoá, trả về "Chỉ được xoá quỹ khi số dư quỹ bằng 0"');
  }

  // Test 14: Thành viên xem chi tiết quỹ thì không có quyền xoá / rút
  {
    var res = await call(fundController.details, {
      params: { id: fund._id.toString() },
      user: { id: member._id.toString() }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.fund.isOwner, false);
    assert.strictEqual(res.data.fund.canWithdraw, false);
    assert.strictEqual(res.data.fund.canDelete, false);
    console.log('[PASS] Test 14: Thành viên không có quyền rút tiền / xoá quỹ');
  }

  // Test 15: Chủ quỹ rút hết số dư rồi xoá quỹ thành công
  {
    var resWithdraw = await call(fundController.withdraw, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() },
      body: { amount: 300000 }
    });
    assert.strictEqual(resWithdraw.statusCode, 200);
    assert.strictEqual(resWithdraw.data.fund.currentAmount, 0);

    var res = await call(fundController.delete, {
      params: { id: fund._id.toString() },
      user: { id: owner._id.toString() }
    });
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.message, 'Xoá quỹ thành công');

    var deletedFund = await Fund.findById(fund._id);
    assert.strictEqual(deletedFund, null);
    console.log('[PASS] Test 15: Rút hết tiền (quỹ về 0đ) rồi xoá quỹ thành công');
  }

  // Dọn dẹp dữ liệu test
  await Transaction.deleteMany({ userId: { $in: [owner._id, member._id, outsider._id] } });
  await FundInvitation.deleteMany({ fundId: fund._id });
  await Notification.deleteMany({ userId: { $in: [owner._id, member._id, outsider._id] } });
  await User.deleteMany({ _id: { $in: [owner._id, member._id, outsider._id] } });
  await User.db.close();

  console.log('--- TẤT CẢ CÁC BÀI TEST RÚT TIỀN ĐÃ VƯỢT QUA THÀNH CÔNG (15/15) ---');
}

runTests().catch(function(err) {
  console.error('Test thất bại:', err);
  process.exit(1);
});