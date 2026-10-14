'use strict';
var http = require('http');
var app = require('../app');
var User = require('../model/User');
var Transaction = require('../model/Transaction');
var bcrypt = require('bcryptjs');
var walletController = require('../controller/walletController');

var token = '';
var userId = '';
var server;

function request(method, path, body, headers) {
  return new Promise(function(resolve, reject) {
    var data = body ? JSON.stringify(body) : '';
    var opts = {
      hostname: 'localhost',
      port: 4001,
      path: path,
      method: method,
      headers: Object.assign({
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      }, headers || {})
    };
    var req = http.request(opts, function(res) {
      var chunks = [];
      res.on('data', function(c) { chunks.push(c); });
      res.on('end', function() {
        try { resolve({ status: res.statusCode, body: JSON.parse(Buffer.concat(chunks).toString()) }); }
        catch(e) { resolve({ status: res.statusCode, body: {} }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function pass(msg) { console.log('[PASS] ' + msg); }
function fail(msg, detail) { console.error('[FAIL] ' + msg); if (detail !== undefined) console.error('  Detail:', JSON.stringify(detail)); process.exit(1); }
function assert(cond, msg, detail) { if (!cond) fail(msg, detail); else pass(msg); }

async function setup() {
  await new Promise(function(resolve, reject) {
    server = http.createServer(app);
    server.listen(4001, function(err) { if (err) reject(err); else resolve(); });
  });
  walletController._resetPinAttempts();
  await User.deleteMany({ email: /bill_test/ });
  await Transaction.deleteMany({ account: /bill_test/ });
  var pinHash = await bcrypt.hash('123456', 10);
  var passwordHash = await bcrypt.hash('123456', 10);
  var user = await User.create({
    name: 'bill_test_user',
    email: 'bill_test@test.com',
    password: '123456',
    passwordHash: passwordHash,
    walletBalance: 500000,
    pinHash: pinHash
  });
  userId = user._id.toString();
  var res = await request('POST', '/api/auth/login', { name: 'bill_test_user', password: '123456' });
  token = res.body.token;
  if (!token) { console.error('Login failed', res.body); process.exit(1); }
  console.log('[OK] Khởi tạo tài khoản test thành công (Số dư: 500.000đ, PIN: 123456)');
}

async function teardown() {
  await User.deleteMany({ email: /bill_test/ });
  await Transaction.deleteMany({ account: /bill_test/ });
  walletController._resetPinAttempts();
  server.close();
}

async function runTests() {
  console.log('=== Bắt đầu kiểm thử Backend Use Case 07: Thanh toán hóa đơn (Cao Thái Tuấn) ===');
  var res;

  // Test 1: Lấy thông tin hóa đơn điện (Luồng con 3.1)
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 200 && res.body.success === true, 'Test 1: Lấy thông tin hóa đơn điện trực tiếp thành công', res.body);
  assert(res.body.bill.customerName === 'Nguyễn Văn A' && res.body.bill.totalAmount === 350000, 'Test 1b: Thông tin hóa đơn đầy đủ (tên KH, nhà cung cấp, kỳ, số tiền)', res.body.bill);

  // Test 2: E3 - Mã khách hàng để trống
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'direct', billType: 'Điện', customerCode: '' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 400 && res.body.code === 'EMPTY_CUSTOMER_CODE', 'Test 2: E3 - Mã khách hàng để trống trả về "Mã khách hàng/Mã hóa đơn không được để trống."', res.body);

  // Test 3: E4 - Mã QR không hợp lệ (không có tiền tố QR_)
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'qr', qrData: 'INVALID_DATA' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 400 && res.body.code === 'INVALID_QR', 'Test 3: E4 - QR không hợp lệ trả về "Mã QR không hợp lệ hoặc không thể giải mã."', res.body);

  // Test 4: E4 - QR rỗng
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'qr', qrData: '' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 400 && res.body.code === 'INVALID_QR', 'Test 4: E4 - QR data rỗng trả về lỗi INVALID_QR', res.body);

  // Test 5: E5 - API đối tác không phản hồi
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001' }, { 'Authorization': 'Bearer ' + token, 'x-mock-partner': 'timeout' });
  assert(res.status === 504 && res.body.code === 'PARTNER_TIMEOUT', 'Test 5: E5 - API đối tác không phản hồi báo "Không thể kết nối đến hệ thống đối tác."', res.body);

  // Test 6: Mã khách hàng không tồn tại
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'NOTEXIST_999' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 404 && res.body.code === 'BILL_NOT_FOUND', 'Test 6: Mã KH không tồn tại trả về BILL_NOT_FOUND', res.body);

  // Test 7: Lấy thông tin hóa đơn qua QR (Luồng con 3.2)
  res = await request('POST', '/api/wallet/bill-info', { paymentMethod: 'qr', qrData: 'QR_EVN001' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 200 && res.body.bill.customerCode === 'QR_EVN001', 'Test 7: Luồng 3.2 - Lấy thông tin hóa đơn bằng mã QR hợp lệ thành công', res.body);

  // Test 8: E1 - PIN không chính xác
  walletController._resetPinAttempts(userId);
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001', pin: '000000' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 401 && res.body.code === 'WRONG_PIN', 'Test 8: E1 - PIN không chính xác trả về "PIN không chính xác."', res.body);
  assert(typeof res.body.remainingAttempts === 'number', 'Test 8b: Hiển thị số lần nhập lại còn lại', res.body);

  // Test 9: E1 - Nhập sai PIN 3 lần khóa xác thực
  walletController._resetPinAttempts(userId);
  await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001', pin: '000000' }, { 'Authorization': 'Bearer ' + token });
  await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001', pin: '000000' }, { 'Authorization': 'Bearer ' + token });
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001', pin: '000000' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 401 && res.body.code === 'PIN_LOCKED', 'Test 9: E1 - Sai PIN 3 lần khóa xác thực giao dịch tạm thời', res.body);

  // Test 10: E2 - Số dư không đủ (Bảo hiểm 1.500.000đ + 10.000 phí > 500.000đ số dư)
  walletController._resetPinAttempts(userId);
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Bảo hiểm', customerCode: 'INS001', pin: '123456' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 400 && res.body.code === 'INSUFFICIENT_BALANCE', 'Test 10: E2 - Số dư không đủ báo "Số dư không đủ để thực hiện giao dịch."', res.body);

  // Test 11: Thanh toán hóa đơn điện thành công (Luồng chính)
  walletController._resetPinAttempts(userId);
  var beforeUser = await User.findById(userId);
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN001', pin: '123456' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 200 && res.body.success === true, 'Test 11: Thanh toán hóa đơn điện EVN001 (350.000đ) thành công', res.body);
  assert(res.body.message === 'Thanh toán thành công', 'Test 11b: Hệ thống hiển thị "Thanh toán thành công"', res.body);
  var afterUser = await User.findById(userId);
  assert(afterUser.walletBalance === beforeUser.walletBalance - 350000, 'Test 11c: Số dư ví bị trừ đúng 350.000đ', { before: beforeUser.walletBalance, after: afterUser.walletBalance });
  var txn = await Transaction.findOne({ account: 'bill_test@test.com', type: 'bill_payment', status: 'completed' });
  assert(txn !== null, 'Test 11d: Giao dịch được lưu vào lịch sử trạng thái completed', txn);

  // Test 12: Thanh toán hóa đơn nước (có phí 5.000đ)
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Nước', customerCode: 'WATER001', pin: '123456' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 200 && res.body.bill.totalAmount === 125000, 'Test 12: Thanh toán hóa đơn nước (120.000đ + phí 5.000đ = 125.000đ) thành công', res.body);

  // Test 13: Thanh toán QR thành công (Luồng con 3.2)
  await User.findByIdAndUpdate(userId, { walletBalance: 500000 });
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'qr', qrData: 'QR_WATER001', pin: '123456' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 200 && res.body.bill.customerCode === 'QR_WATER001', 'Test 13: Luồng 3.2 - Thanh toán QR hóa đơn nước thành công', res.body);

  // Test 14: E5 - API đối tác không phản hồi khi thanh toán
  res = await request('POST', '/api/wallet/bill-payments', { paymentMethod: 'direct', billType: 'Điện', customerCode: 'EVN002', pin: '123456', mockPartner: 'timeout' }, { 'Authorization': 'Bearer ' + token });
  assert(res.status === 504 && res.body.code === 'PARTNER_TIMEOUT', 'Test 14: E5 - API đối tác timeout khi thanh toán báo "Không thể kết nối đến hệ thống đối tác."', res.body);

  console.log('=== TẤT CẢ 14/14 BÀI TEST BACKEND USE CASE 07 ĐÃ VƯỢT QUA XUẤT SẮC! ===');
}

(async function() {
  require('dotenv').config();
  var mongoose = require('mongoose');
  var connectDatabase = require('../db/index.js');
  await connectDatabase();
  try {
    await setup();
    await runTests();
  } catch (err) {
    console.error('Error in bill_payment_test:', err);
    process.exit(1);
  } finally {
    await teardown();
    await mongoose.disconnect();
    process.exit(0);
  }
})();
