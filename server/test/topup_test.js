// Unit & Integration test cho Use Case 08: Nạp tiền điện thoại/data (Cao Thái Tuấn)
require('dotenv').config();

var assert = require('assert');
var bcrypt = require('bcryptjs');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var Transaction = require('../model/Transaction');
var walletController = require('../controller/walletController');

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
  console.log('=== Bắt đầu kiểm thử Backend Use Case 08: Nạp tiền điện thoại/data (Cao Thái Tuấn) ===');
  await connectDatabase();

  // Dọn dẹp dữ liệu cũ
  await User.deleteMany({ email: /@topuptest\.com$/ });
  await Transaction.deleteMany({ account: /@topuptest\.com$/ });

  var pinHash = await bcrypt.hash('123456', 10);

  // Tạo tài khoản test có số dư 200.000đ và PIN 123456
  var testUser = await User.create({
    name: 'Cao Thái Tuấn Test',
    email: 'tuan_test@topuptest.com',
    phoneNumber: '0987654321',
    password: 'password123',
    passwordHash: await bcrypt.hash('password123', 10),
    pinHash: pinHash,
    walletBalance: 200000,
    role: 'user'
  });

  walletController._resetPinAttempts(testUser._id);
  console.log('[OK] Khởi tạo tài khoản test thành công (Số dư: 200.000đ, PIN: 123456)');

  // -------------------------------------------------------------
  // Test 1: Luồng 8.2.1 - Lấy danh sách gói Data (tất cả hoặc theo nhà mạng)
  // -------------------------------------------------------------
  {
    var resAll = mockResponse();
    await walletController.getDataPackages({ query: {} }, resAll);
    assert.strictEqual(resAll.statusCode, 200);
    assert.strictEqual(resAll.data.success, true);
    assert.ok(Array.isArray(resAll.data.packages));
    assert.ok(resAll.data.packages.length >= 10);

    var resViettel = mockResponse();
    await walletController.getDataPackages({ query: { carrier: 'Viettel' } }, resViettel);
    assert.strictEqual(resViettel.statusCode, 200);
    assert.ok(resViettel.data.packages.every(p => p.carrier.toLowerCase() === 'viettel'));
    // Kiểm tra cấu trúc gói data: Tên gói, dung lượng, thời hạn, giá tiền
    var samplePkg = resViettel.data.packages[0];
    assert.ok(samplePkg.name && samplePkg.data && samplePkg.duration && samplePkg.price);
    console.log('[PASS] Test 1: GET /api/wallet/data-packages trả về danh sách gói Data đầy đủ thông tin');
  }

  // -------------------------------------------------------------
  // Test 2: E1 - Số điện thoại không hợp lệ (không đủ 10 chữ số hoặc chứa ký tự khác)
  // -------------------------------------------------------------
  {
    var invalidPhones = ['098765432', '09876543211', '098765abcd', ''];
    for (var phone of invalidPhones) {
      var res = mockResponse();
      var req = {
        user: testUser,
        body: {
          carrier: 'Viettel',
          phoneNumber: phone,
          denomination: 50000,
          pin: '123456'
        },
        headers: {}
      };
      await walletController.mobileTopup('mobile_topup')(req, res);
      assert.strictEqual(res.statusCode, 400);
      assert.strictEqual(res.data.code, 'INVALID_PHONE');
      assert.strictEqual(res.data.error, 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.');
    }
    console.log('[PASS] Test 2: E1 - Số điện thoại không hợp lệ trả về lỗi "Số điện thoại không hợp lệ. Vui lòng kiểm tra lại."');
  }

  // -------------------------------------------------------------
  // Test 3: Kiểm tra nhà mạng không hợp lệ
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: testUser,
      body: {
        carrier: 'Gmobile',
        phoneNumber: '0987654321',
        denomination: 50000,
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_CARRIER');
    console.log('[PASS] Test 3: Nhà mạng ngoài 4 nhà mạng cho phép bị từ chối');
  }

  // -------------------------------------------------------------
  // Test 4: Mệnh giá nạp ĐT không hợp lệ (ngoài 10k, 20k, 50k, 100k, 200k, 500k)
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: testUser,
      body: {
        carrier: 'Vinaphone',
        phoneNumber: '0912345678',
        denomination: 35000,
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INVALID_DENOMINATION');
    console.log('[PASS] Test 4: Mệnh giá không nằm trong danh mục mệnh giá bị từ chối');
  }

  // -------------------------------------------------------------
  // Test 5: E3 - PIN không chính xác & đếm số lần sai
  // -------------------------------------------------------------
  {
    walletController._resetPinAttempts(testUser._id);

    // Sai lần 1
    var res1 = mockResponse();
    var req1 = {
      user: testUser,
      body: { carrier: 'Viettel', phoneNumber: '0987654321', denomination: 50000, pin: '000000' },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req1, res1);
    assert.strictEqual(res1.statusCode, 401);
    assert.strictEqual(res1.data.code, 'WRONG_PIN');
    assert.strictEqual(res1.data.error, 'PIN không chính xác.');
    assert.strictEqual(res1.data.remainingAttempts, 2);

    // Sai lần 2
    var res2 = mockResponse();
    var req2 = {
      user: testUser,
      body: { carrier: 'Viettel', phoneNumber: '0987654321', denomination: 50000, pin: '111111' },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req2, res2);
    assert.strictEqual(res2.statusCode, 401);
    assert.strictEqual(res2.data.code, 'WRONG_PIN');
    assert.strictEqual(res2.data.remainingAttempts, 1);

    // Sai lần 3 -> Khóa tạm thời
    var res3 = mockResponse();
    var req3 = {
      user: testUser,
      body: { carrier: 'Viettel', phoneNumber: '0987654321', denomination: 50000, pin: '222222' },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req3, res3);
    assert.strictEqual(res3.statusCode, 401);
    assert.strictEqual(res3.data.code, 'PIN_LOCKED');
    assert.ok(res3.data.error.includes('Nhập sai mã PIN quá 3 lần'));

    // Thử lại khi đang bị khóa
    var resLock = mockResponse();
    await walletController.mobileTopup('mobile_topup')(req3, resLock);
    assert.strictEqual(resLock.statusCode, 423);
    assert.strictEqual(resLock.data.code, 'PIN_LOCKED');

    // Reset lại để chạy các test tiếp theo
    walletController._resetPinAttempts(testUser._id);
    console.log('[PASS] Test 5: E3 - Nhập sai PIN báo "PIN không chính xác.", sai quá 3 lần khóa xác thực giao dịch');
  }

  // -------------------------------------------------------------
  // Test 6: E2 - Số dư không đủ
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: testUser, // Số dư hiện tại là 200.000đ
      body: {
        carrier: 'Viettel',
        phoneNumber: '0987654321',
        denomination: 500000, // Cần 500.000đ > 200.000đ
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'INSUFFICIENT_BALANCE');
    assert.strictEqual(res.data.error, 'Số dư không đủ để thực hiện giao dịch.');
    console.log('[PASS] Test 6: E2 - Số dư ví không đủ báo "Số dư không đủ để thực hiện giao dịch."');
  }

  // -------------------------------------------------------------
  // Test 7: E4 - API nhà mạng không phản hồi / timeout
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: testUser,
      body: {
        carrier: 'Mobifone',
        phoneNumber: '0901234567',
        denomination: 50000,
        pin: '123456',
        mockCarrier: 'timeout'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 504);
    assert.strictEqual(res.data.code, 'CARRIER_TIMEOUT');
    assert.strictEqual(res.data.error, 'Không thể xử lý giao dịch. Vui lòng thử lại sau.');
    console.log('[PASS] Test 7: E4 - API nhà mạng lỗi kết nối/timeout báo "Không thể xử lý giao dịch. Vui lòng thử lại sau."');
  }

  // -------------------------------------------------------------
  // Test 8: E5 - Giao dịch nhà mạng thất bại
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: testUser,
      body: {
        carrier: 'Vietnamobile',
        phoneNumber: '0921234567',
        denomination: 20000,
        pin: '123456',
        mockCarrier: 'failed'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 502);
    assert.strictEqual(res.data.code, 'CARRIER_FAILED');
    assert.strictEqual(res.data.error, 'Giao dịch không thành công. Vui lòng thử lại.');
    console.log('[PASS] Test 8: E5 - Giao dịch nhà mạng thất bại báo "Giao dịch không thành công. Vui lòng thử lại."');
  }

  // -------------------------------------------------------------
  // Test 9: E6 - Gói Data không còn khả dụng
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: testUser,
      body: {
        carrier: 'Viettel',
        phoneNumber: '0987654321',
        dataPackage: 'EXPIRED_TEST',
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('data_topup')(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.data.code, 'PACKAGE_NOT_AVAILABLE');
    assert.strictEqual(res.data.error, 'Gói Data không còn khả dụng. Vui lòng chọn gói khác.');
    console.log('[PASS] Test 9: E6 - Gói Data đã ngừng cung cấp báo "Gói Data không còn khả dụng. Vui lòng chọn gói khác."');
  }

  // -------------------------------------------------------------
  // Test 10: Luồng thành công - Nạp tiền điện thoại (Subflow 8.1 & Luồng chính)
  // -------------------------------------------------------------
  {
    var initialBalance = testUser.walletBalance; // 200.000đ
    var amount = 50000;
    var res = mockResponse();
    var req = {
      user: testUser,
      body: {
        carrier: 'Viettel',
        phoneNumber: '0987654321',
        denomination: amount,
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.success, true);
    assert.strictEqual(res.data.message, 'Giao dịch thành công');
    assert.strictEqual(res.data.walletBalance, initialBalance - amount); // 150.000đ

    // Kiểm tra dữ liệu trong DB
    var updatedUser = await User.findById(testUser._id);
    assert.strictEqual(updatedUser.walletBalance, 150000);

    var txn = await Transaction.findById(res.data.transaction._id);
    assert.ok(txn);
    assert.strictEqual(txn.type, 'mobile_topup');
    assert.strictEqual(txn.amount, 50000);
    assert.strictEqual(txn.recipient, '0987654321');
    assert.strictEqual(txn.status, 'completed');
    assert.strictEqual(txn.metadata.carrier, 'Viettel');
    console.log('[PASS] Test 10: Nạp tiền điện thoại thành công - số dư ví bị trừ 50.000đ, lưu lịch sử giao dịch trạng thái completed');
  }

  // -------------------------------------------------------------
  // Test 11: Luồng thành công - Nạp gói Data (Subflow 8.2 & Luồng chính)
  // -------------------------------------------------------------
  {
    var currentBalance = 150000;
    var pkgPrice = 30000; // ST30K (7GB - 7 ngày)
    var res = mockResponse();
    var req = {
      user: await User.findById(testUser._id),
      body: {
        carrier: 'Viettel',
        phoneNumber: '0987654321',
        dataPackage: 'ST30K',
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('data_topup')(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.success, true);
    assert.strictEqual(res.data.message, 'Giao dịch thành công');
    assert.strictEqual(res.data.walletBalance, currentBalance - pkgPrice); // 120.000đ

    var updatedUser = await User.findById(testUser._id);
    assert.strictEqual(updatedUser.walletBalance, 120000);

    var txn = await Transaction.findById(res.data.transaction._id);
    assert.ok(txn);
    assert.strictEqual(txn.type, 'data_topup');
    assert.strictEqual(txn.amount, 30000);
    assert.strictEqual(txn.recipient, '0987654321');
    assert.strictEqual(txn.status, 'completed');
    assert.strictEqual(txn.metadata.dataPackage, 'ST30K');
    console.log('[PASS] Test 11: Nạp gói Data thành công - số dư trừ 30.000đ, lưu lịch sử giao dịch gói Data chính xác');
  }

  // -------------------------------------------------------------
  // Test 12: Nạp cho số điện thoại khác (Alternative Flow AF1)
  // -------------------------------------------------------------
  {
    var res = mockResponse();
    var req = {
      user: await User.findById(testUser._id),
      body: {
        carrier: 'Mobifone',
        phoneNumber: '0909888999', // SĐT khác của bạn bè / người thân
        denomination: 20000,
        pin: '123456'
      },
      headers: {}
    };
    await walletController.mobileTopup('mobile_topup')(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.success, true);
    assert.strictEqual(res.data.transaction.recipient, '0909888999');

    var updatedUser = await User.findById(testUser._id);
    assert.strictEqual(updatedUser.walletBalance, 100000);
    console.log('[PASS] Test 12: AF1 - Nạp cho số khác (0909888999) thành công');
  }

  console.log('=== TẤT CẢ 12/12 BÀI TEST BACKEND USE CASE 08 ĐÃ VƯỢT QUA XUẤT SẮC! ===');
}

runTests().then(function() {
  process.exit(0);
}).catch(function(err) {
  console.error('LỖI KIỂM THỬ:', err);
  process.exit(1);
});
