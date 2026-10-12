// Tạo tài khoản admin và các tài khoản mẫu cho Use Case 06 (Mời thành viên)
require('dotenv').config();

var bcrypt = require('bcryptjs');
var connectDatabase = require('./index');
var User = require('../model/User');
var Fund = require('../model/Fund');

var SEED_USERS = [
  {
    name: process.env.ADMIN_NAME || 'admin',
    email: process.env.ADMIN_EMAIL || 'admin@gmail.com',
    phoneNumber: '0901234567',
    password: process.env.ADMIN_PASSWORD || '123456',
    walletBalance: Number(process.env.ADMIN_WALLET_BALANCE || 1000000),
    role: 'admin'
  },
  {
    name: 'Đào Ngọc Đình',
    email: 'dinh@gmail.com',
    phoneNumber: '0988888888',
    password: '123456',
    walletBalance: 2000000,
    role: 'user'
  },
  {
    name: 'Trần Văn B',
    email: 'tranvanb@gmail.com',
    phoneNumber: '0912345678',
    password: '123456',
    walletBalance: 1500000,
    role: 'user'
  },
  {
    name: 'Lê Văn D',
    email: 'levand@gmail.com',
    phoneNumber: '0987654321',
    password: '123456',
    walletBalance: 800000,
    role: 'user'
  },
  {
    name: 'Phạm Văn E',
    email: 'phamvane@gmail.com',
    phoneNumber: '0911223344',
    password: '123456',
    walletBalance: 500000,
    role: 'user'
  }
];

async function seed() {
  await connectDatabase();

  for (var u of SEED_USERS) {
    var passwordHash = await bcrypt.hash(u.password, 12);
    var existing = await User.findOne({ email: u.email });
    if (existing) {
      existing.name = u.name;
      existing.phoneNumber = u.phoneNumber;
      existing.passwordHash = passwordHash;
      existing.walletBalance = u.walletBalance;
      existing.role = u.role || 'user';
      await existing.save();
      console.log('Updated user:', u.name, '(' + u.email + ')');
    } else {
      await User.create({
        name: u.name,
        email: u.email,
        phoneNumber: u.phoneNumber,
        passwordHash: passwordHash,
        walletBalance: u.walletBalance,
        role: u.role || 'user'
      });
      console.log('Created user:', u.name, '(' + u.email + ')');
    }
  }

  await User.db.close();
  console.log('Seed completed successfully!');
}

seed().catch(function(error) {
  console.error('Seed failed:', error.message);
  process.exit(1);
});