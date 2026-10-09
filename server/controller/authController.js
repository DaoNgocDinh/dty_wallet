var bcrypt = require('bcryptjs');
var jwt = require('jsonwebtoken');
var User = require('../model/User');
var security = require('../config/security');

function createToken(user) {
  return jwt.sign({ sub: user.id }, security.jwtSecret, { expiresIn: '7d' });
}

exports.register = async function(req, res) {
  var name = String(req.body.name || '').trim();
  var email = String(req.body.email || '').trim().toLowerCase();
  var password = req.body.password;
  if (!name || !email || typeof password !== 'string' || password.length < 8) {
    return res.status(400).json({ error: 'name, valid email, and password (at least 8 characters) are required' });
  }
  if (req.body.pin && !/^\d{4,6}$/.test(String(req.body.pin))) {
    return res.status(400).json({ error: 'PIN must contain 4 to 6 digits' });
  }
  if (await User.exists({ email: email })) return res.status(409).json({ error: 'Email is already registered' });

  var user = await User.create({
    name: name,
    email: email,
    passwordHash: await bcrypt.hash(password, 12),
    pinHash: req.body.pin ? await bcrypt.hash(String(req.body.pin), 10) : undefined
  });
  res.status(201).json({ token: createToken(user), user: publicUser(user) });
};

exports.login = async function(req, res) {
  var email = String(req.body.email || '').trim().toLowerCase();
  var user = await User.findOne({ email: email }).select('+passwordHash');
  if (!user || !(await bcrypt.compare(String(req.body.password || ''), user.passwordHash))) {
    return res.status(401).json({ error: 'Email or password is incorrect' });
  }
  res.json({ token: createToken(user), user: publicUser(user) });
};

exports.changePassword = async function(req, res) {
  var currentPassword = req.body.currentPassword;
  var newPassword = req.body.newPassword;
  if (!currentPassword || typeof newPassword !== 'string' || newPassword.length < 8) {
    return res.status(400).json({ error: 'currentPassword and newPassword (at least 8 characters) are required' });
  }
  if (newPassword !== req.body.confirmNewPassword) {
    return res.status(400).json({ error: 'New password confirmation does not match' });
  }
  var user = await User.findById(req.user.id).select('+passwordHash');
  if (!(await bcrypt.compare(String(currentPassword), user.passwordHash))) {
    return res.status(400).json({ error: 'Current password is incorrect' });
  }
  user.passwordHash = await bcrypt.hash(newPassword, 12);
  await user.save();
  res.json({ message: 'Password changed successfully' });
};

exports.setPin = async function(req, res) {
  var password = req.body.password;
  var pin = String(req.body.pin || '');
  if (!password || !/^\d{4,6}$/.test(pin)) {
    return res.status(400).json({ error: 'password and a 4-to-6-digit PIN are required' });
  }
  var user = await User.findById(req.user.id).select('+passwordHash +pinHash');
  if (!(await bcrypt.compare(String(password), user.passwordHash))) {
    return res.status(400).json({ error: 'Password is incorrect' });
  }
  user.pinHash = await bcrypt.hash(pin, 10);
  await user.save();
  res.json({ message: 'Transaction PIN saved' });
};

exports.publicUser = publicUser;

function publicUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    walletBalance: user.walletBalance,
    createdAt: user.createdAt
  };
}