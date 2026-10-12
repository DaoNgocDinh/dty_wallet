// Unit / Integration test cho Role Admin và Tính năng xem danh sách tài khoản
require('dotenv').config();

var assert = require('assert');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var adminController = require('../controller/adminController');
var requireAdmin = require('../middleware/admin');

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
  console.log('=== Bắt đầu kiểm thử Backend Role Admin & Xem danh sách tài khoản ===');
  await connectDatabase();

  // Dọn dẹp dữ liệu test cũ nếu có
  await User.deleteMany({ email: /@admintest\.com$/ });

  // Tạo tài khoản admin test
  var adminUser = await User.create({
    name: 'Admin Test',
    email: 'admin_test@admintest.com',
    phoneNumber: '0909999999',
    passwordHash: 'dummy',
    walletBalance: 5000000,
    role: 'admin'
  });

  // Tạo tài khoản người dùng thông thường
  var normalUser = await User.create({
    name: 'Normal User Test',
    email: 'normal_user@admintest.com',
    phoneNumber: '0911111111',
    passwordHash: 'dummy',
    walletBalance: 1000000,
    role: 'user'
  });

  console.log('[OK] Khởi tạo tài khoản Admin và User test thành công');

  // Test 1: Kiểm tra role của admin và normal user
  {
    assert.strictEqual(adminUser.role, 'admin');
    assert.strictEqual(normalUser.role, 'user');
    console.log('[PASS] Test 1: Schema User lưu đúng role admin và user');
  }

  // Test 2: Middleware requireAdmin chặn người dùng không phải admin (403)
  {
    var req = { user: normalUser };
    var res = mockResponse();
    var nextCalled = false;
    requireAdmin(req, res, function() { nextCalled = true; });

    assert.strictEqual(nextCalled, false, 'Next không được gọi đối với user thường');
    assert.strictEqual(res.statusCode, 403, 'Mã lỗi phải là 403');
    assert.strictEqual(res.data.code, 'FORBIDDEN');
    console.log('[PASS] Test 2: Người dùng thông thường bị chặn với mã lỗi 403 FORBIDDEN');
  }

  // Test 3: Middleware requireAdmin cho phép người dùng có role admin đi tiếp
  {
    var req = { user: adminUser };
    var res = mockResponse();
    var nextCalled = false;
    requireAdmin(req, res, function() { nextCalled = true; });

    assert.strictEqual(nextCalled, true, 'Next phải được gọi khi user là admin');
    console.log('[PASS] Test 3: Admin vượt qua middleware requireAdmin thành công');
  }

  // Test 4: Admin xem danh sách tất cả tài khoản
  {
    var req = { user: adminUser, query: {} };
    var res = mockResponse();
    await adminController.listUsers(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.ok(Array.isArray(res.data.data), 'Kết quả phải là một mảng data');
    assert.ok(res.data.data.length >= 2, 'Danh sách phải chứa ít nhất 2 tài khoản test');

    // Kiểm tra cấu trúc tài khoản trả về không lộ passwordHash/pinHash
    var first = res.data.data[0];
    assert.ok(first.name);
    assert.ok(first.email);
    assert.ok(first.role);
    assert.strictEqual(first.passwordHash, undefined, 'Không được lộ passwordHash');
    assert.strictEqual(first.pinHash, undefined, 'Không được lộ pinHash');
    assert.ok(first.password, 'Danh sách quản lý tài khoản phải hiển thị mật khẩu');
    console.log('[PASS] Test 4: Admin lấy danh sách tài khoản thành công kèm mật khẩu');
  }

  // Test 5: Admin tìm kiếm tài khoản theo từ khóa (tên, email, role)
  {
    var req = { user: adminUser, query: { search: 'admin_test' } };
    var res = mockResponse();
    await adminController.listUsers(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.data.data.length, 1);
    assert.strictEqual(res.data.data[0].email, 'admin_test@admintest.com');
    console.log('[PASS] Test 5: Tìm kiếm theo email "admin_test" trả về đúng 1 tài khoản');
  }

  // Test 6: Tìm kiếm theo role "admin"
  {
    var req = { user: adminUser, query: { search: 'admin' } };
    var res = mockResponse();
    await adminController.listUsers(req, res);

    assert.strictEqual(res.statusCode, 200);
    assert.ok(res.data.data.some(function(u) { return u.role === 'admin'; }));
    console.log('[PASS] Test 6: Tìm kiếm theo role admin hoạt động chính xác');
  }

  // Dọn dẹp dữ liệu test
  await User.deleteMany({ email: /@admintest\.com$/ });
  await User.db.close();

  console.log('=== TẤT CẢ 6/6 BÀI TEST BACKEND ROLE ADMIN & XEM DANH SÁCH TÀI KHOẢN ĐÃ PASS! ===');
}

runTests().catch(function(err) {
  console.error('Test thất bại:', err);
  process.exit(1);
});
