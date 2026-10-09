var mongoose = require('mongoose');

var spendingJarSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  name: { type: String, required: true, trim: true, maxlength: 100 },
  balance: { type: Number, default: 0, min: 0 }
}, { timestamps: true });

module.exports = mongoose.model('SpendingJar', spendingJarSchema);