var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var auth = require('../controller/authController');
var transactions = require('../controller/transactionController');
var funds = require('../controller/fundController');
var wallet = require('../controller/walletController');
var jars = require('../controller/spendingJarController');

router.get('/health', function(req, res) {
  res.json({ status: 'ok', database: require('mongoose').connection.readyState === 1 ? 'connected' : 'disconnected' });
});

router.post('/auth/register', asyncHandler(auth.register));
router.post('/auth/login', asyncHandler(auth.login));
router.post('/auth/change-password', requireAuth, asyncHandler(auth.changePassword));
router.put('/auth/pin', requireAuth, asyncHandler(auth.setPin));

router.get('/transactions/history', requireAuth, asyncHandler(transactions.history));
router.get('/transactions', requireAuth, asyncHandler(transactions.search));

router.get('/funds', requireAuth, asyncHandler(funds.list));
router.post('/funds', requireAuth, asyncHandler(funds.create));
router.post('/funds/:id/contributions', requireAuth, asyncHandler(funds.contribute));

router.get('/wallet', requireAuth, asyncHandler(wallet.balance));
router.post('/wallet/deposits', requireAuth, asyncHandler(wallet.depositIntent));
router.post('/wallet/topups/mobile', requireAuth, asyncHandler(wallet.mobileTopup('mobile_topup')));
router.post('/wallet/topups/data', requireAuth, asyncHandler(wallet.mobileTopup('data_topup')));
router.post('/wallet/bill-payments', requireAuth, asyncHandler(wallet.payBill));

router.get('/spending-jars', requireAuth, asyncHandler(jars.list));
router.post('/spending-jars', requireAuth, asyncHandler(jars.create));
router.get('/spending-jars/:id', requireAuth, asyncHandler(jars.details));

router.use(function(req, res) {
  res.status(404).json({ error: 'API endpoint not found' });
});

module.exports = router;