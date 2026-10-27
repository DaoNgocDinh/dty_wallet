# TRÍCH XUẤT CODE TINH GỌN KIỂM THỬ DÒNG ĐIỀU KHIỂN

## TÍNH NĂNG 5: NẠP ĐIỆN THOẠI/DATA (MOBILE / DATA TOP-UP)

---

### 1. Thông tin hàm nguồn
- **Tên hàm được chọn:** `mobileTopup` (thẩm định thông tin nhà mạng, SĐT, gói cước/mệnh giá & nạp tiền/data)
- **Đường dẫn file nguồn:** `server/controller/walletController.js`
- **Vị trí dòng nguồn gốc:** Dòng 154 đến dòng 310

### 2. Lý do chọn hàm
Hàm `mobileTopup` là controller duy nhất trực tiếp xử lý nghiệp vụ cho cả hai nghiệp vụ Nạp tiền điện thoại và Nạp gói Data, kiểm soát toàn diện luồng điều khiển của tính năng. Đoạn code bao hàm toàn bộ các nhánh rẽ nghiệp vụ cốt lõi: thẩm định nhà mạng viễn thông, kiểm tra định dạng 10 chữ số của số điện thoại bằng regex, phân nhánh nạp Data (kiểm tra tồn tại và tính khả dụng của gói) hoặc phân nhánh nạp tiền (kiểm tra mệnh giá hợp lệ), xác thực PIN, đối soát số dư ví và xử lý lỗi phản hồi từ API nhà mạng (timeout/failed). Nhờ gom gọn các bước khởi tạo lên đầu, đoạn mã tập trung toàn bộ vào các câu lệnh điều kiện và khối lệnh rẽ nhánh với độ dài lý tưởng 62 dòng, tối ưu cho việc xây dựng đồ thị dòng điều khiển và xác định đường đi kiểm thử hộp trắng.

---

### 3. Đoạn code tập trung vào điều kiện (Đánh số dòng liên tục)

```javascript
1:  exports.mobileTopup = function(type) {
2:    return async function(req, res) {
3:      // [Gộp khởi tạo dữ liệu đầu vào]
4:      var isData = type === 'data_topup', carrier = String(req.body.carrier || '').trim();
5:      var phoneNumber = String(req.body.phoneNumber || '').trim(), dataPackage = req.body.dataPackage ? String(req.body.dataPackage).trim() : null;
6:      var validCarriers = ['Viettel', 'Vinaphone', 'Mobifone', 'Vietnamobile'];
7:      var matchedCarrier = validCarriers.find(function(c) { return c.toLowerCase() === carrier.toLowerCase(); });
8:      var amount = 0, pkg = null;
9:  
10:     // 1. Kiểm tra nhà mạng hợp lệ
11:     if (!carrier || !matchedCarrier) {
12:       return res.status(400).json({ code: 'INVALID_CARRIER', error: 'Vui lòng chọn một trong các nhà mạng: Viettel, Vinaphone, Mobifone, Vietnamobile' });
13:     }
14:     var normalizedCarrier = matchedCarrier;
15: 
16:     // 2. Kiểm tra định dạng số điện thoại (10 chữ số)
17:     if (!phoneNumber || !/^[0-9]{10}$/.test(phoneNumber)) {
18:       return res.status(400).json({ code: 'INVALID_PHONE', error: 'Số điện thoại không hợp lệ. Vui lòng kiểm tra lại.' });
19:     }
20: 
21:     // 3. Phân nhánh dịch vụ: Gói Data hoặc Mệnh giá nạp ĐT
22:     if (isData) {
23:       if (!dataPackage) {
24:         return res.status(400).json({ code: 'PACKAGE_REQUIRED', error: 'Vui lòng chọn gói Data' });
25:       }
26:       pkg = findDataPackage(normalizedCarrier, dataPackage);
27:       if (!pkg || pkg.available === false) {
28:         return res.status(400).json({ code: 'PACKAGE_NOT_AVAILABLE', error: 'Gói Data không còn khả dụng. Vui lòng chọn gói khác.' });
29:       }
30:       amount = pkg.price;
31:     } else {
32:       amount = Number(req.body.amount || req.body.denomination);
33:       var validDenominations = [10000, 20000, 50000, 100000, 200000, 500000];
34:       if (!validDenominations.includes(amount)) {
35:         return res.status(400).json({ code: 'INVALID_DENOMINATION', error: 'Mệnh giá nạp không hợp lệ. Vui lòng chọn 10.000đ, 20.000đ, 50.000đ, 100.000đ, 200.000đ hoặc 500.000đ' });
36:       }
37:     }
38: 
39:     // 4. Xác thực mã PIN
40:     var user = await verifyPin(req, res);
41:     if (!user) return;
42: 
43:     // 5. Kiểm tra số dư ví
44:     if (user.walletBalance < amount) {
45:       return res.status(400).json({ code: 'INSUFFICIENT_BALANCE', error: 'Số dư không đủ để thực hiện giao dịch.' });
46:     }
47: 
48:     // 6. Kiểm tra kết nối và phản hồi từ hệ thống nhà mạng
49:     var mockCarrier = req.headers['x-mock-carrier'] || req.body.mockCarrier;
50:     if (mockCarrier === 'timeout' || mockCarrier === 'network_error') {
51:       return res.status(504).json({ code: 'CARRIER_TIMEOUT', error: 'Không thể xử lý giao dịch. Vui lòng thử lại sau.' });
52:     }
53:     if (mockCarrier === 'failed') {
54:       return res.status(502).json({ code: 'CARRIER_FAILED', error: 'Giao dịch không thành công. Vui lòng thử lại.' });
55:     }
56: 
57:     // 7. Cập nhật số dư ví và trả về kết quả
58:     user.walletBalance -= amount;
59:     await user.save();
60:     return res.status(200).json({ success: true, message: 'Giao dịch thành công', walletBalance: user.walletBalance });
61:   };
62: };
```

