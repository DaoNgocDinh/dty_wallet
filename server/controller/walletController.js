var bcrypt = require('bcryptjs');
var crypto = require('crypto');
var Transaction = require('../model/Transaction');
var User = require('../model/User');

// Danh sách các gói Data mẫu cho 4 nhà mạng theo chuẩn thị trường Việt Nam
var DATA_PACKAGES = [
  // Viettel
  { id: 'ST5K', name: 'ST5K', carrier: 'Viettel', data: '500MB', duration: '1 ngày', price: 5000, description: '500MB tốc độ cao sử dụng trong 24h', available: true },
  { id: 'ST15K', name: 'ST15K', carrier: 'Viettel', data: '3GB', duration: '3 ngày', price: 15000, description: '3GB tốc độ cao sử dụng trong 3 ngày', available: true },
  { id: 'ST30K', name: 'ST30K', carrier: 'Viettel', data: '7GB', duration: '7 ngày', price: 30000, description: '7GB tốc độ cao sử dụng trong 7 ngày', available: true },
  { id: 'SD90', name: 'SD90', carrier: 'Viettel', data: '1.5GB/ngày', duration: '30 ngày', price: 90000, description: '1.5GB/ngày (45GB/tháng) lướt mạng', available: true },
  { id: 'SD120', name: 'SD120', carrier: 'Viettel', data: '2GB/ngày', duration: '30 ngày', price: 120000, description: '2GB/ngày (60GB/tháng) tốc độ cao', available: true },
  { id: 'SD150', name: 'SD150', carrier: 'Viettel', data: '3GB/ngày', duration: '30 ngày', price: 150000, description: '3GB/ngày (90GB/tháng) trọn gói', available: true },

  // Vinaphone
  { id: 'D3', name: 'D3', carrier: 'Vinaphone', data: '3GB', duration: '3 ngày', price: 15000, description: '3GB data trong 3 ngày', available: true },
  { id: 'DT30', name: 'DT30', carrier: 'Vinaphone', data: '7GB', duration: '7 ngày', price: 30000, description: '7GB data sử dụng trong 7 ngày', available: true },
  { id: 'BIG90', name: 'BIG90', carrier: 'Vinaphone', data: '1GB/ngày', duration: '30 ngày', price: 90000, description: '1GB/ngày (30GB/tháng)', available: true },
  { id: 'BIG120', name: 'BIG120', carrier: 'Vinaphone', data: '2GB/ngày', duration: '30 ngày', price: 120000, description: '2GB/ngày (60GB/tháng)', available: true },
  { id: 'VD149', name: 'VD149', carrier: 'Vinaphone', data: '4GB/ngày', duration: '30 ngày', price: 149000, description: '4GB/ngày kèm gọi thoại', available: true },

  // Mobifone
  { id: 'D15', name: 'D15', carrier: 'Mobifone', data: '3GB', duration: '3 ngày', price: 15000, description: '3GB data trong 3 ngày', available: true },
  { id: 'D30', name: 'D30', carrier: 'Mobifone', data: '7GB', duration: '7 ngày', price: 30000, description: '7GB data trong 7 ngày', available: true },
  { id: 'KC90', name: 'KC90', carrier: 'Mobifone', data: '1GB/ngày', duration: '30 ngày', price: 90000, description: '1GB/ngày (30GB/tháng)', available: true },
  { id: 'KC120', name: 'KC120', carrier: 'Mobifone', data: '1.5GB/ngày', duration: '30 ngày', price: 120000, description: '1.5GB/ngày (45GB/tháng)', available: true },
  { id: 'MF150', name: 'MF150', carrier: 'Mobifone', data: '4GB/ngày', duration: '30 ngày', price: 150000, description: '4GB/ngày (120GB/tháng)', available: true },

  // Vietnamobile
  { id: 'D5', name: 'D5', carrier: 'Vietnamobile', data: '4GB', duration: '1 ngày', price: 5000, description: '4GB data trong 24 giờ', available: true },
  { id: '7D', name: '7D', carrier: 'Vietnamobile', data: '7GB', duration: '7 ngày', price: 20000, description: '7GB data trong 7 ngày', available: true },
  { id: '4GMEGAY', name: '4GMEGAY', carrier: 'Vietnamobile', data: '5GB/ngày', duration: '30 ngày', price: 50000, description: '5GB/ngày (150GB/tháng)', available: true },
  { id: '4GMONTH', name: '4GMONTH', carrier: 'Vietnamobile', data: '8GB/ngày', duration: '30 ngày', price: 90000, description: '8GB/ngày (240GB/tháng)', available: true },

  // Gói mô phỏng ngừng cung cấp (kiểm thử E6)
  { id: 'EXPIRED_TEST', name: 'EXPIRED_TEST', carrier: 'Viettel', data: '10GB', duration: '30 ngày', price: 50000, description: 'Gói thử nghiệm ngừng cung cấp', available: false }
];

