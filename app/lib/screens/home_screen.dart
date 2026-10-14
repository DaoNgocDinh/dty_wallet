import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_logo.dart';
import 'admin_users_screen.dart';
import 'fund_screens/funds_screen.dart';
import 'notifications_sheet.dart';
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
  int _unreadNotificationCount = 0;
  bool _loadedNotifications = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AppScope.of(context).user;
    if (user != null) {
      _walletMessage = formatVnd(user.walletBalance);
    }
    if (!_loadedWallet) {
      _loadedWallet = true;
      _loadWallet();
    }
    if (!_loadedNotifications) {
      _loadedNotifications = true;
      _loadNotifications();
    }
  }

  /// Gọi API lấy số thông báo chưa đọc
  Future<void> _loadNotifications() async {
    try {
      final res = await AppScope.of(context).fetchNotifications();
      if (!mounted) return;
      final unread = res['unreadCount'] as num? ?? 0;
      setState(() => _unreadNotificationCount = unread.toInt());
    } catch (_) {}
  }

  /// Mở giao diện thông báo
  Future<void> _openNotifications(BuildContext context) async {
    await NotificationsSheet.show(context);
    if (mounted) {
      _loadNotifications();
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
                  prefixIcon: Icon(
                    Icons.monetization_on_outlined,
                    color: AppColors.lightBlue,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedSource,
                decoration: const InputDecoration(
                  labelText: 'Nguồn tiền',
                  prefixIcon: Icon(
                    Icons.account_balance_outlined,
                    color: AppColors.lightBlue,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Vietcombank (Liên kết)',
                    child: Text('Vietcombank (Liên kết)'),
                  ),
                  DropdownMenuItem(
                    value: 'MB Bank (QR Pay)',
                    child: Text('MB Bank (QR Pay)'),
                  ),
                  DropdownMenuItem(
                    value: 'Thẻ Quốc tế (Visa/Mastercard)',
                    child: Text('Thẻ Quốc tế (Visa/Mastercard)'),
                  ),
                ],
                onChanged: (v) =>
                    setSheetState(() => selectedSource = v ?? selectedSource),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Text(
                  sheetError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                text: 'Xác nhận nạp tiền',
                isLoading: isSubmitting,
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    setSheetState(
                      () => sheetError = 'Vui lòng nhập số tiền hợp lệ',
                    );
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
                      SnackBar(
                        content: Text(
                          'Yêu cầu nạp ${amount.toStringAsFixed(0)} đ đã được ghi nhận!',
                        ),
                      ),
                    );
                  } on ApiException catch (e) {
                    setSheetState(() => sheetError = e.message);
                  } catch (_) {
                    setSheetState(
                      () => sheetError = 'Không thể nạp tiền, vui lòng thử lại',
                    );
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    DropdownMenuItem(
                      value: 'Vinaphone',
                      child: Text('Vinaphone'),
                    ),
                    DropdownMenuItem(
                      value: 'Mobifone',
                      child: Text('Mobifone'),
                    ),
                  ],
                  onChanged: (v) => setSheetState(
                    () => selectedCarrier = v ?? selectedCarrier,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(
                      Icons.phone_iphone_rounded,
                      color: AppColors.lightBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chọn mệnh giá:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [20000.0, 50000.0, 100000.0, 200000.0].map((amt) {
                    final sel = selectedAmount == amt;
                    return ChoiceChip(
                      label: Text('${amt.toStringAsFixed(0)} đ'),
                      selected: sel,
                      onSelected: (_) =>
                          setSheetState(() => selectedAmount = amt),
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
                    prefixIcon: Icon(
                      Icons.pin_outlined,
                      color: AppColors.lightBlue,
                    ),
                    counterText: '',
                  ),
                ),
                if (sheetError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    sheetError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  text: 'Thanh toán ngay',
                  isLoading: isSubmitting,
                  onPressed: () async {
                    final phone = phoneController.text.trim();
                    final pin = pinController.text.trim();
                    if (phone.isEmpty || pin.isEmpty) {
                      setSheetState(
                        () => sheetError =
                            'Vui lòng nhập số điện thoại và mã PIN',
                      );
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
                        SnackBar(
                          content: Text('Nạp tiền cho $phone thành công!'),
                        ),
                      );
                    } on ApiException catch (e) {
                      setSheetState(() => sheetError = e.message);
                    } catch (_) {
                      setSheetState(
                        () =>
                            sheetError = 'Giao dịch thất bại, vui lòng thử lại',
                      );
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => const _TransactionHistorySheet(),
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
                  const Text(
                    'Thanh toán hoá đơn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                  DropdownMenuItem(
                    value: 'Điện (EVN)',
                    child: Text('Điện (EVN)'),
                  ),
                  DropdownMenuItem(
                    value: 'Nước sinh hoạt',
                    child: Text('Nước sinh hoạt'),
                  ),
                  DropdownMenuItem(
                    value: 'Internet / Truyền hình',
                    child: Text('Internet / Truyền hình'),
                  ),
                ],
                onChanged: (v) => setSheetState(() => billType = v ?? billType),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Mã khách hàng / Hợp đồng',
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                    color: AppColors.lightBlue,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thanh toán',
                  prefixIcon: Icon(
                    Icons.monetization_on_outlined,
                    color: AppColors.lightBlue,
                  ),
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
                  prefixIcon: Icon(
                    Icons.pin_outlined,
                    color: AppColors.lightBlue,
                  ),
                  counterText: '',
                ),
              ),
              if (sheetError != null) ...[
                const SizedBox(height: 10),
                Text(
                  sheetError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
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
                    setSheetState(
                      () => sheetError =
                          'Vui lòng điền đủ mã KH, số tiền và mã PIN',
                    );
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
                      SnackBar(
                        content: Text('Thanh toán hoá đơn $code thành công!'),
                      ),
                    );
                  } on ApiException catch (e) {
                    setSheetState(() => sheetError = e.message);
                  } catch (_) {
                    setSheetState(
                      () =>
                          sheetError = 'Thanh toán thất bại, vui lòng thử lại',
                    );
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

  // --- 5. Màn hình riêng biệt: Quỹ (Không phải dạng pop-up) ---
  Future<void> _openFundsScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FundsScreen()),
    );
    if (mounted) {
      _loadWallet();
    }
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
                const Text(
                  'Hũ chi tiêu (6 Jars)',
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
                future: AppScope.of(context).fetchSpendingJars(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.lightBlue,
                      ),
                    );
                  }
                  final list = (snapshot.data?['data'] as List?) ?? [];
                  if (list.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có hũ chi tiêu nào',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Icon(
                              Icons.all_inbox_rounded,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            item['name'] ?? 'Hũ chi tiêu',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: Text(
                            '${item['balance'] ?? 0} đ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                  Row(
                    children: [
                      // Nút Quản trị viên (chỉ hiển thị khi role == 'admin', các role khác ẩn đi)
                      if (user?.isAdmin == true) ...[
                        Semantics(
                          button: true,
                          label: 'Danh sách tài khoản',
                          child: Tooltip(
                            message: 'Danh sách tài khoản (Admin)',
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminUsersScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(13),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: const Color(0xFFFFB74D),
                                    width: 1.4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Color(0xFFE65100),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Nút Chuông Thông báo cạnh Avatar
                      Semantics(
                        button: true,
                        label: 'Thông báo',
                        child: Tooltip(
                          message: 'Thông báo',
                          child: InkWell(
                            onTap: () => _openNotifications(context),
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
                                    color: AppColors.lightBlue.withValues(
                                      alpha: 0.15,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.notifications_rounded,
                                    color: AppColors.lightBlue,
                                    size: 23,
                                  ),
                                  if (_unreadNotificationCount > 0)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE53935),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

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
                                    color: AppColors.lightBlue.withValues(
                                      alpha: 0.15,
                                    ),
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
                              colors: [
                                AppColors.lightBlue,
                                AppColors.lightBlueDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.lightBlue.withValues(
                                  alpha: 0.35,
                                ),
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
                                  // Nút ẩn / hiện số dư nổi bật
                                  Tooltip(
                                    message: _isBalanceHidden
                                        ? 'Hiện số dư'
                                        : 'Ẩn số dư',
                                    child: InkWell(
                                      onTap: () {
                                        setState(
                                          () => _isBalanceHidden =
                                              !_isBalanceHidden,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.22,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isBalanceHidden
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                              color: Colors.white,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _isBalanceHidden ? 'Hiện' : 'Ẩn',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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
                              // Dòng hiển thị số dư và nút + Nạp tiền trên cùng một dòng
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: _isBalanceHidden
                                        ? const Text(
                                            '•••••••• đ',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 2,
                                            ),
                                          )
                                        : _walletMessage != null
                                        ? Text(
                                            _walletMessage!,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          )
                                        : _walletError != null
                                        ? Text(
                                            _walletError!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFFFCDD2),
                                            ),
                                          )
                                        : const Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _showDepositSheet(context),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            color: AppColors.lightBlueDark,
                                            size: 16,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Nạp tiền',
                                            style: TextStyle(
                                              color: AppColors.lightBlueDark,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Lời chào người dùng
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_pin_circle_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
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
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 2. VÙNG LỚN CHỨA CÁC NÚT TÍNH NĂNG CHỨC NĂNG
                        const Text(
                          'Dịch vụ & Tính năng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Vùng lớn gom chung toàn bộ 6 nút chức năng, bo góc, bóng mờ đồng bộ
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.05,
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
                                iconColor: const Color(0xFFE53935),
                                onTap: () => _openFundsScreen(context),
                              ),
                              _featureButton(
                                label: 'Hũ chi tiêu',
                                icon: Icons.all_inbox_rounded,
                                iconColor: const Color(0xFF00838F),
                                onTap: () => _showJarsSheet(context),
                              ),
                              if (user?.isAdmin == true)
                                _featureButton(
                                  label: 'DS tài khoản',
                                  icon: Icons.admin_panel_settings_rounded,
                                  iconColor: const Color(0xFFE65100),
                                  hasBorder: true,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const AdminUsersScreen(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),

                        if (user?.isAdmin == true) ...[
                          const SizedBox(height: 16),
                          _buildAdminSection(context),
                        ],

                        const SizedBox(height: 16),

                        // 3. HOẠT ĐỘNG GẦN ĐÂY & LỊCH SỬ THU CHI
                        _buildRecentActivitySection(context),

                        const SizedBox(height: 16),

                        // 4. ƯU ĐÃI & KHUYẾN MÃI (LÀM ĐẦY VÀ CÂN ĐỐI PHẦN DƯỚI GIAO DIỆN)
                        _buildPromotionsSection(context),

                        const SizedBox(height: 16),

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

  /// Banner Quản trị viên (chỉ hiển thị khi role == 'admin')
  Widget _buildAdminSection(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB74D)),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
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
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Bảng điều khiển Quản trị viên',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Xem danh sách tài khoản & tra cứu người dùng',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8D6E63),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Xem ngay',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 10,
                  ),
                ],
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
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.lightBlue,
                size: 20,
              ),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
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
          Icon(
            Icons.shield_outlined,
            size: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
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

  /// Khối Ưu đãi & Tiện ích giúp giao diện đầy đặn, không bị trống
  Widget _buildPromotionsSection(BuildContext context) {
    final loginTime = AppScope.of(context).loginTime ?? DateTime.now();
    final hour = loginTime.hour.toString().padLeft(2, '0');
    final minute = loginTime.minute.toString().padLeft(2, '0');
    final day = loginTime.day.toString().padLeft(2, '0');
    final month = loginTime.month.toString().padLeft(2, '0');
    final year = loginTime.year;
    final updateTimeStr = 'Cập nhật lúc $hour:$minute - $day/$month/$year';
    final currentMonth = DateTime.now().month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ưu đãi & Khuyến mãi',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // 1. Lập quỹ tiết kiệm cho bản thân và gia đình
        _buildPromoCard(
          context: context,
          icon: Icons.savings_rounded,
          iconColor: const Color(0xFFE53935),
          title: 'Lập quỹ tiết kiệm cho bản thân và gia đình',
          subtitle: 'Tạo quỹ cá nhân, cặp đôi, tích luỹ, ...',
          onTap: () => _openFundsScreen(context),
        ),
        const SizedBox(height: 10),
        // 2. Chi tiêu tháng (số tháng thay đổi theo thời gian thực & cập nhật theo thời gian đăng nhập)
        _buildPromoCard(
          context: context,
          icon: Icons.pie_chart_rounded,
          iconColor: const Color(0xFF00838F),
          title: 'Chi tiêu tháng $currentMonth',
          subtitle: updateTimeStr,
          onTap: () => _showJarsSheet(context),
        ),
        const SizedBox(height: 10),
        // 3. Ưu đãi hoàn tiền thanh toán hoá đơn
        _buildPromoCard(
          context: context,
          icon: Icons.percent_rounded,
          iconColor: const Color(0xFFEF6C00),
          title: 'Hoàn tiền 10% thanh toán hoá đơn',
          subtitle: 'Áp dụng cho hoá đơn điện, nước sinh hoạt',
          onTap: () => _showBillPaymentSheet(context),
        ),
      ],
    );
  }

  /// Thẻ ưu đãi / tiện ích có thể bấm tương tác
  Widget _buildPromoCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Nút chức năng không viền, làm nổi bật icon và chữ với màu chữ đồng bộ với màu icon.
  /// Riêng mục Quỹ có khung viền đỏ làm nổi bật.
  Widget _featureButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool hasBorder = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: iconColor.withValues(alpha: hasBorder ? 1.0 : 0.25),
                    width: hasBorder ? 1.6 : 1.0,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 25),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Giao diện Lịch sử giao dịch: Phân biệt rõ ràng Tiền vào & Tiền ra, khác icon, màu sắc và hỗ trợ bộ lọc tab
class _TransactionHistorySheet extends StatefulWidget {
  const _TransactionHistorySheet();

  @override
  State<_TransactionHistorySheet> createState() =>
      _TransactionHistorySheetState();
}

class _TransactionHistorySheetState extends State<_TransactionHistorySheet> {
  String _filter = 'all'; // 'all', 'in', 'out'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> item, String query) {
    if (query.isEmpty) return true;
    final q = query.trim().toLowerCase();
    final title = _getTxnTitle(item).toLowerCase();
    final code = (item['transactionCode'] ?? item['code'] ?? item['_id'] ?? item['id'] ?? '')
        .toString()
        .toLowerCase();
    final note = (item['note'] ?? '').toString().toLowerCase();
    final sender = (item['sender'] ?? '').toString().toLowerCase();
    final recipient = (item['recipient'] ?? '').toString().toLowerCase();
    final amtNum = (item['amount'] as num?)?.toDouble() ?? 0;
    final amtStr = amtNum.toString();
    final amtIntStr = amtNum.toInt().toString();
    final formattedAmt = formatVnd(amtNum).toLowerCase();
    final dateStr = _formatTxnDate(item['createdAt']).toLowerCase();

    return title.contains(q) ||
        code.contains(q) ||
        note.contains(q) ||
        sender.contains(q) ||
        recipient.contains(q) ||
        amtStr.contains(q) ||
        amtIntStr.contains(q) ||
        formattedAmt.contains(q) ||
        dateStr.contains(q);
  }

  bool _isIncoming(Map<String, dynamic> item, String? userEmail) {
    final t = item['type']?.toString() ?? '';
    if (t == 'wallet_deposit' ||
        t == 'fund_withdrawal' ||
        t == 'incoming' ||
        t == 'deposit') {
      return true;
    }
    if (t == 'fund_contribution' ||
        t == 'jar_contribution' ||
        t == 'mobile_topup' ||
        t == 'data_topup' ||
        t == 'bill_payment' ||
        t == 'outgoing') {
      return false;
    }
    if (userEmail != null && userEmail.isNotEmpty) {
      if (item['recipient']?.toString().toLowerCase() ==
          userEmail.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  String _getTxnTitle(Map<String, dynamic> item) {
    final t = item['type']?.toString() ?? '';
    final meta = item['metadata'] is Map ? item['metadata'] as Map : null;
    final fundName =
        meta?['fundName']?.toString() ?? item['recipient']?.toString() ?? '';
    switch (t) {
      case 'wallet_deposit':
        final source = item['sender']?.toString();
        if (source != null && source.isNotEmpty && !source.contains('@')) {
          return 'Nạp ví ($source)';
        }
        return 'Nạp tiền vào ví';
      case 'fund_withdrawal':
        if (fundName.isNotEmpty && !fundName.contains('@')) {
          return 'Rút tiền: $fundName';
        }
        return 'Rút tiền từ quỹ';
      case 'fund_contribution':
        if (fundName.isNotEmpty && !fundName.contains('@')) {
          return 'Góp quỹ: $fundName';
        }
        return 'Góp tiền vào quỹ';
      case 'jar_contribution':
        final jarName = item['recipient']?.toString() ?? '';
        if (jarName.isNotEmpty && !jarName.contains('@')) {
          return 'Vào hũ: $jarName';
        }
        return 'Chuyển vào hũ chi tiêu';
      case 'mobile_topup':
        final phone = item['recipient']?.toString() ?? '';
        if (phone.isNotEmpty) {
          return 'Nạp ĐT $phone';
        }
        return 'Nạp tiền điện thoại';
      case 'data_topup':
        final phone = item['recipient']?.toString() ?? '';
        if (phone.isNotEmpty) {
          return 'Nạp Data $phone';
        }
        return 'Nạp Data 3G/4G';
      case 'bill_payment':
        final billType = meta?['billType']?.toString() ?? '';
        if (billType.isNotEmpty) {
          return 'Thanh toán $billType';
        }
        return 'Thanh toán hoá đơn';
      default:
        return t.replaceAll('_', ' ');
    }
  }

  String _formatTxnDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min';
    } catch (_) {
      return dateVal.toString();
    }
  }

  String _formatTxnStatus(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Thành công';
      case 'pending':
        return 'Đang xử lý';
      case 'failed':
        return 'Thất bại';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFEF6C00);
      case 'failed':
        return const Color(0xFFC62828);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = AppScope.of(context).user?.email;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.lightBlue,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Lịch sử giao dịch',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Ô tìm kiếm giao dịch
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, mã giao dịch, số tiền, ghi chú...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.lightBlue,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Xoá tìm kiếm',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: AppScope.of(context).fetchTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.lightBlue),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Lỗi tải: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final rawList = (snapshot.data?['data'] as List?) ?? [];
                final list = rawList
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Chưa có giao dịch nào được ghi nhận',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Tính toán tổng tiền vào và tổng tiền ra
                double totalIn = 0;
                double totalOut = 0;
                int countIn = 0;
                int countOut = 0;

                for (final item in list) {
                  final amt = (item['amount'] as num?)?.toDouble() ?? 0;
                  final isPending =
                      item['status']?.toString().toLowerCase() == 'pending';
                  if (_isIncoming(item, userEmail)) {
                    if (!isPending) totalIn += amt;
                    countIn++;
                  } else {
                    if (!isPending) totalOut += amt;
                    countOut++;
                  }
                }

                // Lọc theo bộ lọc và tìm kiếm
                final filteredList = list.where((item) {
                  final isInc = _isIncoming(item, userEmail);
                  if (_filter == 'in' && !isInc) return false;
                  if (_filter == 'out' && isInc) return false;
                  if (!_matchesSearch(item, _searchQuery)) return false;
                  return true;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thanh tổng quan Tiền vào / Tiền ra
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
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
                          // Tổng tiền vào
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8F5E9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.south_west_rounded,
                                    color: Color(0xFF2E7D32),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tổng vào',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '+${formatVnd(totalIn)}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 28,
                            width: 1,
                            color: AppColors.border,
                          ),
                          const SizedBox(width: 12),
                          // Tổng tiền ra
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFEBEE),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.north_east_rounded,
                                    color: Color(0xFFE53935),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tổng ra',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '-${formatVnd(totalOut)}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE53935),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bộ lọc 3 tab: Tất cả / Tiền vào / Tiền ra
                    Row(
                      children: [
                        _buildFilterTab(
                          label: 'Tất cả (${list.length})',
                          isSelected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: 'Tiền vào ($countIn)',
                          icon: Icons.south_west_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          isSelected: _filter == 'in',
                          activeColor: const Color(0xFF2E7D32),
                          activeBg: const Color(0xFFE8F5E9),
                          onTap: () => setState(() => _filter = 'in'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: 'Tiền ra ($countOut)',
                          icon: Icons.north_east_rounded,
                          iconColor: const Color(0xFFE53935),
                          isSelected: _filter == 'out',
                          activeColor: const Color(0xFFE53935),
                          activeBg: const Color(0xFFFFEBEE),
                          onTap: () => setState(() => _filter = 'out'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Danh sách giao dịch
                    Expanded(
                      child: filteredList.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _searchQuery.isNotEmpty
                                            ? Icons.search_off_rounded
                                            : Icons.receipt_long_outlined,
                                        size: 32,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'Không tìm thấy giao dịch nào phù hợp'
                                          : (_filter == 'in'
                                              ? 'Chưa có giao dịch tiền vào nào'
                                              : 'Chưa có giao dịch tiền ra nào'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (_searchQuery.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Không có kết quả cho "${_searchQuery}"',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Xoá tìm kiếm'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.lightBlue,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredList.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = filteredList[index];
                                final isInc = _isIncoming(item, userEmail);
                                final amount =
                                    (item['amount'] as num?)?.toDouble() ?? 0;
                                final title = _getTxnTitle(item);
                                final code =
                                    item['transactionCode']?.toString() ?? '';
                                final shortCode = code.length > 12
                                    ? '${code.substring(0, 10)}...'
                                    : code;
                                final dateStr =
                                    _formatTxnDate(item['createdAt']);
                                final status =
                                    item['status']?.toString() ?? 'completed';
                                final note = item['note']?.toString() ?? '';

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.02,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Icon phân biệt tiền vào / tiền ra
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isInc
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFEBEE),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isInc
                                                ? const Color(
                                                    0xFF2E7D32,
                                                  ).withValues(alpha: 0.25)
                                                : const Color(
                                                    0xFFE53935,
                                                  ).withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          isInc
                                              ? Icons.south_west_rounded
                                              : Icons.north_east_rounded,
                                          color: isInc
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFE53935),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Thông tin giữa
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13.5,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Huy hiệu Tiền vào / Tiền ra
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                    horizontal: 5.5,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isInc
                                                        ? const Color(
                                                            0xFFE8F5E9,
                                                          )
                                                        : const Color(
                                                            0xFFFFEBEE,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isInc
                                                        ? 'Tiền vào'
                                                        : 'Tiền ra',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isInc
                                                          ? const Color(
                                                              0xFF2E7D32,
                                                            )
                                                          : const Color(
                                                              0xFFC62828,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                if (dateStr.isNotEmpty)
                                                  Text(
                                                    dateStr,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                if (shortCode.isNotEmpty) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '• $shortCode',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (note.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                note,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Số tiền và trạng thái bên phải
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isInc ? '+' : '-'}${formatVnd(amount)}',
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold,
                                              color: isInc
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFE53935),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatTxnStatus(status),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: _statusColor(status),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
    Color? activeColor,
    Color? activeBg,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.5, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? (activeBg ?? AppColors.lightBlue.withValues(alpha: 0.12))
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? (activeColor ?? AppColors.lightBlue)
                  : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected
                      ? (activeColor ?? AppColors.lightBlue)
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (activeColor ?? AppColors.lightBlueDark)
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
