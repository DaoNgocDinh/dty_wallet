var mongoose = require('mongoose');

module.exports = async function connectDatabase() {
  var uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/app_nhom11';
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
  console.log('Connected to MongoDB');
  return mongoose.connection;
};