// Quản lý số lần nhập sai PIN theo từng userId (Map<userId, { count, lockedUntil }>)
var pinAttempts = new Map();

function findDataPackage(carrier, packageIdOrName) {
  var target = String(packageIdOrName || '').trim().toLowerCase();
  return DATA_PACKAGES.find(function(p) {
    return p.carrier.toLowerCase() === String(carrier || '').trim().toLowerCase() &&
      (p.id.toLowerCase() === target || p.name.toLowerCase() === target);
  });
}

exports.balance = async function(req, res) {
  res.json({ walletBalance: req.user.walletBalance, role: req.user.role || 'user' });
};

exports.getDataPackages = async function(req, res) {
  var carrier = String(req.query.carrier || '').trim();
  var packages = DATA_PACKAGES;
  if (carrier) {
    packages = packages.filter(function(p) {
      return p.carrier.toLowerCase() === carrier.toLowerCase();
    });
  }
  res.json({
    success: true,
    packages: packages
  });
};

exports.depositIntent = async function(req, res) {
  var amount = Number(req.body.amount);
  var source = String(req.body.source || '').trim();
  var paymentMethod = String(req.body.paymentMethod || '').trim();
  if (!source || !Number.isFinite(amount) || amount <= 0) {
    return res.status(400).json({ error: 'source and positive amount are required' });
  }
  if (!paymentMethod && !req.body.qrInfo) {
    return res.status(400).json({ error: 'paymentMethod or qrInfo is required' });
  }
  var transaction = await Transaction.create({
    transactionCode: code(), userId: req.user.id, account: req.user.email,
    type: 'wallet_deposit', amount: amount, sender: source, recipient: req.user.email,
    status: 'pending', metadata: { paymentMethod: paymentMethod || 'qr', hasQrInfo: Boolean(req.body.qrInfo) }
  });
  res.status(202).json({ message: 'Deposit request created; wallet is credited after payment confirmation', transaction: transaction });
};

/**
 * 2.1.8 Chức năng Nạp tiền điện thoại / Nạp gói Data (Use Case 08 - Cao Thái Tuấn)
 */
