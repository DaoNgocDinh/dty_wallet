# TRÍCH XUẤT CODE TINH GỌN KIỂM THỬ DÒNG ĐIỀU KHIỂN

## TÍNH NĂNG 4: THANH TOÁN HOÁ ĐƠN (BILL PAYMENT)

---

### 1. Thông tin hàm nguồn
- **Tên hàm được chọn:** `payBill` (thẩm định thông tin hóa đơn & thực hiện thanh toán trừ tiền ví)
- **Đường dẫn file nguồn:** `server/controller/walletController.js`
- **Vị trí dòng nguồn gốc:** Dòng 421 đến dòng 513

### 2. Lý do chọn hàm
Hàm `payBill` là trung tâm điều phối nghiệp vụ của tính năng Thanh toán hóa đơn, xử lý toàn bộ các khâu thẩm định từ phương thức thanh toán, mã hóa đơn/QR, trạng thái kết nối đối tác, xác thực PIN đến kiểm tra số dư ví. Mã nguồn chứa đầy đủ các nhánh rẽ điều kiện quyết định kết quả giao dịch (bỏ trống mã khách hàng, mã QR không hợp lệ, lỗi mạng/timeout phía đối tác, không tìm thấy hóa đơn, sai PIN và số dư ví không đủ). Các khai báo khởi tạo được gộp gọn ở phần đầu giúp đoạn code cô đọng đúng 55 dòng, tập trung chính xác vào luồng điều khiển và các lệnh rẽ nhánh để phục vụ vẽ đồ thị dòng điều khiển (CFG) và thiết kế test case kiểm thử hộp trắng.

---

### 3. Đoạn code tập trung vào điều kiện (Đánh số dòng liên tục)

```javascript
1:  exports.payBill = async function(req, res) {
2:    // [Gộp khởi tạo dữ liệu đầu vào]
3:    var paymentMethod = String(req.body.paymentMethod || '').trim(), billType = String(req.body.billType || '').trim();
4:    var customerCode = String(req.body.customerCode || '').trim(), qrData = req.body.qrData ? String(req.body.qrData).trim() : null;
5:    var content = req.body.content ? String(req.body.content).trim() : null, mockPartner = req.headers['x-mock-partner'] || req.body.mockPartner;
6:  
7:    // 1. Kiểm tra mã khách hàng khi thanh toán trực tiếp
8:    if (paymentMethod === 'direct' && !customerCode) {
9:      return res.status(400).json({ code: 'EMPTY_CUSTOMER_CODE', error: 'Mã khách hàng/Mã hóa đơn không được để trống.' });
10:   }
11: 
12:   // 2. Kiểm tra tính hợp lệ của mã QR khi thanh toán qua QR
13:   if (paymentMethod === 'qr') {
14:     if (!qrData) {
15:       return res.status(400).json({ code: 'INVALID_QR', error: 'Mã QR không hợp lệ hoặc không thể giải mã.' });
16:     }
17:     if (!qrData.startsWith('QR_')) {
18:       return res.status(400).json({ code: 'INVALID_QR', error: 'Mã QR không hợp lệ hoặc không thể giải mã.' });
19:     }
20:     customerCode = qrData;
21:   }
22: 
23:   // 3. Kiểm tra kết nối hệ thống đối tác
24:   if (mockPartner === 'timeout' || mockPartner === 'network_error') {
25:     return res.status(504).json({ code: 'PARTNER_TIMEOUT', error: 'Không thể kết nối đến hệ thống đối tác. Vui lòng thử lại sau.' });
26:   }
27: 
28:   // 4. Kiểm tra sự tồn tại của hóa đơn
29:   var bill = resolveBill(customerCode, billType);
30:   if (!bill) {
31:     return res.status(404).json({ code: 'BILL_NOT_FOUND', error: 'Không tìm thấy thông tin hóa đơn. Vui lòng kiểm tra lại mã khách hàng.' });
32:   }
33: 
34:   var totalAmount = bill.amount + bill.fee;
35: 
36:   // 5. Xác thực mã PIN giao dịch
37:   var user = await verifyPin(req, res);
38:   if (!user) return;
39: 
40:   // 6. Kiểm tra số dư ví khả dụng
41:   if (user.walletBalance < totalAmount) {
42:     return res.status(400).json({ code: 'INSUFFICIENT_BALANCE', error: 'Số dư không đủ để thực hiện giao dịch.' });
43:   }
44: 
45:   // 7. Trừ tiền số dư ví và lưu giao dịch
46:   user.walletBalance -= totalAmount;
47:   await user.save();
48:   var defaultNote = 'Thanh toán ' + bill.billType + ' - ' + bill.provider + ' kỳ ' + bill.period;
49:   var transaction = await Transaction.create({
50:     transactionCode: code(), userId: user._id, account: user.email, type: 'bill_payment',
51:     amount: totalAmount, sender: user.name || user.email, recipient: bill.provider,
52:     status: 'completed', note: content || defaultNote
53:   });
54:   return res.status(200).json({ success: true, message: 'Thanh toán thành công', transaction: transaction, walletBalance: user.walletBalance });
55: };
```

