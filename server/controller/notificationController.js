var Notification = require('../model/Notification');

// Lấy danh sách thông báo và số lượng chưa đọc
exports.list = async function(req, res) {
  var notifications = await Notification.find({ userId: req.user.id })
    .sort({ createdAt: -1 })
    .limit(50);

  var unreadCount = await Notification.countDocuments({
    userId: req.user.id,
    isRead: false
  });

  res.json({
    unreadCount: unreadCount,
    count: notifications.length,
    data: notifications
  });
};

// Đánh dấu một thông báo đã đọc
exports.markRead = async function(req, res) {
  var id = req.params.id;
  var notification = await Notification.findOneAndUpdate(
    { _id: id, userId: req.user.id },
    { isRead: true },
    { new: true }
  );

  if (!notification) {
    return res.status(404).json({ error: 'Thông báo không tồn tại' });
  }

  var unreadCount = await Notification.countDocuments({
    userId: req.user.id,
    isRead: false
  });

  res.json({
    message: 'Đã đánh dấu đã đọc',
    notification: notification,
    unreadCount: unreadCount
  });
};

// Đánh dấu tất cả thông báo là đã đọc
exports.markAllRead = async function(req, res) {
  await Notification.updateMany(
    { userId: req.user.id, isRead: false },
    { isRead: true }
  );

  res.json({
    message: 'Đã đánh dấu tất cả thông báo là đã đọc',
    unreadCount: 0
  });
};