exports.mobileTopup = function(type) {
  return async function(req, res) {
    var isData = type === 'data_topup';
    var carrier = String(req.body.carrier || '').trim();
    var phoneNumber = String(req.body.phoneNumber || '').trim();
    var dataPackage = req.body.dataPackage ? String(req.body.dataPackage).trim() : null;

    // 1. Kiểm tra nhà mạng
    var validCarriers = ['Viettel', 'Vinaphone', 'Mobifone', 'Vietnamobile'];
    var matchedCarrier = validCarriers.find(function(c) {
      return c.toLowerCase() === carrier.toLowerCase();
    });
    if (!carrier || !matchedCarrier) {
      return res.status(400).json({
        code: 'INVALID_CARRIER',
        error: 'Vui lòng chọn một trong các nhà mạng: Viettel, Vinaphone, Mobifone, Vietnamobile'
      });
    }
    var normalizedCarrier = matchedCarrier;

    // 2. Kiểm tra định dạng số điện thoại (E1: chỉ gồm ký tự số và đúng 10 chữ số)
    if (!phoneNumber || !/^[0-9]{10}$/.test(phoneNumber)) {
      return res.status(400).json({
        code: 'INVALID_PHONE',
        error: 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.'
      });
    }

    var amount = 0;
    var pkg = null;

    if (isData) {
      // 3. Gói Data (Subflow 8.2 & E6)
      if (!dataPackage) {
        return res.status(400).json({
          code: 'PACKAGE_REQUIRED',
          error: 'Vui lòng chọn gói Data'
        });
      }
      pkg = findDataPackage(normalizedCarrier, dataPackage);
      if (!pkg || pkg.available === false) {
        return res.status(400).json({
          code: 'PACKAGE_NOT_AVAILABLE',
          error: 'Gói Data không còn khả dụng. Vui lòng chọn gói khác.'
        });
      }
      amount = pkg.price;
    } else {
      // 4. Mệnh giá nạp ĐT (Subflow 8.1)
      amount = Number(req.body.amount || req.body.denomination);
      var validDenominations = [10000, 20000, 50000, 100000, 200000, 500000];
      if (!validDenominations.includes(amount)) {
        return res.status(400).json({
          code: 'INVALID_DENOMINATION',
          error: 'Mệnh giá nạp không hợp lệ. Vui lòng chọn 10.000đ, 20.000đ, 50.000đ, 100.000đ, 200.000đ hoặc 500.000đ'
        });
      }
    }

    // 5. Xác thực mã PIN (Bước 13 & E3)
    var user = await verifyPin(req, res);
    if (!user) return;

    // 6. Kiểm tra số dư ví (Bước 13 & E2)
    if (user.walletBalance < amount) {
      return res.status(400).json({
        code: 'INSUFFICIENT_BALANCE',
        error: 'Số dư không đủ để thực hiện giao dịch.'
      });
    }

    // 7. Gọi API nhà mạng (Bước 14 & E4, E5)
    var mockCarrier = req.headers['x-mock-carrier'] || req.body.mockCarrier;
    if (mockCarrier === 'timeout' || mockCarrier === 'network_error') {
      return res.status(504).json({
        code: 'CARRIER_TIMEOUT',
        error: 'Không thể xử lý giao dịch. Vui lòng thử lại sau.'
      });
    }
    if (mockCarrier === 'failed') {
      return res.status(502).json({
        code: 'CARRIER_FAILED',
        error: 'Giao dịch không thành công. Vui lòng thử lại.'
      });
    }

    // 8. Cập nhật số dư ví sau khi thành công (Bước 16)
    user.walletBalance -= amount;
    await user.save();

    // 9. Lưu thông tin giao dịch vào lịch sử giao dịch (Bước 17)
    var defaultNote = isData
      ? 'Nạp gói Data ' + pkg.name + ' (' + normalizedCarrier + ') cho ' + phoneNumber
      : 'Nạp tiền điện thoại ' + normalizedCarrier + ' ' + amount.toLocaleString('vi-VN') + 'đ cho ' + phoneNumber;

    var transaction = await Transaction.create({
      transactionCode: code(),
      userId: user._id,
      account: user.email,
      type: type,
      amount: amount,
      sender: user.name || user.email,
      recipient: phoneNumber,
      status: 'completed',
      note: req.body.note || defaultNote,
      metadata: {
        carrier: normalizedCarrier,
        serviceType: type,
        phoneNumber: phoneNumber,
        denomination: amount,
        dataPackage: isData ? pkg.name : null,
        dataVolume: isData ? pkg.data : null,
        duration: isData ? pkg.duration : null
      }
    });

    // 10. Trả về thông báo thành công (Bước 18)
    res.status(200).json({
      success: true,
      message: 'Giao dịch thành công',
      transaction: transaction,
      walletBalance: user.walletBalance
    });
  };
};