---

### 4. Liệt kê các nhánh điều khiển quan trọng

| Dòng code gộp | Dòng nguồn | Câu lệnh điều kiện gốc | Nhánh / Luồng có thể xảy ra |
|:---:|:---:|---|---|
| **8** | 428 | `if (paymentMethod === 'direct' && !customerCode)` | **True:** Trả về 400 `EMPTY_CUSTOMER_CODE` ("Mã khách hàng/Mã hóa đơn không được để trống.").<br>**False:** Chuyển sang kiểm tra trường hợp phương thức QR. |
| **13** | 432 | `if (paymentMethod === 'qr')` | **True:** Người dùng chọn thanh toán bằng mã QR, chuyển sang kiểm tra dữ liệu QR.<br>**False:** Phương thức khác, bỏ qua nhánh kiểm tra QR. |
| **14** | 433 | `if (!qrData)` | **True:** Trả về 400 `INVALID_QR` ("Mã QR không hợp lệ hoặc không thể giải mã." - không có dữ liệu QR).<br>**False:** Chuyển sang kiểm tra tiền tố QR. |
| **17** | 436 | `if (!qrData.startsWith('QR_'))` | **True:** Trả về 400 `INVALID_QR` ("Mã QR không hợp lệ hoặc không thể giải mã." - sai định dạng QR).<br>**False:** QR hợp lệ, gán `customerCode = qrData`. |
| **24** | 443 | `if (mockPartner === 'timeout' \|\| mockPartner === 'network_error')` | **True:** Trả về 504 `PARTNER_TIMEOUT` ("Không thể kết nối đến hệ thống đối tác. Vui lòng thử lại sau.").<br>**False:** Kết nối đối tác bình thường, thực hiện tra cứu hóa đơn. |
| **30** | 449 | `if (!bill)` | **True:** Trả về 404 `BILL_NOT_FOUND` ("Không tìm thấy thông tin hóa đơn. Vui lòng kiểm tra lại mã khách hàng.").<br>**False:** Tìm thấy hóa đơn, tính `totalAmount` và chuyển sang xác thực PIN. |
| **38** | 456 | `if (!user) return;` | **True:** Xác thực PIN không thành công (hàm `verifyPin` đã xử lý trả về mã lỗi 400/401/404/423), dừng hàm `payBill`.<br>**False:** Xác thực PIN thành công, nhận đối tượng `user` và chuyển sang kiểm tra số dư. |
| **41** | 458 | `if (user.walletBalance < totalAmount)` | **True:** Trả về 400 `INSUFFICIENT_BALANCE` ("Số dư không đủ để thực hiện giao dịch.").<br>**False:** Số dư ví đủ thanh toán, thực hiện trừ tiền và hoàn tất giao dịch (200). |
