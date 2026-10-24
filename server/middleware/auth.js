var jwt = require('jsonwebtoken');
var User = require('../model/User');
var security = require('../config/security');

module.exports = async function requireAuth(req, res, next) {
  try {
    var header = req.headers.authorization || '';
    var token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'Yêu cầu mã xác thực Bearer token' });

    var payload = jwt.verify(token, security.jwtSecret);
    var user = await User.findById(payload.sub).select('-passwordHash -pinHash');
    if (!user) return res.status(401).json({ error: 'Người dùng không còn tồn tại' });

    req.user = user;
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn' });
    }
    next(error);
  }
};