// Danh sách hóa đơn mẫu cho 4 loại dịch vụ (mô phỏng API đối tác)
var MOCK_BILLS = [
  // Điện (EVN)
  { customerCode: 'EVN001', billType: 'Điện', customerName: 'Nguyễn Văn A', provider: 'Điện lực TP.HCM (EVN)', period: 'Tháng 9/2026', amount: 350000, fee: 0 },
  { customerCode: 'EVN002', billType: 'Điện', customerName: 'Trần Thị B', provider: 'Điện lực Hà Nội (EVN)', period: 'Tháng 9/2026', amount: 280000, fee: 0 },
  { customerCode: 'EVN003', billType: 'Điện', customerName: 'Lê Văn C', provider: 'Điện lực Đà Nẵng (EVN)', period: 'Tháng 9/2026', amount: 195000, fee: 0 },
  // Nước
  { customerCode: 'WATER001', billType: 'Nước', customerName: 'Phạm Thị D', provider: 'Công ty Cấp nước TP.HCM', period: 'Tháng 9/2026', amount: 120000, fee: 5000 },
  { customerCode: 'WATER002', billType: 'Nước', customerName: 'Hoàng Văn E', provider: 'Công ty Cấp nước Hà Nội', period: 'Tháng 9/2026', amount: 85000, fee: 5000 },
  // Internet
  { customerCode: 'INET001', billType: 'Internet', customerName: 'Vũ Thị F', provider: 'Viettel Telecom', period: 'Tháng 10/2026', amount: 220000, fee: 0 },
  { customerCode: 'INET002', billType: 'Internet', customerName: 'Đặng Văn G', provider: 'VNPT VinaPhone', period: 'Tháng 10/2026', amount: 180000, fee: 0 },
  { customerCode: 'INET003', billType: 'Internet', customerName: 'Bùi Thị H', provider: 'FPT Telecom', period: 'Tháng 10/2026', amount: 250000, fee: 0 },
  // Bảo hiểm
  { customerCode: 'INS001', billType: 'Bảo hiểm', customerName: 'Ngô Văn I', provider: 'Bảo hiểm Bảo Việt', period: 'Kỳ Quý 4/2026', amount: 1500000, fee: 10000 },
  { customerCode: 'INS002', billType: 'Bảo hiểm', customerName: 'Trịnh Thị K', provider: 'Prudential Việt Nam', period: 'Tháng 10/2026', amount: 850000, fee: 10000 },
  // QR mã hóa (dùng cho thanh toán QR)
  { customerCode: 'QR_EVN001', billType: 'Điện', customerName: 'Lý Văn L', provider: 'Điện lực Bình Dương (EVN)', period: 'Tháng 9/2026', amount: 310000, fee: 0 },
  { customerCode: 'QR_WATER001', billType: 'Nước', customerName: 'Phùng Thị M', provider: 'Công ty Cấp nước Bình Dương', period: 'Tháng 9/2026', amount: 95000, fee: 5000 },
];

/**
 * 2.1.7. Chức năng Thanh toán hóa đơn (Use Case 07 - Cao Thái Tuấn)
 * Bước 8: Gọi API đối tác để lấy thông tin hóa đơn
 */
