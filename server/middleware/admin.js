module.exports = function requireAdmin(req, res, next) {
  if (req.user && req.user.role === 'admin') {
    return next();
  }
  return res.status(403).json({
    code: 'FORBIDDEN',
    error: 'Quyền quản trị viên (admin) là bắt buộc để truy cập tính năng này'
  });
};
