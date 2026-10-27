```javascript
1:  exports.create = async function(req, res) {
2:    var fundCount = await Fund.countDocuments({ userId: req.user.id });
      var fundType = req.body.fundType !== undefined && req.body.fundType !== null ? String(req.body.fundType).trim() : '';
      var allowedTypes = ['Cá nhân', 'Cặp đôi', 'Tích lũy', 'Hội nhóm'];
      var name = req.body.name !== undefined && req.body.name !== null ? String(req.body.name).trim() : '';
      var targetAmount = Number(req.body.targetAmount) || 0, completionDate = undefined;
      var partner = null;
3:    if (fundCount >= 10) {
4:      return res.status(400).json({ error: 'Không thể tạo thêm quỹ', code: 'MAX_FUNDS_EXCEEDED' });}
5:    if (!fundType) {
6:      return res.status(400).json({ error: 'Vui lòng chọn loại quỹ', code: 'FUND_TYPE_REQUIRED' });}
7:    if (!allowedTypes.includes(fundType)) {
8:      return res.status(400).json({ error: 'Loại quỹ không hợp lệ', code: 'INVALID_FUND_TYPE' });}
9:    if (!name) {
10:     return res.status(400).json({ error: 'Vui lòng nhập tên quỹ', field: 'name', code: 'FUND_NAME_REQUIRED' });}
11:   if (name.length > 60) {
12:     return res.status(400).json({ error: 'Tên quỹ không được vượt quá 60 ký tự', field: 'name', code: 'FUND_NAME_TOO_LONG' });}
13:   if (fundType === 'Tích lũy') {
14:     targetAmount = Number(req.body.targetAmount);
        completionDate = new Date(req.body.completionDate);
        var now = new Date(), todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var compDay = new Date(completionDate.getFullYear(), completionDate.getMonth(), completionDate.getDate());
15:     if (req.body.targetAmount === undefined || req.body.targetAmount === null || String(req.body.targetAmount).trim() === '') {
16:       return res.status(400).json({ error: 'Vui lòng nhập số tiền mục tiêu', field: 'targetAmount', code: 'TARGET_AMOUNT_REQUIRED' });}
17:     if (!Number.isFinite(targetAmount) || targetAmount <= 0) {
18:       return res.status(400).json({ error: 'Số tiền mục tiêu phải lớn hơn 0', field: 'targetAmount', code: 'INVALID_TARGET_AMOUNT' });}
19:     if (!req.body.completionDate) {
20:       return res.status(400).json({ error: 'Vui lòng chọn ngày hoàn thành mục tiêu', field: 'completionDate', code: 'COMPLETION_DATE_REQUIRED' });}
21:     if (Number.isNaN(completionDate.getTime())) {
22:       return res.status(400).json({ error: 'Vui lòng chọn ngày hoàn thành mục tiêu', field: 'completionDate', code: 'INVALID_COMPLETION_DATE' });}
23:     if (compDay.getTime() <= todayStart.getTime()) {
24:       return res.status(400).json({ error: 'Ngày hoàn thành mục tiêu phải sau ngày hiện tại', code: 'COMPLETION_DATE_MUST_BE_FUTURE' });}
25:   } else {
        if (req.body.targetAmount && (!Number.isFinite(Number(req.body.targetAmount)) || Number(req.body.targetAmount) < 0)) {
26:       targetAmount = 0;}
27:     if (req.body.completionDate && !Number.isNaN(new Date(req.body.completionDate).getTime())) {
28:       completionDate = new Date(req.body.completionDate);}}
29:   if (fundType === fundRules.COUPLE_FUND_TYPE) {
30:     var lookup = await resolvePartner(req);
31:     if (lookup.error) {
32:       return res.status(400).json(lookup.error);}
33:     partner = lookup.user;}};