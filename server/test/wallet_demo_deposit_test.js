require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var walletController = require('../controller/walletController');

var TEST_EMAIL = 'wallet_demo_deposit_test@gmail.com';

function mockResponse() {
  return {
    statusCode: 200,
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

async function call(req) {
  var res = mockResponse();
  await walletController.demoDeposit(req, res);
  return res;
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử nạp tiền demo vào ví ===');
  await connectDatabase();

  var previousUser = await User.findOne({ email: TEST_EMAIL });
  if (previousUser) {
    await Transaction.deleteMany({ userId: previousUser._id });
    await User.deleteOne({ _id: previousUser._id });
  }

  var user = await User.create({
    name: 'Kiểm thử nạp demo',
    email: TEST_EMAIL,
    passwordHash: 'dummy',
    walletBalance: 500000
  });
  var previousFlag = process.env.DEMO_DEPOSITS_ENABLED;

  try {
    process.env.DEMO_DEPOSITS_ENABLED = 'false';
    var disabled = await call({
      user: { id: user.id, email: user.email },
      body: { source: 'Ngân hàng demo', amount: 100000 }
    });
    assert.strictEqual(disabled.statusCode, 403);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 500000);
    console.log('[PASS] Từ chối nạp demo khi chưa bật cấu hình');

    process.env.DEMO_DEPOSITS_ENABLED = 'true';
    var invalid = await call({
      user: { id: user.id, email: user.email },
      body: { source: 'Ngân hàng demo', amount: 0 }
    });
    assert.strictEqual(invalid.statusCode, 400);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 500000);
    console.log('[PASS] Số tiền không hợp lệ không làm thay đổi số dư');

    var success = await call({
      user: { id: user.id, email: user.email },
      body: { source: 'Ngân hàng demo', amount: 100000 }
    });
    assert.strictEqual(success.statusCode, 201);
    assert.strictEqual(success.data.walletBalance, 600000);
    assert.strictEqual(success.data.transaction.status, 'completed');
    assert.strictEqual(success.data.transaction.metadata.demo, true);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 600000);
    assert.strictEqual(await Transaction.countDocuments({
      userId: user.id,
      type: 'wallet_deposit',
      status: 'completed'
    }), 1);
    console.log('[PASS] Nạp demo cộng số dư và ghi một giao dịch hoàn tất');
  } finally {
    if (previousFlag === undefined) {
      delete process.env.DEMO_DEPOSITS_ENABLED;
    } else {
      process.env.DEMO_DEPOSITS_ENABLED = previousFlag;
    }
    await Transaction.deleteMany({ userId: user._id });
    await User.deleteOne({ _id: user._id });
    await User.db.close();
  }

  console.log('=== Tất cả kiểm thử nạp demo đã vượt qua ===');
}

runTests().catch(function(error) {
  console.error('Test thất bại:', error);
  process.exit(1);
});
