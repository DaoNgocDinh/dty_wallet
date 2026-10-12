require('dotenv').config();
var bcrypt = require('bcryptjs');
var connectDatabase = require('./index');
var User = require('../model/User');

async function run() {
  await connectDatabase();
  console.log('Connected to MongoDB.');

  // Tìm tất cả các tài khoản có tên "admin" (không phân biệt hoa thường) hoặc email bắt đầu bằng admin@
  var filter = {
    $or: [
      { name: /^admin$/i },
      { email: /^admin@/i }
    ]
  };

  var adminUsers = await User.find(filter);
  console.log('Found matching accounts:', adminUsers.length);

  if (adminUsers.length > 0) {
    for (var u of adminUsers) {
      u.role = 'admin';
      await u.save();
      console.log('Updated user to role admin:', {
        id: u._id,
        name: u.name,
        email: u.email,
        phoneNumber: u.phoneNumber,
        role: u.role
      });
    }
  } else {
    // Nếu chưa có tài khoản admin, tạo mới
    var passwordHash = await bcrypt.hash('123456', 12);
    var newUser = await User.create({
      name: 'admin',
      email: 'admin@gmail.com',
      phoneNumber: '0901234567',
      passwordHash: passwordHash,
      walletBalance: 1000000,
      role: 'admin'
    });
    console.log('Created new admin account:', {
      id: newUser._id,
      name: newUser.name,
      email: newUser.email,
      role: newUser.role
    });
  }

  // Cập nhật bất kỳ tài khoản nào khác có tên chính xác là "admin"
  var nameRes = await User.updateMany({ name: /^admin$/i }, { $set: { role: 'admin' } });
  console.log('updateMany by name result:', nameRes);

  await User.updateMany({ password: { $exists: false } }, { $set: { password: '123456' } });
  await User.updateMany({ password: null }, { $set: { password: '123456' } });
  console.log('Updated passwords for all users to 123456');

  var allUsers = await User.find({}, { name: 1, email: 1, role: 1, password: 1, walletBalance: 1 });
  console.log('Current users in DB:', allUsers);

  await User.db.close();
  console.log('Done!');
}

run().catch(function(err) {
  console.error('Error:', err);
  process.exit(1);
});