---

### 4. Liệt kê các nhánh điều khiển quan trọng

| Dòng code gộp | Dòng nguồn | Câu lệnh điều kiện gốc | Nhánh / Luồng có thể xảy ra |
|:---:|:---:|---|---|
| **11** | 166 | `if (!carrier \|\| !matchedCarrier)` | **True:** Trả về 400 `INVALID_CARRIER` ("Vui lòng chọn một trong các nhà mạng: Viettel, Vinaphone, Mobifone, Vietnamobile").<br>**False:** Nhà mạng hợp lệ, chuyển sang kiểm tra số điện thoại. |
| **17** | 175 | `if (!phoneNumber \|\| !/^[0-9]{10}$/.test(phoneNumber))` | **True:** Trả về 400 `INVALID_PHONE` ("Số điện thoại không hợp lệ. Vui lòng kiểm tra lại." - bỏ trống hoặc sai 10 chữ số).<br>**False:** Số điện thoại hợp lệ, chuyển sang kiểm tra loại dịch vụ (Data hoặc Nạp tiền). |
| **22** | 185 | `if (isData)` | **True:** Xử lý nhánh nạp gói Data.<br>**False:** Xử lý nhánh nạp tiền điện thoại (mệnh giá thông thường). |
| **23** | 187 | `if (!dataPackage)` | **True:** Trả về 400 `PACKAGE_REQUIRED` ("Vui lòng chọn gói Data").<br>**False:** Tìm kiếm thông tin gói Data theo nhà mạng. |
| **27** | 194 | `if (!pkg \|\| pkg.available === false)` | **True:** Trả về 400 `PACKAGE_NOT_AVAILABLE` ("Gói Data không còn khả dụng. Vui lòng chọn gói khác.").<br>**False:** Gói data khả dụng, gán `amount = pkg.price`. |
| **34** | 205 | `if (!validDenominations.includes(amount))` | **True:** Trả về 400 `INVALID_DENOMINATION` ("Mệnh giá nạp không hợp lệ..." - không nằm trong 6 mức cho phép).<br>**False:** Mệnh giá nạp hợp lệ. |
| **41** | 215 | `if (!user) return;` | **True:** Xác thực PIN không thành công (hàm `verifyPin` đã xử lý trả về mã lỗi 400/401/404/423), dừng hàm.<br>**False:** Xác thực PIN thành công, chuyển sang kiểm tra số dư ví. |
| **44** | 218 | `if (user.walletBalance < amount)` | **True:** Trả về 400 `INSUFFICIENT_BALANCE` ("Số dư không đủ để thực hiện giao dịch.").<br>**False:** Số dư ví đủ, chuyển sang gọi hệ thống nhà mạng. |
| **50** | 227 | `if (mockCarrier === 'timeout' \|\| mockCarrier === 'network_error')` | **True:** Trả về 504 `CARRIER_TIMEOUT` ("Không thể xử lý giao dịch. Vui lòng thử lại sau.").<br>**False:** Kết nối nhà mạng không bị gián đoạn. |
| **53** | 233 | `if (mockCarrier === 'failed')` | **True:** Trả về 502 `CARRIER_FAILED` ("Giao dịch không thành công. Vui lòng thử lại.").<br>**False:** Nhà mạng nạp thành công, trừ số dư ví và trả về kết quả 200. |
