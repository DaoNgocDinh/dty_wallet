var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var funds = require('../controller/fundController');
var invitations = require('../controller/invitationController');

// Quản lý Quỹ (CRUD, Góp tiền, Rút tiền & Rời quỹ)
router.get('/', requireAuth, asyncHandler(funds.list));
router.post('/', requireAuth, asyncHandler(funds.create));
// Danh sách người dùng để chọn làm người cùng lập quỹ cặp đôi (đặt trước /:id)
router.get('/partner-candidates', requireAuth, asyncHandler(funds.partnerCandidates));
router.get('/:id', requireAuth, asyncHandler(funds.details));
router.post('/:id/contributions', requireAuth, asyncHandler(funds.contribute));
router.post('/:id/withdraw', requireAuth, asyncHandler(funds.withdraw));
router.post('/:id/leave', requireAuth, asyncHandler(funds.leave));
router.delete('/:id', requireAuth, asyncHandler(funds.delete));

// Mời thành viên & Quản lý lời mời của quỹ (Use Case 06)
router.get('/:id/candidates', requireAuth, asyncHandler(invitations.getCandidates));
router.post('/:id/invitations', requireAuth, asyncHandler(invitations.sendInvite));
router.get('/:id/invitations', requireAuth, asyncHandler(invitations.listFundInvitations));

module.exports = router;