exports.getBillInfo = async function(req, res) {
  var paymentMethod = String(req.body.paymentMethod || '').trim();
  var billType = String(req.body.billType || '').trim();
  var customerCode = String(req.body.customerCode || '').trim();
  var qrData = req.body.qrData ? String(req.body.qrData).trim() : null;

  if (paymentMethod === 'direct' && !customerCode) {
    return res.status(400).json({
      code: 'EMPTY_CUSTOMER_CODE',
      error: 'Mã khách hàng/Mã hóa đơn không được để trống.'
    });
  }

  if (paymentMethod === 'qr') {
    if (!qrData) {
      return res.status(400).json({ code: 'INVALID_QR', error: 'Mã QR không hợp lệ hoặc không thể giải mã.' });
    }
    if (!qrData.startsWith('QR_')) {
      return res.status(400).json({ code: 'INVALID_QR', error: 'Mã QR không hợp lệ hoặc không thể giải mã.' });
    }
    customerCode = qrData;
  }

  var mockPartner = req.headers['x-mock-partner'] || req.body.mockPartner;
  if (mockPartner === 'timeout' || mockPartner === 'network_error') {
    return res.status(504).json({ code: 'PARTNER_TIMEOUT', error: 'Không thể kết nối đến hệ thống đối tác. Vui lòng thử lại sau.' });
  }

  var bill = MOCK_BILLS.find(function(b) {
    var codeMatch = b.customerCode.toLowerCase() === customerCode.toLowerCase();
    var typeMatch = !billType || b.billType.toLowerCase() === billType.toLowerCase();
    return codeMatch && typeMatch;
  });

  if (!bill) {
    return res.status(404).json({ code: 'BILL_NOT_FOUND', error: 'Không tìm thấy thông tin hóa đơn. Vui lòng kiểm tra lại mã khách hàng.' });
  }

  res.json({
    success: true,
    bill: { customerCode: bill.customerCode, billType: bill.billType, customerName: bill.customerName, provider: bill.provider, period: bill.period, amount: bill.amount, fee: bill.fee, totalAmount: bill.amount + bill.fee }
  });
};

/**
 * 2.1.7. Chức năng Thanh toán hóa đơn - Bước 14: Xử lý thanh toán
 */
exports.payBill = async function(req, res) {
  var paymentMethod = String(req.body.paymentMethod || '').trim();
  var billType = String(req.body.billType || '').trim();
  var customerCode = String(req.body.customerCode || '').trim();
  var qrData = req.body.qrData ? String(req.body.qrData).trim() : null;
  var content = req.body.content ? String(req.body.content).trim() : null;

  if (paymentMethod === 'direct' && !customerCode) {
    return res.status(400).json({ code: 'EMPTY_CUSTOMER_CODE', error: 'Mã khách hàng/Mã hóa đơn không được để trống.' });
  }

  if (paymentMethod === 'qr') {
    if (!qrData) {
      return res.status(400).json({ code: 'INVALID_QR', error: 'Mã QR không hợp lệ hoặc không thể giải mã.' });
    }
    if (!qrData.startsWith('QR_')) {
      return res.status(400).json({ code: 'INVALID_QR', error: 'Mã QR không hợp lệ hoặc không thể giải mã.' });
    }
    customerCode = qrData;
  }

  var mockPartner = req.headers['x-mock-partner'] || req.body.mockPartner;
  if (mockPartner === 'timeout' || mockPartner === 'network_error') {
    return res.status(504).json({ code: 'PARTNER_TIMEOUT', error: 'Không thể kết nối đến hệ thống đối tác. Vui lòng thử lại sau.' });
  }

  var bill = MOCK_BILLS.find(function(b) {
    var codeMatch = b.customerCode.toLowerCase() === customerCode.toLowerCase();
    var typeMatch = !billType || b.billType.toLowerCase() === billType.toLowerCase();
    return codeMatch && typeMatch;
  });

  if (!bill) {
    return res.status(404).json({ code: 'BILL_NOT_FOUND', error: 'Không tìm thấy thông tin hóa đơn. Vui lòng kiểm tra lại mã khách hàng.' });
  }

  var totalAmount = bill.amount + bill.fee;

  var user = await verifyPin(req, res);
  if (!user) return;

  if (user.walletBalance < totalAmount) {
    return res.status(400).json({ code: 'INSUFFICIENT_BALANCE', error: 'Số dư không đủ để thực hiện giao dịch.' });
  }

  user.walletBalance -= totalAmount;
  await user.save();

  var defaultNote = 'Thanh toán ' + bill.billType + ' - ' + bill.provider + ' kỳ ' + bill.period;
  var transaction = await Transaction.create({
    transactionCode: code(),
    userId: user._id,
    account: user.email,
    type: 'bill_payment',
    amount: totalAmount,
    sender: user.name || user.email,
    recipient: bill.provider,
    status: 'completed',
    note: content || defaultNote,
    metadata: {
      paymentMethod: paymentMethod,
      billType: bill.billType,
      customerCode: bill.customerCode,
      customerName: bill.customerName,
      provider: bill.provider,
      period: bill.period,
      billAmount: bill.amount,
      fee: bill.fee,
      totalAmount: totalAmount,
      hasQr: paymentMethod === 'qr'
    }
  });

  res.status(200).json({
    success: true,
    message: 'Thanh toán thành công',
    transaction: transaction,
    walletBalance: user.walletBalance,
    bill: { customerCode: bill.customerCode, billType: bill.billType, customerName: bill.customerName, provider: bill.provider, period: bill.period, amount: bill.amount, fee: bill.fee, totalAmount: totalAmount }
  });
};

