require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var SpendingJar = require('../model/SpendingJar');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var spendingJarController = require('../controller/spendingJarController');

var TEST_EMAIL = 'spending_jar_create_test@gmail.com';
var INITIAL_BALANCE = 5000000;

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

async function call(user, name, amount) {
  var res = mockResponse();
  await spendingJarController.create({
    user: { id: user.id },
    body: { name: name, amount: amount }
  }, res);
  return res;
}

async function resetUserData(user) {
  await SpendingJar.deleteMany({ userId: user.id });
  await Transaction.deleteMany({ userId: user.id });
  await User.updateOne({ _id: user.id }, { $set: { walletBalance: INITIAL_BALANCE } });
}

async function runCase(number, title, user, test, failures) {
  try {
    await resetUserData(user);
    await test();
    console.log('[PASS] TC' + number + ' ' + title);
  } catch (error) {
    failures.push({ number: number, title: title, error: error });
    console.error('[FAIL] TC' + number + ' ' + title + ': ' + error.message);
  }
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử thêm hũ chi tiêu ===');
  await connectDatabase();

  var previousUser = await User.findOne({ email: TEST_EMAIL });
  if (previousUser) {
    await SpendingJar.deleteMany({ userId: previousUser._id });
    await Transaction.deleteMany({ userId: previousUser._id });
    await User.deleteOne({ _id: previousUser._id });
  }

  var user = await User.create({
    name: 'Kiểm thử thêm hũ chi tiêu',
    email: TEST_EMAIL,
    passwordHash: 'dummy',
    walletBalance: INITIAL_BALANCE
  });
  var failures = [];
  var originalTransactionCreate = Transaction.create;

  try {
    await runCase('01', 'Tạo hũ hợp lệ, lưu hũ và cập nhật số dư', user, async function() {
      var res = await call(user, 'Ăn uống', 1000000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.jar.name, 'Ăn uống');
      assert.strictEqual(res.data.jar.balance, 1000000);
      assert.strictEqual(res.data.walletBalance, 4000000);
      assert.strictEqual((await User.findById(user.id)).walletBalance, 4000000);
    }, failures);

    await runCase('02', 'Từ chối khi bỏ trống tên hũ', user, async function() {
      var res = await call(user, '', 1000000);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Hãy nhập đầy đủ tên hũ');
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('03', 'Chấp nhận tên hũ một ký tự', user, async function() {
      var res = await call(user, 'A', 1000000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.jar.name, 'A');
    }, failures);

    await runCase('04', 'Chấp nhận tên hũ dài đúng 50 ký tự', user, async function() {
      var name = 'A'.repeat(50);
      var res = await call(user, name, 1000000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.jar.name, name);
    }, failures);

    await runCase('05', 'Từ chối tên hũ dài 51 ký tự', user, async function() {
      var res = await call(user, 'A'.repeat(51), 1000000);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Tên hũ không hợp lệ');
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('06', 'Từ chối khi bỏ trống số tiền', user, async function() {
      var res = await call(user, 'Ăn uống', '');
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Hãy cung cấp tiền cho hũ');
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('07', 'Từ chối số tiền bằng 0', user, async function() {
      var res = await call(user, 'Ăn uống', 0);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Số tiền cung cấp phải lớn hơn 0');
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('08', 'Từ chối số tiền âm', user, async function() {
      var res = await call(user, 'Ăn uống', -100000);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Số tiền cung cấp phải lớn hơn 0');
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('09', 'Cho phép tiếp tục tạo hũ với dữ liệu hợp lệ', user, async function() {
      var res = await call(user, 'Ăn uống', 1000000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 1);
    }, failures);

    await runCase('10', 'Cho phép nạp số tiền đúng bằng số dư ví', user, async function() {
      var res = await call(user, 'Ăn uống', INITIAL_BALANCE);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.walletBalance, 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, 0);
    }, failures);

    await runCase('11', 'Từ chối số tiền lớn hơn số dư ví', user, async function() {
      var res = await call(user, 'Ăn uống', INITIAL_BALANCE + 1);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.error, 'Bạn không đủ tiền trong ví để cung cấp cho hũ');
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('12', 'Xác nhận dữ liệu hợp lệ tạo hũ và lưu CSDL', user, async function() {
      var res = await call(user, 'Ăn uống', 1000000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 1);
      assert.strictEqual(await Transaction.countDocuments({
        userId: user.id,
        type: 'jar_contribution'
      }), 1);
      assert.strictEqual((await User.findById(user.id)).walletBalance, 4000000);
    }, failures);

    console.log('[SKIP] TC13 Hủy xác nhận là hành vi giao diện, không kiểm thử được ở controller/API');

    await runCase('14', 'Số dư sau khi tạo hũ còn đúng 4.000.000 VNĐ', user, async function() {
      var res = await call(user, 'Ăn uống', 1000000);
      assert.strictEqual(res.data.walletBalance, 4000000);
      assert.strictEqual((await User.findById(user.id)).walletBalance, 4000000);
    }, failures);

    await runCase('15', 'Hũ mới xuất hiện với đúng tên và số dư', user, async function() {
      var res = await call(user, 'Ăn uống', 1000000);
      var jar = await SpendingJar.findOne({ userId: user.id, name: 'Ăn uống' });
      assert.strictEqual(res.statusCode, 201);
      assert.ok(jar);
      assert.strictEqual(jar.balance, 1000000);
    }, failures);

    await runCase('16', 'Trả thông tin tạo hũ thành công', user, async function() {
      var res = await call(user, 'Ăn uống', 1000000);
      assert.strictEqual(res.statusCode, 201);
      assert.strictEqual(res.data.jar.name, 'Ăn uống');
      assert.strictEqual(res.data.message, 'Tạo hũ mới thành công!');
    }, failures);

    await runCase('17', 'Hoàn tác tạo hũ và số dư khi lưu giao dịch lỗi', user, async function() {
      Transaction.create = async function() {
        throw new Error('Simulated transaction persistence failure');
      };
      try {
        await assert.rejects(
          call(user, 'Ăn uống', 1000000),
          /Simulated transaction persistence failure/
        );
      } finally {
        Transaction.create = originalTransactionCreate;
      }
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual(await Transaction.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('18', 'Dữ liệu không hợp lệ không tạo hũ và không đổi số dư', user, async function() {
      var res = await call(user, '   ', 1000000);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('19', 'Từ chối khi tên và số tiền cùng bỏ trống', user, async function() {
      var res = await call(user, '', '');
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);

    await runCase('20', 'Từ chối số tiền không phải số', user, async function() {
      var res = await call(user, 'Ăn uống', 'abc');
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
      assert.strictEqual((await User.findById(user.id)).walletBalance, INITIAL_BALANCE);
    }, failures);
  } finally {
    Transaction.create = originalTransactionCreate;
    await SpendingJar.deleteMany({ userId: user._id });
    await Transaction.deleteMany({ userId: user._id });
    await User.deleteOne({ _id: user._id });
    await User.db.close();
  }

  console.log('=== Kết quả kiểm thử thêm hũ: ' + (19 - failures.length) + '/19 chạy, 1/20 bỏ qua ===');
  if (failures.length) {
    throw new Error(failures.length + ' test case thêm hũ thất bại');
  }
}

runTests().catch(function(error) {
  console.error('Test thất bại:', error);
  process.exit(1);
});
