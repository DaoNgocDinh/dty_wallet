var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var wallet = require('../controller/walletController');

router.get('/', requireAuth, asyncHandler(wallet.balance));
router.get('/data-packages', asyncHandler(wallet.getDataPackages));
router.post('/deposits', requireAuth, asyncHandler(wallet.depositIntent));
router.post('/topups/mobile', requireAuth, asyncHandler(wallet.mobileTopup('mobile_topup')));
router.post('/topups/data', requireAuth, asyncHandler(wallet.mobileTopup('data_topup')));
router.post('/bill-payments', requireAuth, asyncHandler(wallet.payBill));

module.exports = router;
