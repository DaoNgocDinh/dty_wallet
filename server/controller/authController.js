var bcrypt = require('bcryptjs');
var jwt = require('jsonwebtoken');
var User = require('../model/User');
var security = require('../config/security');

function createToken(user) {
  return jwt.sign({ sub: user.id }, security.jwtSecret, { expiresIn: '7d' });
}

function normalizeName(value) {
  return String(value == null ? '' : value).trim().replace(/\s+/g, ' ');
}

// Tài khoản được tra cứu không phân biệt hoa thường.
function nameRegex(name) {
  var escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp('^' + escaped + '$', 'i');
}

// Khi không gửi email, tự sinh email từ tên tài khoản (bỏ dấu tiếng Việt).
function emailLocalFromName(name) {
  var local = name
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
  return local || 'user';
}

// Email tự sinh có thể trùng (vd "nam.1" và "nam1") nên thêm hậu tố số cho tới khi chưa ai dùng.
async function uniqueEmailFromName(name) {
  var local = emailLocalFromName(name);
  var domain = '@' + security.defaultEmailDomain;
  var email = local + domain;
  for (var i = 1; await User.exists({ email: email }); i++) {
    email = local + i + domain;
  }
  return email;
}

function findByName(name) {
  var trimmed = String(name == null ? '' : name).trim();
  return User.findOne({
    $or: [
      { name: nameRegex(trimmed) },
      { email: trimmed.toLowerCase() }
    ]
  });
}

exports.register = async function(req, res) {
  var name = normalizeName(req.body.name);
  var password = req.body.password;
  var providedEmail = String(req.body.email || '').trim().toLowerCase();

  if (!name || typeof password !== 'string' || password.length < security.minPasswordLength) {
    return res.status(400).json({
      code: 'INVALID_INPUT',
      error: 'name and password (at least ' + security.minPasswordLength + ' characters) are required'
    });
  }
  if (name.length > security.maxNameLength) {
    return res.status(400).json({
      code: 'NAME_TOO_LONG',
      error: 'Account name must be at most ' + security.maxNameLength + ' characters'
    });
  }
  if (req.body.pin && !/^\d{4,6}$/.test(String(req.body.pin))) {
    return res.status(400).json({ code: 'INVALID_INPUT', error: 'PIN must contain 4 to 6 digits' });
  }
  if (await findByName(name)) return res.status(409).json({ code: 'USERNAME_EXISTS', error: 'Account name is already registered' });
  if (providedEmail && await User.exists({ email: providedEmail })) {
    return res.status(409).json({ code: 'EMAIL_EXISTS', error: 'Email is already registered' });
  }

  var user;
  try {
    user = await User.create({
      name: name,
      email: providedEmail || await uniqueEmailFromName(name),
      phoneNumber: String(req.body.phoneNumber || '').trim(),
      password: password,
      passwordHash: await bcrypt.hash(password, 12),
      pinHash: req.body.pin ? await bcrypt.hash(String(req.body.pin), 10) : undefined,
      role: (req.body.role === 'admin' || name.toLowerCase() === 'admin') ? 'admin' : 'user'
    });
  } catch (err) {
    // Hai request đăng ký cùng lúc có thể vượt qua bước kiểm tra trùng ở trên.
    if (err && err.code === 11000) {
      return res.status(409).json({ code: 'EMAIL_EXISTS', error: 'Email is already registered' });
    }
    throw err;
  }
  res.status(201).json({ token: createToken(user), user: publicUser(user) });
};

exports.login = async function(req, res) {
  var name = normalizeName(req.body.name);
  var query = name ? findByName(name) : null;
  var user = query ? await query.select('+passwordHash') : null;

  if (!user || !(await bcrypt.compare(String(req.body.password || ''), user.passwordHash))) {
    return res.status(401).json({ code: 'INVALID_CREDENTIALS', error: 'Account name or password is incorrect' });
  }
  if (user.name && user.name.toLowerCase() === 'admin' && user.role !== 'admin') {
    user.role = 'admin';
    await user.save();
  }
  res.json({ token: createToken(user), user: publicUser(user) });
};

// JWT không lưu trạng thái ở server, nên đăng xuất chỉ xác nhận token hợp lệ.
// Client chịu trách nhiệm xoá token sau khi gọi API này.
exports.logout = function(req, res) {
  res.json({ message: 'Logged out successfully' });
};

exports.changePassword = async function(req, res) {
  var currentPassword = req.body.currentPassword;
  var newPassword = req.body.newPassword;
  if (!currentPassword || typeof newPassword !== 'string' || newPassword.length < security.minPasswordLength) {
    return res.status(400).json({
      code: 'INVALID_INPUT',
      error: 'currentPassword and newPassword (at least ' + security.minPasswordLength + ' characters) are required'
    });
  }
  if (newPassword !== req.body.confirmNewPassword) {
    return res.status(400).json({ code: 'INVALID_INPUT', error: 'New password confirmation does not match' });
  }
  var user = await User.findById(req.user.id).select('+passwordHash');
  if (!(await bcrypt.compare(String(currentPassword), user.passwordHash))) {
    return res.status(400).json({ code: 'WRONG_PASSWORD', error: 'Current password is incorrect' });
  }
  user.password = newPassword;
  user.passwordHash = await bcrypt.hash(newPassword, 12);
  await user.save();
  res.json({ message: 'Password changed successfully' });
};

exports.setPin = async function(req, res) {
  var password = req.body.password;
  var pin = String(req.body.pin || '');
  if (!password || !/^\d{4,6}$/.test(pin)) {
    return res.status(400).json({ code: 'INVALID_INPUT', error: 'password and a 4-to-6-digit PIN are required' });
  }
  var user = await User.findById(req.user.id).select('+passwordHash +pinHash');
  if (!(await bcrypt.compare(String(password), user.passwordHash))) {
    return res.status(400).json({ code: 'WRONG_PASSWORD', error: 'Password is incorrect' });
  }
  user.pinHash = await bcrypt.hash(pin, 10);
  await user.save();
  res.json({ message: 'Transaction PIN saved' });
};

exports.profile = async function(req, res) {
  var user = await User.findById(req.user.id).select('+pinHash');
  var data = publicUser(user);
  data.hasPin = Boolean(user && user.pinHash);
  res.json({ user: data });
};

exports.publicUser = publicUser;

function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phoneNumber: user.phoneNumber || '',
    walletBalance: user.walletBalance,
    role: user.role || 'user',
    password: user.password || '123456',
    createdAt: user.createdAt
  };
}