exports.MOCK_BILLS = MOCK_BILLS;

async function verifyPin(req, res) {
  var user = await User.findById(req.user.id).select('+passwordHash +pinHash');
  if (!user) {
    res.status(404).json({ error: 'Người dùng không tồn tại' });
    return null;
  }

  var pin = String(req.body.pin || '').trim();
  if (!pin || !/^\d{4,6}$/.test(pin)) {
    res.status(400).json({ code: 'INVALID_PIN_FORMAT', error: 'Mã PIN bắt buộc gồm 6 chữ số' });
    return null;
  }

  var userId = user._id.toString();
  var record = pinAttempts.get(userId) || { count: 0, lockedUntil: 0 };

  if (record.lockedUntil && record.lockedUntil > Date.now()) {
    res.status(423).json({
      code: 'PIN_LOCKED',
      error: 'Nhập sai mã PIN quá 3 lần. Giao dịch đã bị hủy và khóa xác thực giao dịch tạm thời.'
    });
    return null;
  }

  // Tự động đồng bộ PIN nếu người dùng chưa cài pinHash (dùng mật khẩu mặc định 123456 nếu đúng)
  var userPinHash = user.pinHash;
  if (!userPinHash) {
    if (user.password === '123456' && pin === '123456') {
      user.pinHash = await bcrypt.hash('123456', 10);
      await user.save();
      userPinHash = user.pinHash;
    } else {
      res.status(400).json({ code: 'PIN_NOT_SET', error: 'Vui lòng thiết lập mã PIN 6 số trước khi thực hiện giao dịch' });
      return null;
    }
  }

  var isMatch = await bcrypt.compare(pin, userPinHash);
  if (!isMatch) {
    record.count += 1;
    if (record.count >= 3) {
      record.lockedUntil = Date.now() + 5 * 60 * 1000;
      pinAttempts.set(userId, record);
      res.status(401).json({
        code: 'PIN_LOCKED',
        error: 'Nhập sai mã PIN quá 3 lần. Giao dịch đã bị hủy và khóa xác thực giao dịch tạm thời.'
      });
      return null;
    } else {
      pinAttempts.set(userId, record);
      res.status(401).json({
        code: 'WRONG_PIN',
        error: 'PIN không chính xác.',
        remainingAttempts: 3 - record.count
      });
      return null;
    }
  }

  pinAttempts.delete(userId);
  return user;
}

async function createPaymentIntent(user, amount, details) {
  return Transaction.create({
    transactionCode: code(), userId: user.id, account: user.email,
    type: details.type, amount: amount, sender: user.email,
    recipient: details.recipient, note: details.note,
    status: 'pending', metadata: details.metadata
  });
}

function code() { return 'TX-' + crypto.randomUUID(); }

exports._resetPinAttempts = function(userId) {
  if (userId) pinAttempts.delete(String(userId));
  else pinAttempts.clear();
};
exports.DATA_PACKAGES = DATA_PACKAGES;