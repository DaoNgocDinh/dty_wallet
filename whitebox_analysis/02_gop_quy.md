```javascript
1:  exports.contribute = async function(req, res) {
2:    var rawAmount = req.body.amount, amountStr = String(rawAmount || '').trim().replace(/,/g, ''), amount = Number(amountStr);
      var note = String(req.body.note || '').trim();
      var fund = await Fund.findOne({ _id: req.params.id, $or: [{ userId: req.user.id }, { 'members.userId': req.user.id }] });
      var user = await User.findById(req.user.id);
      var debited = await User.findOneAndUpdate({ _id: user.id, walletBalance: { $gte: amount } }, { $inc: { walletBalance: -amount } });
3:    if (rawAmount === undefined || rawAmount === null || String(rawAmount).trim() === '') {
4:      return res.status(400).json({ error: 'Vui lòng nhập số tiền muốn góp', code: 'AMOUNT_REQUIRED' });}
5:    if (!/^\d+(\.\d+)?$/.test(amountStr)) {
6:      return res.status(400).json({ error: 'Số tiền không hợp lệ', code: 'INVALID_AMOUNT' });}
7:    if (!Number.isFinite(amount) || isNaN(amount) || amount <= 0) {
8:      return res.status(400).json({ error: 'Số tiền không hợp lệ', code: 'INVALID_AMOUNT' });}
9:    if (amount < 1000) {
10:     return res.status(400).json({ error: 'Tối thiểu 1000đ', code: 'MIN_AMOUNT_1000' });}
11:   if (note) {
12:     var words = note.split(/\s+/).filter(Boolean);
13:     if (words.length > 200) {
14:       return res.status(400).json({ error: 'Tối đa 200 từ', code: 'NOTE_TOO_LONG' });}}
15:   if (!fund) {
16:     return res.status(404).json({ error: 'Quỹ không tồn tại hoặc bạn không phải thành viên quỹ' });}
17:   if (!user) {
18:     return res.status(404).json({ error: 'Người dùng không tồn tại' });}
19:   if (user.walletBalance < amount) {
20:     return res.status(400).json({ error: 'Số dư ví không đủ để thực hiện giao dịch', code: 'INSUFFICIENT_BALANCE' });}
21:   if (!debited) {
22:     return res.status(400).json({ error: 'Số dư ví không đủ để thực hiện giao dịch', code: 'INSUFFICIENT_BALANCE' });}};
```