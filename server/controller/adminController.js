var User = require('../model/User');
var authController = require('./authController');

exports.listUsers = async function(req, res) {
  var search = String(req.query.search || '').trim();
  var filter = {};
  if (search) {
    var escaped = search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var regex = new RegExp(escaped, 'i');
    filter.$or = [
      { name: regex },
      { email: regex },
      { phoneNumber: regex },
      { role: regex }
    ];
  }
  var users = await User.find(filter).select('+password').sort({ createdAt: -1 });
  res.json({
    data: users.map(function(u) {
      var item = authController.publicUser(u);
      item.password = u.password || '123456';
      return item;
    }),
    total: users.length
  });
};
