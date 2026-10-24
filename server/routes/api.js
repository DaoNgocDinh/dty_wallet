var express = require('express');
var router = express.Router();
var mongoose = require('mongoose');

// Route kiểm tra trạng thái hoạt động của hệ thống
router.get('/health', function(req, res) {
  res.json({
    status: 'ok',
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// Phân bổ các Router module theo từng miền nghiệp vụ rõ ràng
router.use('/auth', require('./authRoutes'));
router.use('/funds', require('./fundRoutes'));
router.use('/invitations', require('./invitationRoutes'));
router.use('/notifications', require('./notificationRoutes'));
router.use('/wallet', require('./walletRoutes'));
router.use('/admin', require('./adminRoutes'));
router.use('/spending-jars', require('./spendingJarRoutes'));
router.use('/transactions', require('./transactionRoutes'));
router.use('/features', require('./featureRoutes'));

// Bí danh tương thích ngược cho endpoint /users -> adminRoutes (/admin/users)
router.use('/users', require('./adminRoutes'));

// 404 Handler cho các API không tồn tại
router.use(function(req, res) {
  res.status(404).json({ error: 'Đường dẫn API không tồn tại' });
});

module.exports = router;