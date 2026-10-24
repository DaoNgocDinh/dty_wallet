var express = require('express');
var router = express.Router();
var jwt = require('jsonwebtoken');
var security = require('../config/security');
var User = require('../model/User');

// Danh mục toàn bộ dịch vụ và tính năng của DTY Wallet
var FEATURES = [
  {
    id: 'deposit',
    name: 'Nạp tiền vào ví',
    shortName: 'Nạp ví',
    description: 'Nạp tiền từ ngân hàng liên kết vào số dư ví DTY',
    category: 'Tài chính',
    icon: 'add_card',
    keywords: ['nap', 'nap tien', 'nap vi', 'tien', 'deposit', 'bank', 'ngan hang', 'so du', 'tai khoan']
  },
  {
    id: 'topup_phone',
    name: 'Nạp tiền điện thoại',
    shortName: 'Nạp ĐT',
    description: 'Nạp thẻ trực tiếp Viettel, VinaPhone, MobiFone, Vietnamobile',
    category: 'Viễn thông',
    icon: 'phone_iphone',
    keywords: ['nap dt', 'nap dien thoai', 'the cao', 'viettel', 'vinaphone', 'mobifone', 'vietnamobile', 'topup', 'phone']
  },
  {
    id: 'topup_data',
    name: 'Nạp Data 3G/4G/5G',
    shortName: 'Nạp Data',
    description: 'Đăng ký gói cước dung lượng Data internet di động tốc độ cao',
    category: 'Viễn thông',
    icon: 'data_usage',
    keywords: ['nap data', 'data', '4g', '3g', '5g', 'dung luong', 'mang', 'internet', 'goi cuoc']
  },
  {
    id: 'history',
    name: 'Lịch sử giao dịch',
    shortName: 'Lịch sử',
    description: 'Xem chi tiết biến động số dư, lịch sử nạp tiền, chi tiêu và chuyển tiền',
    category: 'Tài chính',
    icon: 'receipt_long',
    keywords: ['lich su', 'giao dich', 'bien dong so du', 'thu chi', 'sao ke', 'history', 'nhat ky']
  },
  {
    id: 'bill_payment',
    name: 'Thanh toán hoá đơn',
    shortName: 'Hoá đơn',
    description: 'Thanh toán hoá đơn điện lực EVN, nước sạch, cước internet',
    category: 'Tiện ích',
    icon: 'receipt',
    keywords: ['hoa don', 'dien', 'nuoc', 'internet', 'thanh toan hoa don', 'bill', 'dien luc', 'tien dien', 'tien nuoc']
  },
  {
    id: 'funds',
    name: 'Quản lý quỹ nhóm',
    shortName: 'Quỹ nhóm',
    description: 'Tạo quỹ chung, quản lý thành viên, góp quỹ và rút tiền minh bạch',
    category: 'Tài chính',
    icon: 'groups',
    keywords: ['quy', 'quan ly quy', 'tao quy', 'gop quy', 'quy nhom', 'quy cap doi', 'funds', 'tiet kiem']
  },
  {
    id: 'spending_jars',
    name: 'Hũ chi tiêu',
    shortName: 'Hũ chi tiêu',
    description: 'Phương pháp 6 hũ quản lý tài chính cá nhân thông minh',
    category: 'Tài chính',
    icon: 'all_inbox',
    keywords: ['hu chi tieu', 'hu', 'spending jars', '6 hu', 'tiet kiem', 'ngan sach', 'chi tieu']
  },
  {
    id: 'notifications',
    name: 'Thông báo',
    shortName: 'Thông báo',
    description: 'Xem tin tức hệ thống, thông báo biến động số dư và lời mời tham gia quỹ',
    category: 'Tiện ích',
    icon: 'notifications',
    keywords: ['thong bao', 'chuong', 'tin nhan', 'tin moi', 'notification', 'notifications']
  },
  {
    id: 'profile',
    name: 'Trang cá nhân & Cài đặt',
    shortName: 'Trang cá nhân',
    description: 'Xem thông tin tài khoản, cài đặt mã PIN và đổi mật khẩu ví',
    category: 'Tài khoản',
    icon: 'person',
    keywords: ['ca nhan', 'ho so', 'tai khoan', 'profile', 'user', 'doi mat khau', 'ma pin', 'dang xuat']
  },
  {
    id: 'admin_users',
    name: 'Quản lý tài khoản (Admin)',
    shortName: 'DS tài khoản',
    description: 'Xem danh sách tài khoản, phân quyền và quản lý hệ thống',
    category: 'Quản trị',
    icon: 'admin_panel_settings',
    keywords: ['admin', 'quan tri', 'danh sach tai khoan', 'nguoi dung', 'users'],
    adminOnly: true
  }
];

// Hàm chuẩn hoá chuỗi tiếng Việt (bỏ dấu, chuyển chữ thường) để tìm kiếm linh hoạt
function normalizeString(str) {
  if (!str) return '';
  return str
    .toString()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[đĐ]/g, 'd')
    .toLowerCase()
    .trim();
}

// Xử lý tìm kiếm tính năng
async function handleSearch(req, res) {
  try {
    var rawQuery = req.query.q || req.query.query || '';
    var q = normalizeString(rawQuery);

    // Xác định xem người gọi có phải là admin không (nếu có token)
    var isAdmin = false;
    var header = req.headers.authorization || '';
    var token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (token) {
      try {
        var payload = jwt.verify(token, security.jwtSecret);
        var user = await User.findById(payload.sub).select('role name');
        if (user && (user.role === 'admin' || (user.name && user.name.trim().toLowerCase() === 'admin'))) {
          isAdmin = true;
        }
      } catch (e) {
        // Token không hợp lệ thì coi như khách thường
      }
    }

    // Lọc tính năng theo quyền admin
    var available = FEATURES.filter(function(item) {
      if (item.adminOnly && !isAdmin) return false;
      return true;
    });

    // Nếu không có từ khóa tìm kiếm, trả về danh sách tất cả các tính năng khả dụng
    if (!q) {
      return res.json({
        success: true,
        query: rawQuery,
        count: available.length,
        features: available
      });
    }

    // Tìm kiếm tương đối theo tên, tên rút gọn, mô tả, danh mục và từ khóa
    var results = available.filter(function(item) {
      var nameNorm = normalizeString(item.name);
      var shortNorm = normalizeString(item.shortName);
      var descNorm = normalizeString(item.description);
      var catNorm = normalizeString(item.category);

      if (nameNorm.includes(q) || shortNorm.includes(q) || descNorm.includes(q) || catNorm.includes(q)) {
        return true;
      }

      if (Array.isArray(item.keywords)) {
        return item.keywords.some(function(k) {
          return normalizeString(k).includes(q) || q.includes(normalizeString(k));
        });
      }

      return false;
    });

    res.json({
      success: true,
      query: rawQuery,
      count: results.length,
      features: results
    });
  } catch (err) {
    res.status(500).json({ error: 'Lỗi máy chủ khi tìm kiếm tính năng' });
  }
}

router.get('/search', handleSearch);
router.get('/', handleSearch);

module.exports = router;
