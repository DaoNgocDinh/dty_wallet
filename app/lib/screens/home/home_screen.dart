export '../../utils/format_utils.dart' show formatVnd;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../state/app_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../profile/admin_users_screen.dart';
import '../funds/funds_screen.dart';
import '../bill_payment/bill_payment_screen.dart';
import '../mobile_topup/mobile_topup_screen.dart';
import '../notifications/notifications_sheet.dart';
import '../profile/profile_screen.dart';
import '../transaction_history/transaction_history_screen.dart';
import '../spending_jars/spending_jars_screen.dart';

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
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBottomNavIndex = 0; // 0: Trang chủ, 1: Nạp data, 2: Lịch sử, 3: Cá nhân

  int _historyRefreshTrigger = 0; // Kích hoạt làm mới tự động mỗi khi vào Lịch sử giao dịch
  String? _walletMessage;
  String? _walletError;
  bool _loadedWallet = false;
  bool _isBalanceHidden = false;
  int _unreadNotificationCount = 0;
  bool _loadedNotifications = false;

  // Trạng thái tìm kiếm
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isSearching = false;
  List<Map<String, dynamic>>? _searchResults;
  String _selectedSearchCategory = 'all';

  // Danh mục toàn bộ tính năng của ứng dụng (Local catalog phục vụ tìm kiếm tức thì 0ms)
  static const List<Map<String, dynamic>> _kAllFeatures = [
    {
      'id': 'deposit',
      'name': 'Nạp tiền vào ví',
      'shortName': 'Nạp ví',
      'description': 'Nạp tiền từ ngân hàng liên kết vào số dư ví DTY',
      'category': 'Tài chính',
      'icon': 'add_card',
      'keywords': ['nap', 'nap tien', 'nap vi', 'tien', 'deposit', 'bank', 'ngan hang', 'so du', 'tai khoan'],
    },
    {
      'id': 'topup_phone',
      'name': 'Nạp tiền điện thoại',
      'shortName': 'Nạp ĐT',
      'description': 'Nạp thẻ trực tiếp Viettel, VinaPhone, MobiFone, Vietnamobile',
      'category': 'Viễn thông',
      'icon': 'phone_iphone',
      'keywords': ['nap dt', 'nap dien thoai', 'the cao', 'viettel', 'vinaphone', 'mobifone', 'vietnamobile', 'topup', 'phone'],
    },
    {
      'id': 'topup_data',
      'name': 'Nạp Data 3G/4G/5G',
      'shortName': 'Nạp Data',
      'description': 'Đăng ký gói cước dung lượng Data internet di động tốc độ cao',
      'category': 'Viễn thông',
      'icon': 'data_usage',
      'keywords': ['nap data', 'data', '4g', '3g', '5g', 'dung luong', 'mang', 'internet', 'goi cuoc'],
    },
    {
      'id': 'history',
      'name': 'Lịch sử giao dịch',
      'shortName': 'Lịch sử',
      'description': 'Xem chi tiết biến động số dư, lịch sử nạp tiền, chi tiêu và chuyển tiền',
      'category': 'Tài chính',
      'icon': 'receipt_long',
      'keywords': ['lich su', 'giao dich', 'bien dong so du', 'thu chi', 'sao ke', 'history', 'nhat ky'],
    },
    {
      'id': 'bill_payment',
      'name': 'Thanh toán hoá đơn',
      'shortName': 'Hoá đơn',
      'description': 'Thanh toán hoá đơn điện lực EVN, nước sạch, cước internet',
      'category': 'Tiện ích',
      'icon': 'receipt',
      'keywords': ['hoa don', 'dien', 'nuoc', 'internet', 'thanh toan hoa don', 'bill', 'dien luc', 'tien dien', 'tien nuoc'],
    },
    {
      'id': 'funds',
      'name': 'Quản lý quỹ nhóm',
      'shortName': 'Quỹ nhóm',
      'description': 'Tạo quỹ chung, quản lý thành viên, góp quỹ và rút tiền minh bạch',
      'category': 'Tài chính',
      'icon': 'groups',
      'keywords': ['quy', 'quan ly quy', 'tao quy', 'gop quy', 'quy nhom', 'quy cap doi', 'funds', 'tiet kiem'],
    },
    {
      'id': 'spending_jars',
      'name': 'Hũ chi tiêu',
      'shortName': 'Hũ chi tiêu',
      'description': 'Phương pháp 6 hũ quản lý tài chính cá nhân thông minh',
      'category': 'Tài chính',
      'icon': 'all_inbox',
      'keywords': ['hu chi tieu', 'hu', 'spending jars', '6 hu', 'tiet kiem', 'ngan sach', 'chi tieu'],
    },
    {
      'id': 'notifications',
      'name': 'Thông báo',
      'shortName': 'Thông báo',
      'description': 'Xem tin tức hệ thống, thông báo biến động số dư và lời mời tham gia quỹ',
      'category': 'Tiện ích',
      'icon': 'notifications',
      'keywords': ['thong bao', 'chuong', 'tin nhan', 'tin moi', 'notification', 'notifications'],
    },
    {
      'id': 'profile',
      'name': 'Trang cá nhân & Cài đặt',
      'shortName': 'Trang cá nhân',
      'description': 'Xem thông tin tài khoản, cài đặt mã PIN và đổi mật khẩu ví',
      'category': 'Tài khoản',
      'icon': 'person',
      'keywords': ['ca nhan', 'ho so', 'tai khoan', 'profile', 'user', 'doi mat khau', 'ma pin', 'dang xuat'],
    },
    {
      'id': 'admin_users',
      'name': 'Quản lý tài khoản (Admin)',
      'shortName': 'DS tài khoản',
      'description': 'Xem danh sách tài khoản, phân quyền và quản lý hệ thống',
      'category': 'Quản trị',
      'icon': 'admin_panel_settings',
      'keywords': ['admin', 'quan tri', 'danh sach tai khoan', 'nguoi dung', 'users'],
      'adminOnly': true,
    },
  ];

  static String _normalizeVietnamese(String text) {
    var result = text.toLowerCase();
    const withDiacritics = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  List<Map<String, dynamic>> _filterFeaturesLocally(String query, bool isAdmin) {
    final available = _kAllFeatures.where((f) {
      if (f['adminOnly'] == true && !isAdmin) return false;
      if (_selectedSearchCategory != 'all') {
        if (_selectedSearchCategory == 'finance' && f['category'] != 'Tài chính') return false;
        if (_selectedSearchCategory == 'telecom' && f['category'] != 'Viễn thông') return false;
        if (_selectedSearchCategory == 'utility' && f['category'] != 'Tiện ích') return false;
        if (_selectedSearchCategory == 'account' && f['category'] != 'Tài khoản') return false;
      }
      return true;
    }).toList();

    if (query.trim().isEmpty) return available;
    final qNorm = _normalizeVietnamese(query.trim());

    return available.where((item) {
      final nameNorm = _normalizeVietnamese(item['name'] as String? ?? '');
      final shortNorm = _normalizeVietnamese(item['shortName'] as String? ?? '');
      final descNorm = _normalizeVietnamese(item['description'] as String? ?? '');
      final catNorm = _normalizeVietnamese(item['category'] as String? ?? '');

      if (nameNorm.contains(qNorm) || shortNorm.contains(qNorm) || descNorm.contains(qNorm) || catNorm.contains(qNorm)) {
        return true;
      }

      final keywords = (item['keywords'] as List?) ?? [];
      for (final k in keywords) {
        final kNorm = _normalizeVietnamese(k.toString());
        if (kNorm.contains(qNorm) || qNorm.contains(kNorm)) return true;
      }
      return false;
    }).toList();
  }

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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  // --- Xử lý tìm kiếm tính năng thông minh ---
  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    final isAdmin = AppScope.of(context).user?.isAdmin == true;

    // Phản hồi tức thì ngay khi gõ ký tự
    setState(() {
      _searchResults = _filterFeaturesLocally(val, isAdmin);
      _isSearching = val.trim().isNotEmpty;
    });

    if (val.trim().isEmpty) return;

    // Gọi API backend đồng bộ
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      _fetchFeaturesFromApi(val.trim());
    });
  }

  Future<void> _fetchFeaturesFromApi(String query) async {
    try {
      final results = await AppScope.of(context).searchFeatures(query);
      if (!mounted) return;
      if (results.isNotEmpty && _searchController.text.trim().isNotEmpty) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = null;
      _isSearching = false;
      _selectedSearchCategory = 'all';
    });
  }

  void _openFeatureById(String id) {
    _clearSearch();
    switch (id) {
      case 'deposit':
        _showDepositSheet(context);
        break;
      case 'topup_phone':
      case 'topup_data':
        setState(() => _currentBottomNavIndex = 1);
        break;
      case 'history':
        _openHistoryTab();
        break;
      case 'profile':
        setState(() => _currentBottomNavIndex = 3);
        break;
      case 'bill_payment':
        _showBillPaymentSheet(context);
        break;
      case 'funds':
        _openFundsScreen(context);
        break;
      case 'spending_jars':
        _openSpendingJarsScreen(context);
        break;
      case 'notifications':
        _openNotifications(context);
        break;
      case 'admin_users':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
        );
        break;
      default:
        break;
    }
  }

  IconData _getFeatureIcon(String id) {
    switch (id) {
      case 'deposit':
        return Icons.add_card_rounded;
      case 'topup_phone':
        return Icons.phone_iphone_rounded;
      case 'topup_data':
        return Icons.data_usage_rounded;
      case 'history':
        return Icons.receipt_long_rounded;
      case 'bill_payment':
        return Icons.receipt_outlined;
      case 'funds':
        return Icons.groups_rounded;
      case 'spending_jars':
        return Icons.all_inbox_rounded;
      case 'notifications':
        return Icons.notifications_rounded;
      case 'profile':
        return Icons.person_rounded;
      case 'admin_users':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  Color _getFeatureColor(String id) {
    switch (id) {
      case 'deposit':
        return const Color(0xFF2E7D32);
      case 'topup_phone':
        return const Color(0xFFEF6C00);
      case 'topup_data':
        return AppColors.lightBlue;
      case 'history':
        return const Color(0xFF7B1FA2);
      case 'bill_payment':
        return const Color(0xFFC2185B);
      case 'funds':
        return const Color(0xFFE53935);
      case 'spending_jars':
        return const Color(0xFF00838F);
      case 'notifications':
        return const Color(0xFFF57C00);
      case 'profile':
        return AppColors.lightBlueDark;
      case 'admin_users':
        return const Color(0xFFE65100);
      default:
        return AppColors.lightBlue;
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
            top: 24,
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
              const Text(
                'Chế độ demo: tiền sẽ được cộng ngay vào ví, không thực hiện thanh toán thật.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số tiền nạp (VND)',
                  prefixIcon: Icon(
                    Icons.attach_money_rounded,
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
                    child: Text('Vietcombank (mô phỏng)'),
                  ),
                  DropdownMenuItem(
                    value: 'MB Bank (QR Pay)',
                    child: Text('MB Bank (mô phỏng)'),
                  ),
                  DropdownMenuItem(
                    value: 'Thẻ Quốc tế (Visa/Mastercard)',
                    child: Text('Thẻ quốc tế (mô phỏng)'),
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
                text: 'Nạp tiền demo',
                isLoading: isSubmitting,
                onPressed: () async {
                  final amountText = amountController.text
                      .trim()
                      .replaceAll('.', '')
                      .replaceAll(',', '');
                  final amount = RegExp(r'^\d+$').hasMatch(amountText)
                      ? double.tryParse(amountText)
                      : null;
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
                    await AppScope.of(context)
                        .demoDeposit(amount: amount, source: selectedSource);
                    if (!mounted) return;
                    navigator.pop();
                    await _loadWallet();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Nạp demo ${formatVnd(amount)} thành công!',
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

  // --- 2. Chức năng Nạp ĐT / Data ---
  void _openMobileTopupScreen(BuildContext context, {bool initialIsData = false}) {
    setState(() => _currentBottomNavIndex = 1);
  }

  void _showTopupSheet(BuildContext context) {
    setState(() => _currentBottomNavIndex = 1);
  }

  // --- 3. Mở Lịch sử giao dịch ---
  void _openHistoryTab() {
    _clearSearch();
    setState(() {
      _currentBottomNavIndex = 2;
      _historyRefreshTrigger++;
    });
  }

  void _showHistorySheet(BuildContext context) {
    _openHistoryTab();
  }

  // --- 4. Màn hình Thanh toán hóa đơn ---
  void _showBillPaymentSheet(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BillPaymentScreen()))
        .then((_) => _loadWallet());
  }

  // --- 5. Màn hình riêng biệt: Quỹ ---
  Future<void> _openFundsScreen(BuildContext context) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FundsScreen()));
    if (mounted) {
      _loadWallet();
    }
  }

  // --- 6. Màn hình riêng biệt: Hũ chi tiêu ---
  Future<void> _openSpendingJarsScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpendingJarsScreen()),
    );
    if (mounted) {
      _loadWallet();
      _loadNotifications();
    }
  }

  // ==========================================
  // GIAO DIỆN CHÍNH (SCAFFOLD VỚI 4 TABS + BOTTOM BAR)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentBottomNavIndex,
          children: [
            // Tab 0: Trang chủ DTY
            _buildHomeTabContent(context),

            // Tab 1: Nạp ĐT / Data Viễn thông
            MobileTopupScreen(
              initialIsData: false,
              isEmbedded: true,
              onBackToHome: () {
                setState(() => _currentBottomNavIndex = 0);
                _loadWallet();
              },
            ),

            // Tab 2: Lịch sử giao dịch chuyên biệt
            TransactionHistoryScreen(
              key: ValueKey('tx_history_$_historyRefreshTrigger'),
              isEmbedded: true,
              isActive: _currentBottomNavIndex == 2,
              onBackToHome: () => setState(() => _currentBottomNavIndex = 0),
            ),

            // Tab 3: Trang cá nhân
            ProfileScreen(
              isEmbedded: true,
              onBackToHome: () => setState(() => _currentBottomNavIndex = 0),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // --- Thanh điều hướng dưới cùng (Bottom Navigation Bar) ---
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // 1. Bên trái: Trang chủ
              Expanded(
                child: _buildBottomBarIcon(
                  icon: Icons.home_rounded,
                  tooltip: 'Trang chủ',
                  isActive: _currentBottomNavIndex == 0,
                  onTap: () {
                    _clearSearch();
                    setState(() => _currentBottomNavIndex = 0);
                  },
                ),
              ),

              // 2. Bên trái: Nạp data
              Expanded(
                child: _buildBottomBarIcon(
                  icon: Icons.data_usage_rounded,
                  tooltip: 'Nạp data',
                  isActive: _currentBottomNavIndex == 1,
                  onTap: () {
                    _clearSearch();
                    setState(() => _currentBottomNavIndex = 1);
                  },
                ),
              ),

              // 3. Ở giữa: Nút hình tròn có dấu cộng khi ấn sẽ vào tính năng nạp tiền
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Semantics(
                  button: true,
                  label: 'Nạp tiền',
                  child: Tooltip(
                    message: 'Nạp tiền',
                    child: InkWell(
                      onTap: () => _showDepositSheet(context),
                      borderRadius: BorderRadius.circular(27),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.lightBlue, AppColors.lightBlueDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lightBlue.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Bên phải: Lịch sử giao dịch
              Expanded(
                child: _buildBottomBarIcon(
                  icon: Icons.receipt_long_rounded,
                  tooltip: 'Lịch sử giao dịch',
                  isActive: _currentBottomNavIndex == 2,
                  onTap: _openHistoryTab,
                ),
              ),

              // 5. Bên phải: Trang cá nhân
              Expanded(
                child: _buildBottomBarIcon(
                  icon: Icons.person_rounded,
                  tooltip: 'Trang cá nhân',
                  isActive: _currentBottomNavIndex == 3,
                  onTap: () {
                    _clearSearch();
                    setState(() => _currentBottomNavIndex = 3);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isActive)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                Icon(
                  icon,
                  size: 26,
                  color: isActive ? AppColors.lightBlueDark : AppColors.textSecondary,
                ),
                if (isActive)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.lightBlueDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Nội dung Tab 0: Trang chủ DTY ---
  Widget _buildHomeTabContent(BuildContext context) {
    final user = AppScope.of(context).user;

    return Column(
      children: [
        // 1. Header trên cùng: Thanh tìm kiếm thiết kế đẹp + Nút Chuông Thông báo
        _buildSearchHeader(context, user),

        // 2. Nội dung hiển thị: Kết quả tìm kiếm HOẶC Giao diện Trang chủ chuẩn
        if (_searchController.text.trim().isNotEmpty)
          Expanded(
            child: _buildSearchResultsView(context),
          )
        else
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
                      // Card số dư trên cùng
                      _buildBalanceCard(context, user),

                      const SizedBox(height: 16),

                      // Dịch vụ & Tính năng (Grid 6 nút)
                      _buildServicesGrid(context, user),

                      if (user?.isAdmin == true) ...[
                        const SizedBox(height: 16),
                        _buildAdminSection(context),
                      ],

                      const SizedBox(height: 16),

                      // Hoạt động gần đây & Lịch sử
                      _buildRecentActivitySection(context),

                      const SizedBox(height: 16),

                      // Ưu đãi & Khuyến mãi
                      _buildPromotionsSection(context),

                      const SizedBox(height: 16),

                      // Chân trang bảo mật
                      _buildSecurityFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- Header Tìm kiếm thiết kế mới sang trọng, hiện đại ---
  Widget _buildSearchHeader(BuildContext context, AuthUser? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          // Thanh tìm kiếm tính năng
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: _searchController.text.isNotEmpty || _searchFocusNode.hasFocus
                      ? AppColors.lightBlue
                      : AppColors.lightBlue.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lightBlueDark.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppColors.lightBlueDark,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm tính năng, dịch vụ...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (val) {
                        _onSearchChanged(val);
                      },
                    ),
                  ),
                  if (_isSearching) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.lightBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ] else if (_searchController.text.isNotEmpty) ...[
                    InkWell(
                      onTap: _clearSearch,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Nút Quản trị viên (chỉ hiển thị khi role == 'admin')
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
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
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

          // Nút Chuông Thông báo
          Semantics(
            button: true,
            label: 'Thông báo',
            child: Tooltip(
              message: 'Thông báo',
              child: InkWell(
                onTap: () => _openNotifications(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.lightBlue.withValues(alpha: 0.35),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lightBlue.withValues(alpha: 0.12),
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
                        color: AppColors.lightBlueDark,
                        size: 24,
                      ),
                      if (_unreadNotificationCount > 0)
                        Positioned(
                          top: 7,
                          right: 7,
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
        ],
      ),
    );
  }

  // --- Giao diện Kết quả Tìm kiếm đẹp & Trực quan ---
  Widget _buildSearchResultsView(BuildContext context) {
    final results = _searchResults ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dãy nút lọc nhanh theo danh mục
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              _buildCategoryPill('Tất cả', 'all', Icons.auto_awesome_rounded),
              const SizedBox(width: 8),
              _buildCategoryPill('Tài chính', 'finance', Icons.account_balance_wallet_rounded),
              const SizedBox(width: 8),
              _buildCategoryPill('Viễn thông', 'telecom', Icons.phone_android_rounded),
              const SizedBox(width: 8),
              _buildCategoryPill('Tiện ích', 'utility', Icons.receipt_long_rounded),
              const SizedBox(width: 8),
              _buildCategoryPill('Tài khoản', 'account', Icons.manage_accounts_rounded),
            ],
          ),
        ),

        // Tiêu đề số lượng kết quả
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tìm thấy ${results.length} tính năng',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: _clearSearch,
                child: const Text(
                  'Đóng tìm kiếm',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.lightBlueDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Danh sách tính năng tìm được
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.search_off_rounded,
                            size: 44,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Không tìm thấy tính năng nào phù hợp',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Thử tìm với từ khoá: nạp ví, nạp data, hoá đơn, quỹ...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    final id = item['id'] as String? ?? '';
                    final name = item['name'] as String? ?? '';
                    final desc = item['description'] as String? ?? '';
                    final category = item['category'] as String? ?? '';
                    final color = _getFeatureColor(id);
                    final icon = _getFeatureIcon(id);

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openFeatureById(id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(icon, color: color, size: 23),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightBlue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.lightBlueDark,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String label, String categoryKey, IconData icon) {
    final isSelected = _selectedSearchCategory == categoryKey;
    return InkWell(
      onTap: () {
        setState(() => _selectedSearchCategory = categoryKey);
        _onSearchChanged(_searchController.text);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightBlueDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.lightBlueDark : AppColors.border,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.lightBlueDark.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Thẻ hiển thị số dư ví ---
  Widget _buildBalanceCard(BuildContext context, AuthUser? user) {
    return Container(
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
              // Nút ẩn / hiện số dư nổi bật
              Tooltip(
                message: _isBalanceHidden ? 'Hiện số dư' : 'Ẩn số dư',
                child: InkWell(
                  onTap: () {
                    setState(() => _isBalanceHidden = !_isBalanceHidden);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
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

          // Hiển thị số dư (đã xoá nút nạp tiền khỏi card)
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
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Grid 6 nút Dịch vụ & Tính năng ---
  Widget _buildServicesGrid(BuildContext context, AuthUser? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dịch vụ & Tính năng',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
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
                onTap: () => setState(() => _currentBottomNavIndex = 1),
              ),
              _featureButton(
                label: 'L.sử giao dịch',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF7B1FA2),
                onTap: _openHistoryTab,
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
                onTap: () => _openSpendingJarsScreen(context),
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
      ],
    );
  }

  /// Banner Quản trị viên
  Widget _buildAdminSection(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
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
              color: Colors.orange.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 24,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Xem danh sách tài khoản & tra cứu người dùng',
                    style: TextStyle(fontSize: 11, color: Color(0xFFBF360C)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFE65100),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Khối Hoạt động gần đây
  Widget _buildRecentActivitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Hoạt động gần đây',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _openHistoryTab,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Xem tất cả',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.lightBlueDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTransactionHistoryCard(context),
      ],
    );
  }

  Widget _buildTransactionHistoryCard(BuildContext context) {
    return InkWell(
      onTap: _openHistoryTab,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.lightBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.lightBlueDark,
                size: 22,
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

  /// Khối Ưu đãi & Tiện ích
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
        _buildPromoCard(
          context: context,
          icon: Icons.savings_rounded,
          iconColor: const Color(0xFFE53935),
          title: 'Lập quỹ tiết kiệm cho bản thân và gia đình',
          subtitle: 'Tạo quỹ cá nhân, cặp đôi, tích luỹ, ...',
          onTap: () => _openFundsScreen(context),
        ),
        const SizedBox(height: 10),
        _buildPromoCard(
          context: context,
          icon: Icons.all_inbox_rounded,
          iconColor: const Color(0xFF00838F),
          title: 'Chi tiêu tháng $currentMonth',
          subtitle: updateTimeStr,
          onTap: () => _openSpendingJarsScreen(context),
        ),
      ],
    );
  }

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
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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

  Widget _featureButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    bool hasBorder = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: hasBorder
              ? Border.all(color: const Color(0xFFFFB74D), width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
