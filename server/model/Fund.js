var mongoose = require('mongoose');

var fundSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  name: { type: String, required: true, trim: true, maxlength: 60 },
  fundType: {
    type: String,
    required: true,
    trim: true,
    enum: ['Cá nhân', 'Cặp đôi', 'Tích lũy', 'Hội nhóm']
  },
  targetAmount: { type: Number, min: 0, default: 0 },
  currentAmount: { type: Number, default: 0, min: 0 },
  completionDate: { type: Date },
  // 'active': quỹ đang hoạt động.
  // 'pending_partner': quỹ cặp đôi đã tạo nhưng chờ người được chọn đồng ý mới chính thức lập.
  status: {
    type: String,
    enum: ['active', 'pending_partner'],
    default: 'active',
    index: true
  },
  members: [{
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    role: { type: String, default: 'member', enum: ['owner', 'member'] },
    joinedAt: { type: Date, default: Date.now }
  }]
}, { timestamps: true });

module.exports = mongoose.model('Fund', fundSchema);