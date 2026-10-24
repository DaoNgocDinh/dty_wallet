'use strict';
var http = require('http');
var assert = require('assert');
var app = require('../app');
var connectDatabase = require('../db/index');
var User = require('../model/User');
var jwt = require('jsonwebtoken');
var security = require('../config/security');

var server;
var port = 4005;

function request(method, path, headers) {
  return new Promise(function(resolve, reject) {
    var opts = {
      hostname: 'localhost',
      port: port,
      path: path,
      method: method,
      headers: Object.assign({
        'Content-Type': 'application/json'
      }, headers || {})
    };
    var req = http.request(opts, function(res) {
      var chunks = [];
      res.on('data', function(c) { chunks.push(c); });
      res.on('end', function() {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(Buffer.concat(chunks).toString()) });
        } catch (e) {
          resolve({ status: res.statusCode, body: {} });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử Backend API Tìm kiếm tính năng (Feature Search) ===');
  await connectDatabase();

  await new Promise(function(resolve) {
    server = http.createServer(app).listen(port, resolve);
  });

  try {
    // 1. Không truyền từ khoá -> Trả về danh sách tính năng thông thường (không có adminOnly)
    var resAll = await request('GET', '/api/features/search');
    assert.strictEqual(resAll.status, 200);
    assert.strictEqual(resAll.body.success, true);
    assert.ok(resAll.body.features.length >= 9, 'Phải có ít nhất 9 tính năng cơ bản');
    assert.strictEqual(resAll.body.features.some(f => f.id === 'admin_users'), false, 'Khách thường không thấy admin');
    console.log('[PASS] Test 1: GET /api/features/search trả về đầy đủ tính năng người dùng');

    // 2. Tìm kiếm với từ khoá không dấu: "nap"
    var resNap = await request('GET', '/api/features/search?q=nap');
    assert.strictEqual(resNap.status, 200);
    var ids = resNap.body.features.map(f => f.id);
    assert.ok(ids.includes('deposit'), 'Phải bao gồm Nạp ví');
    assert.ok(ids.includes('topup_phone'), 'Phải bao gồm Nạp ĐT');
    assert.ok(ids.includes('topup_data'), 'Phải bao gồm Nạp Data');
    console.log('[PASS] Test 2: Tìm kiếm "nap" trả về Nạp ví, Nạp điện thoại và Nạp Data');

    // 3. Tìm kiếm có dấu: "hoá đơn"
    var resBill = await request('GET', '/api/features/search?q=' + encodeURIComponent('hoá đơn'));
    assert.strictEqual(resBill.status, 200);
    assert.ok(resBill.body.features.some(f => f.id === 'bill_payment'));
    console.log('[PASS] Test 3: Tìm kiếm có dấu "hoá đơn" tìm thấy đúng tính năng Thanh toán hoá đơn');

    // 4. Tìm kiếm "quy" (Quỹ)
    var resFund = await request('GET', '/api/features/search?q=quy');
    assert.strictEqual(resFund.status, 200);
    assert.ok(resFund.body.features.some(f => f.id === 'funds'));
    console.log('[PASS] Test 4: Tìm kiếm "quy" tìm thấy tính năng Quản lý quỹ');

    // 5. Tìm kiếm "hu" (Hũ chi tiêu)
    var resJars = await request('GET', '/api/features/search?q=hu');
    assert.strictEqual(resJars.status, 200);
    assert.ok(resJars.body.features.some(f => f.id === 'spending_jars'));
    console.log('[PASS] Test 5: Tìm kiếm "hu" tìm thấy tính năng Hũ chi tiêu');

    // 6. Tìm kiếm từ khoá không tồn tại
    var resEmpty = await request('GET', '/api/features/search?q=khongtontaitronghethong123');
    assert.strictEqual(resEmpty.status, 200);
    assert.strictEqual(resEmpty.body.count, 0);
    assert.strictEqual(resEmpty.body.features.length, 0);
    console.log('[PASS] Test 6: Từ khoá không khớp trả về danh sách rỗng an toàn');

    // 7. Tạo admin user và token để test tìm kiếm quyền admin
    var adminUser = await User.findOne({ role: 'admin' });
    if (!adminUser) {
      adminUser = await User.create({
        name: 'Admin Search Test',
        email: 'admin_search_test@dty.com',
        phoneNumber: '0988776655',
        passwordHash: 'dummy',
        role: 'admin'
      });
    }
    var adminToken = jwt.sign({ sub: adminUser._id }, security.jwtSecret, { expiresIn: '1h' });

    var resAdmin = await request('GET', '/api/features/search?q=admin', {
      'Authorization': 'Bearer ' + adminToken
    });
    assert.strictEqual(resAdmin.status, 200);
    assert.ok(resAdmin.body.features.some(f => f.id === 'admin_users'));
    console.log('[PASS] Test 7: Admin tìm kiếm "admin" trả về tính năng Quản lý tài khoản (Admin)');

    console.log('=== TẤT CẢ 7/7 BÀI TEST API TÌM KIẾM TÍNH NĂNG ĐÃ THÀNH CÔNG! ===');
  } finally {
    if (server) server.close();
  }
}

runTests().then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});
