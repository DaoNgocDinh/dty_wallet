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

async function call(user, source, amount) {
  var res = mockResponse();
  await walletController.demoDeposit({
    user: { id: user.id, email: user.email },
    body: { source: source, amount: amount }
  }, res);
  return res;
}

async function balance(user) {
  return (await User.findById(user.id)).walletBalance;
}

async function expectInvalid(user, source, amount, message) {
  var before = await balance(user);
  var res = await call(user, source, amount);
  assert.strictEqual(res.statusCode, 400);
  if (message) assert.strictEqual(res.data.error, message);
  assert.strictEqual(await balance(user), before);
}

async function runCase(number, title, test, failures) {
  try {
    await test();
    console.log('[PASS] TC' + number + ' ' + title);
  } catch (error) {
    failures.push({ number: number, title: title, error: error });
    console.error('[FAIL] TC' + number + ' ' + title + ': ' + error.message);
  }
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
  var originalTransactionCreate = Transaction.create;
  var failures = [];

  try {
    process.env.DEMO_DEPOSITS_ENABLED = 'true';

    await runCase('01', 'Nạp Vietcombank thành công', async function() {
      var res = await call(user, 'Vietcombank', 500000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.sender, 'Vietcombank');
      assert.strictEqual(res.data.transaction.amount, 500000);
      assert.strictEqual(res.data.walletBalance, 1000000);
      assert.strictEqual(await balance(user), 1000000);
    }, failures);

    await runCase('02', 'Nạp MB Bank và lưu đúng nguồn', async function() {
      var res = await call(user, 'MB Bank', 500000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.sender, 'MB Bank');
    }, failures);

    await runCase('03', 'Nạp thẻ quốc tế mô phỏng', async function() {
      var res = await call(user, 'Thẻ quốc tế', 500000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.sender, 'Thẻ quốc tế');
    }, failures);

    await runCase('04', 'Từ chối khi chưa chọn nguồn nạp', async function() {
      var before = await balance(user);
      var res = await call(user, '   ', 500000);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(await balance(user), before);
    }, failures);

    await runCase('05', 'Bỏ trống số tiền trả thông báo hợp lệ', async function() {
      var before = await balance(user);
      var res = await call(user, 'Vietcombank', '');
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Vui lòng nhập số tiền hợp lệ');
      assert.strictEqual(await balance(user), before);
    }, failures);

    await runCase('06', 'Từ chối số tiền bằng 0', async function() {
      await expectInvalid(user, 'Vietcombank', 0);
    }, failures);

    await runCase('07', 'Từ chối số tiền âm', async function() {
      await expectInvalid(user, 'Vietcombank', -1000);
    }, failures);

    await runCase('08', 'Từ chối số tiền là chữ', async function() {
      await expectInvalid(user, 'Vietcombank', 'abc');
    }, failures);

    await runCase('09', 'Từ chối số tiền thập phân', async function() {
      await expectInvalid(user, 'Vietcombank', 1.5);
    }, failures);

    await runCase('10', 'Chấp nhận số tiền nhỏ nhất hợp lệ', async function() {
      var res = await call(user, 'Vietcombank', '1');
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.amount, 1);
    }, failures);

    await runCase('11', 'Chấp nhận số tiền nguyên dương', async function() {
      var res = await call(user, 'Vietcombank', 2);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.amount, 2);
    }, failures);

    await runCase('12', 'Chuẩn hóa số tiền có dấu chấm phân cách', async function() {
      var res = await call(user, 'Vietcombank', '1.000.000');
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.amount, 1000000);
    }, failures);

    await runCase('13', 'Chuẩn hóa số tiền có dấu phẩy phân cách', async function() {
      var res = await call(user, 'Vietcombank', '1,000,000');
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.transaction.amount, 1000000);
    }, failures);

    await runCase('14', 'Từ chối định dạng số tiền sai', async function() {
      await expectInvalid(user, 'Vietcombank', '1.2.3');
    }, failures);

    process.env.DEMO_DEPOSITS_ENABLED = 'false';
    await runCase('15', 'Từ chối khi chế độ demo bị tắt', async function() {
      var before = await balance(user);
      var res = await call(user, 'Vietcombank', 500000);
      assert.strictEqual(res.statusCode, 403);
      assert.strictEqual(res.data.error, 'Nạp tiền demo hiện chưa được bật');
      assert.strictEqual(await balance(user), before);
    }, failures);

    delete process.env.DEMO_DEPOSITS_ENABLED;
    await runCase('16', 'Từ chối khi chưa cấu hình chế độ demo', async function() {
      var before = await balance(user);
      var res = await call(user, 'Vietcombank', 500000);
      assert.strictEqual(res.statusCode, 403);
      assert.strictEqual(res.data.error, 'Nạp tiền demo hiện chưa được bật');
      assert.strictEqual(await balance(user), before);
    }, failures);

    process.env.DEMO_DEPOSITS_ENABLED = 'true';
    await User.updateOne({ _id: user.id }, { $set: { walletBalance: 1000000 } });
    await runCase('17', 'Cộng chính xác số tiền vào số dư ví', async function() {
      var res = await call(user, 'Vietcombank', 500000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.walletBalance, 1500000);
      assert.strictEqual(await balance(user), 1500000);
    }, failures);

    await runCase('18', 'Mã giao dịch đúng dạng TX-<UUID>', async function() {
      var res = await call(user, 'Vietcombank', 10);
      assert.match(res.data.transaction.transactionCode, /^TX-[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
    }, failures);

    await runCase('19', 'Lưu đúng loại giao dịch', async function() {
      var res = await call(user, 'Vietcombank', 11);
      assert.strictEqual(res.data.transaction.type, 'wallet_deposit');
    }, failures);

    await runCase('20', 'Lưu đúng trạng thái giao dịch', async function() {
      var res = await call(user, 'Vietcombank', 12);
      assert.strictEqual(res.data.transaction.status, 'completed');
    }, failures);

    await runCase('21', 'Lưu thời gian giao dịch hợp lệ', async function() {
      var res = await call(user, 'Vietcombank', 13);
      assert.ok(res.data.transaction.createdAt);
      assert.ok(Number.isFinite(new Date(res.data.transaction.createdAt).getTime()));
    }, failures);

    await runCase('22', 'Trả thông báo nạp tiền thành công', async function() {
      var res = await call(user, 'Vietcombank', 14);
      assert.strictEqual(res.data.message, 'Nạp tiền demo thành công');
    }, failures);

    await runCase('23', 'Hoàn tiền khi lưu giao dịch thất bại', async function() {
      var beforeFailure = await balance(user);
      var transactionCount = await Transaction.countDocuments({ userId: user.id });
      Transaction.create = async function() {
        throw new Error('Simulated transaction persistence failure');
      };
      try {
        await assert.rejects(call(user, 'Vietcombank', 500000), /Simulated transaction persistence failure/);
      } finally {
        Transaction.create = originalTransactionCreate;
      }
      assert.strictEqual(await balance(user), beforeFailure);
      assert.strictEqual(await Transaction.countDocuments({ userId: user.id }), transactionCount);
    }, failures);
  } finally {
    Transaction.create = originalTransactionCreate;
    if (previousFlag === undefined) {
      delete process.env.DEMO_DEPOSITS_ENABLED;
    } else {
      process.env.DEMO_DEPOSITS_ENABLED = previousFlag;
    }
    await Transaction.deleteMany({ userId: user._id });
    await User.deleteOne({ _id: user._id });
    await User.db.close();
  }

  console.log('=== Kết quả: ' + (23 - failures.length) + '/23 test case đạt ===');
  if (failures.length) {
    throw new Error(failures.length + ' test case thất bại theo yêu cầu hiện tại');
  }
}

runTests().catch(function(error) {
  console.error('Test thất bại:', error);
  process.exit(1);
});
