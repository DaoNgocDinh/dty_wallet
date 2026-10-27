```javascript
1:  exports.sendInvite = async function(req, res) {
2:    var fundId = req.params.id, inviteeId = req.body.inviteeId, inviteePhone = req.body.phoneNumber || req.body.phone, inviteeName = req.body.name;
      var fund = await Fund.findById(fundId);
      var coupleBlocked = await fundRules.checkCoupleFundCapacity(fund);
      var targetUser = null;
      var existingInvite = await FundInvitation.findOne({ fundId: fund._id, inviteeId: targetUser._id, status: 'pending' });
3:    if (!fund) {
4:      return res.status(404).json({ error: 'Quỹ không tồn tại' });}
5:    if (!isFundMember(fund, req.user.id)) {
6:      return res.status(403).json({ error: 'Bạn không phải là thành viên của quỹ', code: 'NOT_FUND_MEMBER' });}
7:    if (fund.fundType === 'Cá nhân') {
8:      return res.status(400).json({ error: 'Quỹ cá nhân không thể mời thành viên', code: 'PERSONAL_FUND_CANNOT_INVITE' });}
9:    if (coupleBlocked) {
10:     return res.status(coupleBlocked.status).json(coupleBlocked.body);}
11:   if (inviteeId) {
12:     targetUser = await User.findById(inviteeId);
13:   } else if (inviteePhone) {
14:     targetUser = await User.findOne({ phoneNumber: String(inviteePhone).trim() });
15:   } else if (inviteeName) {
16:     targetUser = await User.findOne({ name: String(inviteeName).trim() });}
17:   if (!targetUser) {
18:     return res.status(400).json({ error: 'Người dùng chưa đăng ký tài khoản ví điện tử hoặc không tồn tại', code: 'USER_NOT_FOUND' });}
19:   if (targetUser._id.toString() === req.user.id.toString()) {
20:     return res.status(400).json({ error: 'Bạn không thể tự mời chính mình', code: 'CANNOT_INVITE_SELF' });}
21:   if (targetUser.role === 'admin' || (targetUser.name && targetUser.name.toLowerCase() === 'admin')) {
22:     return res.status(400).json({ error: 'Không thể mời tài khoản quản trị viên vào quỹ', code: 'CANNOT_INVITE_ADMIN' });}
23:   if (isFundMember(fund, targetUser._id)) {
24:     return res.status(400).json({ error: 'Người dùng đã là thành viên của quỹ', code: 'ALREADY_MEMBER' });}
25:   if (existingInvite) {
26:     return res.status(400).json({ error: 'Người dùng đã có lời mời tham gia quỹ', code: 'PENDING_INVITATION_EXISTS' });}};