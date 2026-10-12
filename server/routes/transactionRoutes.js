var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var transactions = require('../controller/transactionController');

router.get('/history', requireAuth, asyncHandler(transactions.history));
router.get('/', requireAuth, asyncHandler(transactions.search));

module.exports = router;
