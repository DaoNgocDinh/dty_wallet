var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var auth = require('../controller/authController');

router.post('/register', asyncHandler(auth.register));
router.post('/login', asyncHandler(auth.login));
router.post('/logout', requireAuth, asyncHandler(auth.logout));
router.post('/change-password', requireAuth, asyncHandler(auth.changePassword));
router.put('/pin', requireAuth, asyncHandler(auth.setPin));
router.get('/me', requireAuth, asyncHandler(auth.profile));
router.get('/profile', requireAuth, asyncHandler(auth.profile));

module.exports = router;
