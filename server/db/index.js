var mongoose = require('mongoose');
var bcrypt = require('bcryptjs');

async function ensureAdminAccount() {
  try {
    var User = require('../model/User');
    var existingAdmin = await User.findOne({
      $or: [
        { name: /^admin$/i },
        { email: 'admin@gmail.com' },
        { role: 'admin' }
      ]
    });

    if (!existingAdmin) {
      var passwordHash = await bcrypt.hash('123456', 12);
      var admin = await User.create({
        name: 'admin',
        email: 'admin@gmail.com',
        phoneNumber: '0901234567',
        password: '123456',
        passwordHash: passwordHash,
        walletBalance: 10000000,
        role: 'admin'
      });
      console.log('--- Đã tự động sinh tài khoản admin: tài khoản:admin, mật khẩu:123456, email:admin@gmail.com ---');
      return admin;
    }
    return existingAdmin;
  } catch (err) {
    console.error('Lỗi khi tự động khởi tạo tài khoản admin:', err.message);
  }
}

async function connectDatabase() {
  var uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/dty_wallet';
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
  console.log('Connected to MongoDB');
  await ensureAdminAccount();
  return mongoose.connection;
}

module.exports = connectDatabase;
module.exports.ensureAdminAccount = ensureAdminAccount;