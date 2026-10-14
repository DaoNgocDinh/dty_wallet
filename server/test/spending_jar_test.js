require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var SpendingJar = require('../model/SpendingJar');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var spendingJarController = require('../controller/spendingJarController');

var TEST_EMAIL = 'spending_jar_test@gmail.com';

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
  await spendingJarController.create(req, res);
  return res;
}

async function callDetails(req) {
  var res = mockResponse();
  await spendingJarController.details(req, res);
  return res;
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử tạo hũ chi tiêu ===');
  await connectDatabase();

  var previousUser = await User.findOne({ email: TEST_EMAIL });
  if (previousUser) {
    await SpendingJar.deleteMany({ userId: previousUser._id });
    await Transaction.deleteMany({ userId: previousUser._id });
    await User.deleteOne({ _id: previousUser._id });
  }

  var user = await User.create({
    name: 'Kiểm thử hũ chi tiêu',
    email: TEST_EMAIL,
    passwordHash: 'dummy',
    walletBalance: 1000000
  });
  var req = {
    user: { id: user.id },
    body: { name: '  Ăn uống  ', amount: 250000 }
  };

  try {
    var invalid = await call({
      user: req.user,
      body: { name: '   ', amount: 100000 }
    });
    assert.strictEqual(invalid.statusCode, 400);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 1000000);
    assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
    console.log('[PASS] Tên trống bị từ chối, số dư không đổi');

    var insufficient = await call({
      user: req.user,
      body: { name: 'Ăn uống', amount: 1000001 }
    });
    assert.strictEqual(insufficient.statusCode, 400);
    assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 0);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 1000000);
    console.log('[PASS] Số tiền vượt số dư bị từ chối, không tạo hũ');

    var created = await call(req);
    assert.strictEqual(created.statusCode, 201);
    assert.strictEqual(created.data.jar.name, 'Ăn uống');
    assert.strictEqual(created.data.jar.balance, 250000);
    assert.strictEqual(created.data.walletBalance, 750000);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 750000);
    assert.strictEqual(await Transaction.countDocuments({
      userId: user.id,
      type: 'jar_contribution'
    }), 1);
    console.log('[PASS] Tạo hũ không cần PIN, ghi giao dịch và cập nhật số dư ví');

    var jar = created.data.jar;
    var duplicate = await call({
      user: req.user,
      body: { name: '  ăn UỐNG  ', amount: 100000 }
    });
    assert.strictEqual(duplicate.statusCode, 409);
    assert.strictEqual(duplicate.data.code, 'SPENDING_JAR_NAME_EXISTS');
    assert.strictEqual(await SpendingJar.countDocuments({ userId: user.id }), 1);
    assert.strictEqual((await User.findById(user.id)).walletBalance, 750000);
    assert.strictEqual(await Transaction.countDocuments({
      userId: user.id,
      type: 'jar_contribution'
    }), 1);
    console.log('[PASS] Tên trùng không phân biệt hoa thường bị từ chối trước khi trừ tiền');

    var currentDate = new Date();
    await Transaction.insertMany(
      Array.from({ length: 11 }, function(_, index) {
        return {
          transactionCode: 'TX-JAR-DETAIL-' + index,
          userId: user._id,
          account: user.email,
          type: 'jar_contribution',
          amount: 10000,
          sender: user.email,
          recipient: jar.name,
          status: 'completed',
          metadata: { jarId: jar.id },
          createdAt: new Date(currentDate.getTime() - index * 1000)
        };
      })
    );

    var firstPage = await callDetails({
      params: { id: jar.id },
      user: { id: user.id },
      query: {
        year: currentDate.getFullYear(),
        month: currentDate.getMonth() + 1,
        page: '1',
        limit: '20'
      }
    });
    assert.strictEqual(firstPage.statusCode, 200);
    assert.strictEqual(firstPage.data.count, 12);
    assert.strictEqual(firstPage.data.pageSize, 10);
    assert.strictEqual(firstPage.data.totalPages, 2);
    assert.strictEqual(firstPage.data.transactions.length, 10);
    assert.strictEqual(typeof firstPage.data.transactions[0].balanceAfter, 'number');
    console.log('[PASS] Chi tiết hũ trả tối đa 10 giao dịch và số dư sau giao dịch');

    var secondPage = await callDetails({
      params: { id: jar.id },
      user: { id: user.id },
      query: {
        year: currentDate.getFullYear(),
        month: currentDate.getMonth() + 1,
        page: '2'
      }
    });
    assert.strictEqual(secondPage.data.transactions.length, 2);
    console.log('[PASS] Phân trang trả đúng số giao dịch còn lại');

    var invalidPage = await callDetails({
      params: { id: jar.id },
      user: { id: user.id },
      query: { year: currentDate.getFullYear(), month: currentDate.getMonth() + 1, page: '0' }
    });
    assert.strictEqual(invalidPage.statusCode, 400);
    console.log('[PASS] Trang không hợp lệ bị từ chối');
  } finally {
    await SpendingJar.deleteMany({ userId: user._id });
    await Transaction.deleteMany({ userId: user._id });
    await User.deleteOne({ _id: user._id });
    await User.db.close();
  }

  console.log('=== Tất cả kiểm thử tạo hũ chi tiêu đã vượt qua ===');
}

runTests().catch(function(error) {
  console.error('Test thất bại:', error);
  process.exit(1);
});
