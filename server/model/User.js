var mongoose = require('mongoose');

var userSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 100 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  passwordHash: { type: String, required: true, select: false },
  pinHash: { type: String, select: false },
  walletBalance: { type: Number, default: 0, min: 0 }
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);