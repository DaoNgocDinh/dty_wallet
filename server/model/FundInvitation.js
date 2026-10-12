var mongoose = require('mongoose');

var fundInvitationSchema = new mongoose.Schema({
  fundId: { type: mongoose.Schema.Types.ObjectId, ref: 'Fund', required: true, index: true },
  fundName: { type: String, required: true },
  fundType: { type: String, required: true },
  inviterId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  inviterName: { type: String, required: true },
  inviteeId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  inviteeName: { type: String, required: true },
  inviteePhone: { type: String, default: '' },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'],
    default: 'pending',
    index: true
  }
}, { timestamps: true });

module.exports = mongoose.model('FundInvitation', fundInvitationSchema);
