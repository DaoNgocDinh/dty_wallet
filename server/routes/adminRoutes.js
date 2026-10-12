var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var requireAdmin = require('../middleware/admin');
var admin = require('../controller/adminController');

router.get('/users', requireAuth, requireAdmin, asyncHandler(admin.listUsers));

module.exports = router;
