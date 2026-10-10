import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_logo.dart';
import 'profile_screen.dart';

/// Hàm định dạng tiền tệ VND: 0 -> '0 đ', 1000000 -> '1.000.000 đ'
String formatVnd(dynamic amount) {
  if (amount == null) return '0 đ';
  final num? value = amount is num ? amount : num.tryParse(amount.toString());
  if (value == null) return '0 đ';
  final int val = value.round();
  final isNegative = val < 0;
  final absStr = val.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < absStr.length; i++) {
    if (i > 0 && (absStr.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(absStr[i]);
  }
  return '${isNegative ? '-' : ''}${buffer.toString()} đ';
}

/// Trang chủ ví điện tử chuẩn kích thước iPhone 18.
/// - Phần hiển thị số dư được đẩy lên trên cùng
/// - Dưới hiển thị 6 nút nhỏ tính năng: Nạp ví, Nạp đt/data, L.sử giao dịch, Thanh toán hđ, Quỹ, Hũ chi tiêu
/// - Nút trang cá nhân hình vuông tròn trên cùng bên phải
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _walletMessage;
  String? _walletError;
  bool _loadedWallet = false;
  bool _isBalanceHidden = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedWallet) {
      _loadedWallet = true;
      _loadWallet();
    }
  }

  /// Gọi API lấy số dư ví
  Future<void> _loadWallet() async {
    try {
      final wallet = await AppScope.of(context).fetchWallet();
      if (!mounted) return;
      final balance = wallet['walletBalance'] ?? wallet['balance'] ?? 0;
      setState(() => _walletMessage = formatVnd(balance));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _walletError = error.message);
    }
  }

  // --- 1. Bottom Sheet: Nạp ví ---
  void _showDepositSheet(BuildContext context) {
    final amountController = TextEditingController(text: '100000');
    String selectedSource = 'Vietcombank (Liên kết)';
    bool isSubmitting = false;
    String? sheetError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Nạp tiền vào ví',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền nạp (VND)',
                  prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.lightBlue),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedSource,
                decoration: const InputDecoration(
                  labelText: 'Nguồn tiền',
                  prefixIcon: Icon(Icons.account_balance_outlined, color: AppColors.lightBlue),
                ),
                items: const [
                  DropdownMenuItem(value: 'Vietcombank (Liên kết)', child: Text('Vietcombank (Liên kết)')),
                  DropdownMenuItem(value: 'MB Bank (QR Pay)', child: Text('MB Bank (QR Pay)')),
                  DropdownMenuItem(value: 'Thẻ Quốc tế (Visa/Mastercard)', child: Text('Thẻ Quốc tế (Visa/Mastercard)')),
                ],
                onChanged: (v) => setSheetState(() => selectedSource = v ?? selectedSource),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Text(sheetError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              AppButton(
                text: 'Xác nhận nạp tiền',
                isLoading: isSubmitting,
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    setSheetState(() => sheetError = 'Vui lòng nhập số tiền hợp lệ');
                    return;
                  }
                  setSheetState(() {
                    isSubmitting = true;
                    sheetError = null;
                  });
                  final navigator = Navigator.of(sheetCtx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await AppScope.of(context).deposit(
                      amount: amount,
                      source: selectedSource,
                      paymentMethod: 'qr',
                    );
                    if (!mounted) return;
                    navigator.pop();
                    _loadWallet();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Yêu cầu nạp ${amount.toStringAsFixed(0)} đ đã được ghi nhận!')),
                    );
                  } on ApiException catch (e) {
                    setSheetState(() => sheetError = e.message);
                  } catch (_) {
                    setSheetState(() => sheetError = 'Không thể nạp tiền, vui lòng thử lại');
                  } finally {
                    setSheetState(() => isSubmitting = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. Bottom Sheet: Nạp ĐT / Data ---
  void _showTopupSheet(BuildContext context) {
    final phoneController = TextEditingController();
    final pinController = TextEditingController();
    String selectedCarrier = 'Viettel';
    double selectedAmount = 50000;
    bool isData = false;
    bool isSubmitting = false;
    String? sheetError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isData ? 'Nạp gói Data 4G/5G' : 'Nạp tiền điện thoại',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Nạp ĐT'),
                      selected: !isData,
                      onSelected: (val) => setSheetState(() => isData = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Gói Data'),
                      selected: isData,
                      onSelected: (val) => setSheetState(() => isData = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCarrier,
                  decoration: const InputDecoration(labelText: 'Nhà mạng'),
                  items: const [
                    DropdownMenuItem(value: 'Viettel', child: Text('Viettel')),
                    DropdownMenuItem(value: 'Vinaphone', child: Text('Vinaphone')),
                    DropdownMenuItem(value: 'Mobifone', child: Text('Mobifone')),
                  ],
                  onChanged: (v) => setSheetState(() => selectedCarrier = v ?? selectedCarrier),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_iphone_rounded, color: AppColors.lightBlue),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Chọn mệnh giá:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [20000.0, 50000.0, 100000.0, 200000.0].map((amt) {
                    final sel = selectedAmount == amt;
                    return ChoiceChip(
                      label: Text('${amt.toStringAsFixed(0)} đ'),
                      selected: sel,
                      onSelected: (_) => setSheetState(() => selectedAmount = amt),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mã PIN giao dịch',
                    prefixIcon: Icon(Icons.pin_outlined, color: AppColors.lightBlue),
                    counterText: '',
                  ),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 10),
                  Text(sheetError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                AppButton(
                  text: 'Thanh toán ngay',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    final pin = pinController.text.trim();
                    if (phone.isEmpty || pin.isEmpty) {
                      setSheetState(() => sheetError = 'Vui lòng nhập số điện thoại và mã PIN');
                      return;
                    }
                    setSheetState(() {
                      isSubmitting = true;
                      sheetError = null;
                    });
                    final navigator = Navigator.of(sheetCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await AppScope.of(context).mobileTopup(
                        carrier: selectedCarrier,
                        phoneNumber: phone,
                        amount: selectedAmount,
                        pin: pin,
                        dataPackage: isData ? 'DATA_30D' : null,
                      );
                      if (!mounted) return;
                      navigator.pop();
                      _loadWallet();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Nạp tiền cho $phone thành công!')),
                      );
                    } on ApiException catch (e) {
                      setSheetState(() => sheetError = e.message);
                    } catch (_) {
                      setSheetState(() => sheetError = 'Giao dịch thất bại, vui lòng thử lại');
                    } finally {
                      setSheetState(() => isSubmitting = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. Bottom Sheet: Lịch sử giao dịch ---
  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(sheetCtx).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lịch sử giao dịch',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: AppScope.of(context).fetchTransactions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.lightBlue));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi tải: ${snapshot.error}'));
                  }
                  final list = (snapshot.data?['data'] as List?) ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('Chưa có giao dịch nào được ghi nhận', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index] as Map<String, dynamic>;
                      final type = item['type'] ?? 'Giao dịch';
                      final amount = item['amount'] ?? 0;
                      final code = item['transactionCode'] ?? '';
                      final status = item['status'] ?? 'pending';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.lightBlue.withValues(alpha: 0.15),
                          child: const Icon(Icons.receipt_rounded, color: AppColors.lightBlue, size: 20),
                        ),
                        title: Text('$type', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('$code', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${amount.toString()} đ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            Text(
                              '$status',
                              style: TextStyle(
                                fontSize: 11,
                                color: status == 'completed' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. Bottom Sheet: Thanh toán hoá đơn ---
  void _showBillPaymentSheet(BuildContext context) {
    final codeController = TextEditingController();
    final amountController = TextEditingController(text: '350000');
    final pinController = TextEditingController();
    String billType = 'Điện (EVN)';
    bool isSubmitting = false;
    String? sheetError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thanh toán hoá đơn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: billType,
                decoration: const InputDecoration(labelText: 'Loại hoá đơn'),
                items: const [
                  DropdownMenuItem(value: 'Điện (EVN)', child: Text('Điện (EVN)')),
                  DropdownMenuItem(value: 'Nước sinh hoạt', child: Text('Nước sinh hoạt')),
                  DropdownMenuItem(value: 'Internet / Truyền hình', child: Text('Internet / Truyền hình')),
                ],
                onChanged: (v) => setSheetState(() => billType = v ?? billType),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã khách hàng / Hợp đồng',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.lightBlue),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thanh toán',
                  prefixIcon: Icon(Icons.monetization_on_outlined, color: AppColors.lightBlue),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Mã PIN giao dịch',
                  prefixIcon: Icon(Icons.pin_outlined, color: AppColors.lightBlue),
                  counterText: '',
                ),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Text(sheetError!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              AppButton(
                text: 'Thanh toán hoá đơn',
                isLoading: isSubmitting,
                onPressed: () async {
                  final code = codeController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0;
                  final pin = pinController.text.trim();
                  if (code.isEmpty || amount <= 0 || pin.isEmpty) {
                    setSheetState(() => sheetError = 'Vui lòng điền đủ mã KH, số tiền và mã PIN');
                    return;
                  }
                  setSheetState(() {
                    isSubmitting = true;
                    sheetError = null;
                  });
                  final navigator = Navigator.of(sheetCtx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await AppScope.of(context).payBill(
                      billType: billType,
                      customerCode: code,
                      amount: amount,
                      paymentMethod: 'wallet',
                      pin: pin,
                    );
                    if (!mounted) return;
                    navigator.pop();
                    _loadWallet();
                    messenger.showSnackBar(
                      SnackBar(content: Text('Thanh toán hoá đơn $code thành công!')),
                    );
                  } on ApiException catch (e) {
                    setSheetState(() => sheetError = e.message);
                  } catch (_) {
                    setSheetState(() => sheetError = 'Thanh toán thất bại, vui lòng thử lại');
                  } finally {
                    setSheetState(() => isSubmitting = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 5. Bottom Sheet: Quỹ ---
  void _showFundsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(sheetCtx).size.height * 0.65,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quỹ tiết kiệm & Đầu tư', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: AppScope.of(context).fetchFunds(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.lightBlue));
                  }
                  final list = (snapshot.data?['data'] as List?) ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('Chưa có quỹ nào được tạo', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.groups_rounded, color: Colors.white),
                          ),
                          title: Text(item['name'] ?? 'Quỹ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Loại: ${item['fundType'] ?? 'Tiết kiệm'}'),
                          trailing: Text('${item['targetAmount'] ?? 0} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. Bottom Sheet: Hũ chi tiêu ---
  void _showJarsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(sheetCtx).size.height * 0.65,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Hũ chi tiêu (6 Jars)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                future: AppScope.of(context).fetchSpendingJars(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.lightBlue));
                  }
                  final list = (snapshot.data?['data'] as List?) ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Text('Chưa có hũ chi tiêu nào', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.all_inbox_rounded, color: Colors.white),
                          ),
                          title: Text(item['name'] ?? 'Hũ chi tiêu', style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text('${item['balance'] ?? 0} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Header trên cùng: Brand/Logo bên trái + Nút Trang cá nhân hình vuông tròn bên phải ---
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 34),
                      const SizedBox(width: 8),
                      Text(
                        'DTY Wallet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  // Nút Trang cá nhân hình vuông tròn (Squircle Profile Button)
                  Semantics(
                    button: true,
                    label: 'Trang cá nhân',
                    child: Tooltip(
                      message: 'Trang cá nhân',
                      child: InkWell(
                        onTap: () => openProfileScreen(context),
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppColors.lightBlue.withValues(alpha: 0.4),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lightBlue.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.lightBlue,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Nội dung trang chủ cân bằng, không bị trống trên và dưới ---
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kIPhone18Width),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. PHẦN HIỂN THỊ SỐ DƯ ĐẨY LÊN TRÊN CÙNG
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.lightBlue, AppColors.lightBlueDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lightBlue.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Ví điện tử DTY',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isBalanceHidden
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.white70,
                                      size: 19,
                                    ),
                                    onPressed: () {
                                      setState(() => _isBalanceHidden = !_isBalanceHidden);
                                    },
                                    tooltip: _isBalanceHidden ? 'Hiện số dư' : 'Ẩn số dư',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Số dư ví khả dụng',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_isBalanceHidden)
                                const Text(
                                  '•••••••• đ',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                  ),
                                )
                              else if (_walletMessage != null)
                                Text(
                                  _walletMessage!,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                )
                              else if (_walletError != null)
                                Text(
                                  _walletError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFFFCDD2),
                                  ),
                                )
                              else
                                const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              // Lời chào người dùng & nút nạp nhanh
                              Row(
                                children: [
                                  const Icon(Icons.person_pin_circle_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Xin chào, ${user?.name ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _showDepositSheet(context),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 2),
                                          Text(
                                            'Nạp tiền',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 2. DƯỚI HIỂN THỊ CÁC BUTTON NHỎ CÁC TÍNH NĂNG (ĐÃ BỎ DẤU +)
                        const Text(
                          'Dịch vụ & Tính năng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lưới 6 tính năng yêu cầu (không có dấu + ở đầu)
                        GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.98,
                          children: [
                            _featureButton(
                              label: 'Nạp ví',
                              icon: Icons.add_card_rounded,
                              iconColor: const Color(0xFF2E7D32),
                              onTap: () => _showDepositSheet(context),
                            ),
                            _featureButton(
                              label: 'Nạp đt/data',
                              icon: Icons.phone_iphone_rounded,
                              iconColor: const Color(0xFFEF6C00),
                              onTap: () => _showTopupSheet(context),
                            ),
                            _featureButton(
                              label: 'L.sử giao dịch',
                              icon: Icons.receipt_long_rounded,
                              iconColor: const Color(0xFF7B1FA2),
                              onTap: () => _showHistorySheet(context),
                            ),
                            _featureButton(
                              label: 'Thanh toán hđ',
                              icon: Icons.receipt_outlined,
                              iconColor: const Color(0xFFC2185B),
                              onTap: () => _showBillPaymentSheet(context),
                            ),
                            _featureButton(
                              label: 'Quỹ',
                              icon: Icons.groups_rounded,
                              iconColor: const Color(0xFFF57F17),
                              onTap: () => _showFundsSheet(context),
                            ),
                            _featureButton(
                              label: 'Hũ chi tiêu',
                              icon: Icons.all_inbox_rounded,
                              iconColor: const Color(0xFF00838F),
                              onTap: () => _showJarsSheet(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // 3. PHẦN QUẢN LÝ TÀI CHÍNH (CÂN BẰNG PHẦN DƯỚI GIAO DIỆN)
                        _buildFinancialSection(context),

                        const SizedBox(height: 14),

                        // 4. PHẦN HOẠT ĐỘNG GẦN ĐÂY & LỊCH SỬ
                        _buildRecentActivitySection(context),

                        const SizedBox(height: 14),

                        // 5. BANNER BẢO MẬT DƯỚI CÙNG
                        _buildSecurityFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khối Quản lý tài chính: Quỹ tiết kiệm & 6 Hũ chi tiêu
  Widget _buildFinancialSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Quản lý tài chính',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _infoCard(
                title: 'Quỹ tiết kiệm',
                subtitle: 'Mục tiêu & Đầu tư',
                icon: Icons.groups_rounded,
                color: const Color(0xFFF57F17),
                onTap: () => _showFundsSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _infoCard(
                title: '6 Hũ chi tiêu',
                subtitle: 'Phân bổ ngân sách',
                icon: Icons.all_inbox_rounded,
                color: const Color(0xFF00838F),
                onTap: () => _showJarsSheet(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Thẻ thông tin tài chính bo góc hiện đại
  Widget _infoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khối Xem biến động giao dịch gần đây
  Widget _buildRecentActivitySection(BuildContext context) {
    return InkWell(
      onTap: () => _showHistorySheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.lightBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biến động số dư & Hoá đơn',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Xem toàn bộ lịch sử thu chi của bạn',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  /// Chân trang bảo mật
  Widget _buildSecurityFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Bảo mật thanh toán đa lớp chuẩn quốc tế',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nút nhỏ tính năng dạng hình vuông bo tròn (Squircle)
  Widget _featureButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}