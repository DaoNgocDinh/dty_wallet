// Unit / Integration test cho Role Admin và Tính năng xem danh sách tài khoản
require('dotenv').config();

var assert = require('assert');
var bcrypt = require('bcryptjs');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var adminController = require('../controller/adminController');
var authController = require('../controller/authController');
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

  // Test 7: Tự động sinh tài khoản admin nếu database chưa có: tài khoản:admin, mật khẩu:123456, email:admin@gmail.com
  {
    // Xoá tài khoản admin nếu đã tồn tại để giả lập database chưa có admin
    await User.deleteMany({
      $or: [
        { name: /^admin$/i },
        { email: 'admin@gmail.com' },
        { role: 'admin' }
      ]
    });

    // Gọi ensureAdminAccount
    var createdAdmin = await connectDatabase.ensureAdminAccount();
    assert.ok(createdAdmin, 'Phải tạo thành công tài khoản admin mới');
    assert.strictEqual(createdAdmin.name, 'admin');
    assert.strictEqual(createdAdmin.email, 'admin@gmail.com');
    assert.strictEqual(createdAdmin.role, 'admin');

    // Kiểm tra mật khẩu băm phải khớp với "123456"
    var fetchedAdmin = await User.findById(createdAdmin._id).select('+passwordHash');
    var isPasswordMatch = await bcrypt.compare('123456', fetchedAdmin.passwordHash);
    assert.strictEqual(isPasswordMatch, true, 'Mật khẩu phải là 123456');
    console.log('[PASS] Test 7: Tự động sinh tài khoản admin khi database chưa có (admin / 123456 / admin@gmail.com)');
  }

  // Test 8: Đăng nhập bằng tài khoản admin tự sinh (bằng username "admin" hoặc email "admin@gmail.com")
  {
    // Đăng nhập bằng tên tài khoản "admin"
    var reqLoginName = {
      body: { name: 'admin', password: '123456' }
    };
    var resLoginName = mockResponse();
    await authController.login(reqLoginName, resLoginName);

    assert.strictEqual(resLoginName.statusCode, 200);
    assert.ok(resLoginName.data.token, 'Phải trả về token khi đăng nhập thành công');
    assert.strictEqual(resLoginName.data.user.role, 'admin');
    assert.strictEqual(resLoginName.data.user.name, 'admin');
    assert.strictEqual(resLoginName.data.user.email, 'admin@gmail.com');

    // Đăng nhập bằng email "admin@gmail.com"
    var reqLoginEmail = {
      body: { name: 'admin@gmail.com', password: '123456' }
    };
    var resLoginEmail = mockResponse();
    await authController.login(reqLoginEmail, resLoginEmail);

    assert.strictEqual(resLoginEmail.statusCode, 200);
    assert.ok(resLoginEmail.data.token, 'Phải trả về token khi đăng nhập bằng email');
    assert.strictEqual(resLoginEmail.data.user.role, 'admin');
    console.log('[PASS] Test 8: Đăng nhập thành công với tài khoản admin vừa sinh bằng cả tên và email');
  }

  // Test 9: Gọi lại ensureAdminAccount khi đã có admin thì không tạo trùng
  {
    var beforeCount = await User.countDocuments({ role: 'admin' });
    await connectDatabase.ensureAdminAccount();
    var afterCount = await User.countDocuments({ role: 'admin' });
    assert.strictEqual(beforeCount, afterCount, 'Không được tạo trùng tài khoản admin khi đã tồn tại');
    console.log('[PASS] Test 9: Không tạo trùng tài khoản admin khi database đã có');
  }

  // Dọn dẹp dữ liệu test
  await User.deleteMany({ email: /@admintest\.com$/ });
  await User.db.close();

  console.log('=== TẤT CẢ 9/9 BÀI TEST BACKEND ROLE ADMIN & TỰ ĐỘNG SINH TÀI KHOẢN ADMIN ĐÃ PASS! ===');
}

runTests().catch(function(err) {
  console.error('Test thất bại:', err);
  process.exit(1);
});
