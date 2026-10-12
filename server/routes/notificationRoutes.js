var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var notifications = require('../controller/notificationController');

router.get('/', requireAuth, asyncHandler(notifications.list));
router.put('/:id/read', requireAuth, asyncHandler(notifications.markRead));
router.put('/read-all', requireAuth, asyncHandler(notifications.markAllRead));

module.exports = router;
