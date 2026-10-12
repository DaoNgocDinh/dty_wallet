var express = require('express');
var router = express.Router();
var asyncHandler = require('../middleware/asyncHandler');
var requireAuth = require('../middleware/auth');
var jars = require('../controller/spendingJarController');

router.get('/', requireAuth, asyncHandler(jars.list));
router.post('/', requireAuth, asyncHandler(jars.create));
router.get('/:id', requireAuth, asyncHandler(jars.details));

module.exports = router;
