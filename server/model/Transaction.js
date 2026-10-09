var mongoose = require('mongoose');

var transactionSchema = new mongoose.Schema({
  transactionCode: { type: String, required: true, unique: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  account: { type: String, required: true },
  type: {
    type: String,
    required: true,
    enum: ['fund_contribution', 'jar_contribution', 'mobile_topup', 'data_topup', 'bill_payment', 'wallet_deposit']
  },
  amount: { type: Number, required: true, min: 0 },
  sender: { type: String, default: '' },
  recipient: { type: String, default: '' },
  status: { type: String, enum: ['pending', 'completed', 'failed'], default: 'completed', index: true },
  note: { type: String, trim: true, maxlength: 500 },
  metadata: { type: mongoose.Schema.Types.Mixed, default: {} }
}, { timestamps: true });

transactionSchema.index({ userId: 1, createdAt: -1 });
module.exports = mongoose.model('Transaction', transactionSchema);