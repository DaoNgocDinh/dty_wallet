var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var invitations = require('../controller/invitationController');

// Lời mời cá nhân nhận được (Xem, Đồng ý, Từ chối)
router.get('/', requireAuth, asyncHandler(invitations.getMyInvitations));
router.post('/:id/accept', requireAuth, asyncHandler(invitations.acceptInvite));
router.post('/:id/reject', requireAuth, asyncHandler(invitations.rejectInvite));

module.exports = router;
