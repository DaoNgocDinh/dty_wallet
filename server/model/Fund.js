var mongoose = require('mongoose');

var fundSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  name: { type: String, required: true, trim: true, maxlength: 100 },
  fundType: { type: String, required: true, trim: true, maxlength: 50 },
  targetAmount: { type: Number, required: true, min: 0.01 },
  currentAmount: { type: Number, default: 0, min: 0 },
  completionDate: { type: Date }
}, { timestamps: true });

module.exports = mongoose.model('Fund', fundSchema);