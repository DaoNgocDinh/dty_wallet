require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var SpendingJar = require('../model/SpendingJar');
var Transaction = require('../model/Transaction');
var User = require('../model/User');
var spendingJarController = require('../controller/spendingJarController');

var TEST_EMAIL = 'spending_jar_details_test@gmail.com';

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

async function callDetails(user, jar, page) {
  var res = mockResponse();
  await spendingJarController.details({
    params: { id: jar.id },
    user: { id: user.id },
    query: page === undefined ? {} : { page: String(page) }
  }, res);
  return res;
}

async function seedTransactions(user, jar, count, caseId) {
  await Transaction.deleteMany({ userId: user.id, 'metadata.jarId': jar.id });
  await SpendingJar.updateOne({ _id: jar.id }, { $set: { balance: count * 1000 } });
  if (!count) return [];

  var now = new Date();
  var documents = Array.from({ length: count }, function(_, index) {
    return {
      transactionCode: 'TX-JD-' + user.id + '-' + caseId + '-' + index,
      userId: user._id,
      account: user.email,
      type: 'jar_contribution',
      amount: 1000,
      sender: user.email,
      recipient: jar.name,
      status: 'completed',
      metadata: { jarId: jar.id },
      createdAt: new Date(now.getTime() - index * 1000)
    };
  });
  await Transaction.insertMany(documents);
  return documents;
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
  console.log('=== Bắt đầu kiểm thử xem chi tiết hũ chi tiêu ===');
  await connectDatabase();

  var previousUser = await User.findOne({ email: TEST_EMAIL });
  if (previousUser) {
    await SpendingJar.deleteMany({ userId: previousUser._id });
    await Transaction.deleteMany({ userId: previousUser._id });
    await User.deleteOne({ _id: previousUser._id });
  }

  var user = await User.create({
    name: 'Kiểm thử xem chi tiết hũ chi tiêu',
    email: TEST_EMAIL,
    passwordHash: 'dummy',
    walletBalance: 1000000
  });
  var jar;
  var failures = [];
  var originalCountDocuments = Transaction.countDocuments;

  try {
    jar = await SpendingJar.create({
      userId: user.id,
      name: 'Hũ kiểm thử chi tiết',
      balance: 0
    });

    await runCase('01', 'Hũ có 1 giao dịch hiển thị đúng 1 giao dịch', async function() {
      await seedTransactions(user, jar, 1, '01');
      var res = await callDetails(user, jar, 1);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.data.count, 1);
      assert.strictEqual(res.data.transactions.length, 1);
      assert.strictEqual(res.data.totalPages, 1);
    }, failures);

    await runCase('02', 'Hũ có 10 giao dịch hiển thị đủ trong 1 trang', async function() {
      await seedTransactions(user, jar, 10, '02');
      var res = await callDetails(user, jar, 1);
      assert.strictEqual(res.data.count, 10);
      assert.strictEqual(res.data.transactions.length, 10);
      assert.strictEqual(res.data.totalPages, 1);
    }, failures);

    await runCase('03', 'Hũ có 11 giao dịch phân trang tối đa 10 mỗi trang', async function() {
      await seedTransactions(user, jar, 11, '03');
      var res = await callDetails(user, jar, 1);
      assert.strictEqual(res.data.count, 11);
      assert.strictEqual(res.data.pageSize, 10);
      assert.strictEqual(res.data.transactions.length, 10);
      assert.strictEqual(res.data.totalPages, 2);
    }, failures);

    await runCase('04', 'Hũ có 20 giao dịch chia thành 2 trang', async function() {
      await seedTransactions(user, jar, 20, '04');
      var firstPage = await callDetails(user, jar, 1);
      var secondPage = await callDetails(user, jar, 2);
      assert.strictEqual(firstPage.data.totalPages, 2);
      assert.strictEqual(firstPage.data.transactions.length, 10);
      assert.strictEqual(secondPage.data.transactions.length, 10);
    }, failures);

    await runCase('05', 'Hũ có 21 giao dịch có 3 trang, trang cuối 1 giao dịch', async function() {
      await seedTransactions(user, jar, 21, '05');
      var firstPage = await callDetails(user, jar, 1);
      var lastPage = await callDetails(user, jar, 3);
      assert.strictEqual(firstPage.data.totalPages, 3);
      assert.strictEqual(firstPage.data.transactions.length, 10);
      assert.strictEqual(lastPage.data.transactions.length, 1);
    }, failures);

    await runCase('06', 'Hũ chưa có giao dịch trả về danh sách rỗng', async function() {
      await seedTransactions(user, jar, 0, '06');
      var res = await callDetails(user, jar, 1);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.data.count, 0);
      assert.deepStrictEqual(res.data.transactions, []);
      assert.strictEqual(res.data.totalPages, 0);
    }, failures);

    await runCase('07', 'Giao dịch có đủ dữ liệu tiêu đề, thời gian, tiền và số dư', async function() {
      await seedTransactions(user, jar, 1, '07');
      var res = await callDetails(user, jar, 1);
      var transaction = res.data.transactions[0];
      assert.strictEqual(transaction.transactionCode, 'TX-JD-' + user.id + '-07-0');
      assert.strictEqual(transaction.type, 'jar_contribution');
      assert.strictEqual(transaction.sender, user.email);
      assert.strictEqual(transaction.recipient, jar.name);
      assert.strictEqual(transaction.amount, 1000);
      assert.ok(Number.isFinite(new Date(transaction.createdAt).getTime()));
      assert.strictEqual(transaction.balanceAfter, 1000);
    }, failures);

    await runCase('08', 'Hũ có 15 giao dịch hiển thị 10 giao dịch ở trang 1 và 5 ở trang 2', async function() {
      await seedTransactions(user, jar, 15, '08');
      var firstPage = await callDetails(user, jar, 1);
      var secondPage = await callDetails(user, jar, 2);
      assert.strictEqual(firstPage.data.transactions.length, 10);
      assert.strictEqual(secondPage.data.transactions.length, 5);
      assert.strictEqual(firstPage.data.totalPages, 2);
    }, failures);

    await runCase('09', 'Chuyển sang trang 2 hiển thị 5 giao dịch còn lại', async function() {
      await seedTransactions(user, jar, 15, '09');
      var res = await callDetails(user, jar, 2);
      assert.strictEqual(res.data.page, 2);
      assert.strictEqual(res.data.transactions.length, 5);
    }, failures);

    await runCase('10', 'Quay lại trang 1 hiển thị lại đúng 10 giao dịch', async function() {
      await seedTransactions(user, jar, 15, '10');
      await callDetails(user, jar, 2);
      var firstPage = await callDetails(user, jar, 1);
      assert.strictEqual(firstPage.data.page, 1);
      assert.strictEqual(firstPage.data.transactions.length, 10);
      assert.strictEqual(firstPage.data.transactions[0].transactionCode, 'TX-JD-' + user.id + '-10-0');
    }, failures);

    await runCase('11', 'Truy xuất danh sách thành công khi CSDL hoạt động', async function() {
      await seedTransactions(user, jar, 3, '11');
      var res = await callDetails(user, jar, 1);
      assert.strictEqual(res.statusCode, 200);
      assert.strictEqual(res.data.count, 3);
      assert.strictEqual(res.data.transactions.length, 3);
    }, failures);

    await runCase('12', 'Lỗi truy xuất CSDL được chuyển tiếp để xử lý', async function() {
      Transaction.countDocuments = async function() {
        throw new Error('Simulated database read failure');
      };
      try {
        await assert.rejects(
          callDetails(user, jar, 1),
          /Simulated database read failure/
        );
      } finally {
        Transaction.countDocuments = originalCountDocuments;
      }
    }, failures);

    await runCase('13', 'Giao dịch đầu tiên khớp dữ liệu lấy từ CSDL', async function() {
      await seedTransactions(user, jar, 3, '13');
      var storedFirst = await Transaction.findOne({
        userId: user.id,
        'metadata.jarId': jar.id,
        transactionCode: 'TX-JD-' + user.id + '-13-0'
      });
      var res = await callDetails(user, jar, 1);
      assert.strictEqual(res.data.transactions[0].transactionCode, storedFirst.transactionCode);
      assert.strictEqual(res.data.transactions[0].amount, storedFirst.amount);
      assert.strictEqual(new Date(res.data.transactions[0].createdAt).getTime(), storedFirst.createdAt.getTime());
    }, failures);

    await runCase('14', 'Giao dịch thứ 11 hiển thị đúng ở trang 2', async function() {
      await seedTransactions(user, jar, 11, '14');
      var expectedEleventh = await Transaction.findOne({
        userId: user.id,
        'metadata.jarId': jar.id,
        transactionCode: 'TX-JD-' + user.id + '-14-10'
      });
      var secondPage = await callDetails(user, jar, 2);
      assert.strictEqual(secondPage.data.transactions.length, 1);
      assert.strictEqual(secondPage.data.transactions[0].transactionCode, expectedEleventh.transactionCode);
      assert.strictEqual(secondPage.data.transactions[0].amount, expectedEleventh.amount);
      assert.strictEqual(secondPage.data.transactions[0].balanceAfter, 1000);
    }, failures);
  } finally {
    Transaction.countDocuments = originalCountDocuments;
    await SpendingJar.deleteMany({ userId: user._id });
    await Transaction.deleteMany({ userId: user._id });
    await User.deleteOne({ _id: user._id });
    await User.db.close();
  }

  console.log('=== Kết quả kiểm thử xem chi tiết: ' + (14 - failures.length) + '/14 đạt ===');
  if (failures.length) {
    throw new Error(failures.length + ' test case xem chi tiết hũ thất bại');
  }
}

runTests().catch(function(error) {
  console.error('Test thất bại:', error);
  process.exit(1);
});
