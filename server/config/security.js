var crypto = require('crypto');

module.exports = {
  jwtSecret: process.env.JWT_SECRET || crypto.randomBytes(32).toString('hex'),
  // Độ dài tối thiểu của mật khẩu (áp dụng cho đăng ký và đổi mật khẩu).
  minPasswordLength: Number(process.env.MIN_PASSWORD_LENGTH || 6),
  changePasswordMinLength: 8,
  changePasswordMaxLength: 20,
  // Độ dài tối đa của tên tài khoản (khớp với maxlength trong model User).
  maxNameLength: 100,
  // Email được sinh tự động khi đăng ký không gửi email.
  defaultEmailDomain: 'gmail.com'
};