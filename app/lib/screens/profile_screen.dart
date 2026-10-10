import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/back_label.dart';
import '../widgets/error_message.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';

/// Màn hình Trang cá nhân: hiển thị thông tin tài khoản, số dư,
/// cài đặt mã PIN giao dịch, đổi mật khẩu và đăng xuất qua API server.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;
  String? _error;
  int _transactionCount = 0;
  int _fundCount = 0;
  int _jarCount = 0;
  bool _hasPin = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = AppScope.of(context);
      // Gọi song song các API từ server
      final walletFuture = session.fetchWallet();
      final profileFuture = session.fetchProfile();
      final txFuture = session.fetchTransactions();
      final fundsFuture = session.fetchFunds();
      final jarsFuture = session.fetchSpendingJars();

      final results = await Future.wait([
        walletFuture.catchError((_) => <String, dynamic>{}),
        profileFuture.catchError((_) => <String, dynamic>{}),
        txFuture.catchError((_) => <String, dynamic>{}),
        fundsFuture.catchError((_) => <String, dynamic>{}),
        jarsFuture.catchError((_) => <String, dynamic>{}),
      ]);

      if (!mounted) return;

      final profileData = results[1];
      final txData = results[2];
      final fundsData = results[3];
      final jarsData = results[4];

      final userMap = profileData['user'] as Map<String, dynamic>?;
      final txList = txData['data'] as List?;
      final fundsList = fundsData['data'] as List?;
      final jarsList = jarsData['data'] as List?;

      setState(() {
        _hasPin = userMap?['hasPin'] as bool? ?? session.user?.hasPin ?? false;
        _transactionCount = txList?.length ?? txData['count'] as int? ?? 0;
        _fundCount = fundsList?.length ?? fundsData['count'] as int? ?? 0;
        _jarCount = jarsList?.length ?? jarsData['count'] as int? ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      // Bỏ qua lỗi mạng nền
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await AppScope.of(context).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSetPinDialog() {
    final passwordController = TextEditingController();
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.pin_outlined, color: AppColors.lightBlue),
              SizedBox(width: 8),
              Text('Cài đặt mã PIN giao dịch', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mã PIN gồm 4-6 chữ số dùng để xác thực khi thực hiện giao dịch nạp tiền, nạp thẻ hoặc thanh toán.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu tài khoản',
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.lightBlue),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng nhập mật khẩu' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mã PIN mới (4 - 6 số)',
                      prefixIcon: Icon(Icons.dialpad_rounded, color: AppColors.lightBlue),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || !RegExp(r'^\d{4,6}$').hasMatch(v)) {
                        return 'Mã PIN phải từ 4 đến 6 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Xác nhận mã PIN mới',
                      prefixIcon: Icon(Icons.lock_reset_rounded, color: AppColors.lightBlue),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v != pinController.text) {
                        return 'Mã PIN xác thực không khớp';
                      }
                      return null;
                    },
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    ErrorMessage(message: dialogError!),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      final navigator = Navigator.of(dialogCtx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await AppScope.of(dialogCtx).setPin(
                          password: passwordController.text,
                          pin: pinController.text,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        setState(() => _hasPin = true);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Lưu mã PIN giao dịch thành công!')),
                        );
                      } on ApiException catch (e) {
                        setDialogState(() => dialogError = e.message);
                      } catch (_) {
                        setDialogState(() => dialogError = 'Không thể lưu mã PIN, vui lòng thử lại');
                      } finally {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu mã PIN'),
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
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          color: AppColors.lightBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kIPhone18Width),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nút quay lại trang chủ
                    BackLabel(
                      onTap: () => Navigator.of(context).pop(),
                      text: 'Trang chủ',
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: AppColors.lightBlue,
                      ),
                    const SizedBox(height: 12),

                    // Card thông tin cá nhân chính (Hero Card)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // Avatar hình vuông tròn (Squircle Avatar)
                          Container(
                            width: 76,
                            height: 76,
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
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                (user?.name.isNotEmpty == true)
                                    ? user!.name.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            user?.name ?? 'Người dùng',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Badge thành viên
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.verified_rounded, size: 15, color: AppColors.lightBlue),
                                SizedBox(width: 4),
                                Text(
                                  'Tài khoản đã xác thực',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.lightBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      ErrorMessage(message: _error!),
                    ],

                    const SizedBox(height: 20),

                    // 1. Thống kê nhanh tài chính gom vào 1 vùng lớn, không viền từng ô, màu chữ khớp màu icon
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statItem(
                              icon: Icons.receipt_long_rounded,
                              label: 'Giao dịch',
                              value: '$_transactionCount',
                              color: const Color(0xFF7B1FA2),
                            ),
                          ),
                          Container(height: 36, width: 1, color: AppColors.border.withValues(alpha: 0.8)),
                          Expanded(
                            child: _statItem(
                              icon: Icons.savings_rounded,
                              label: 'Quỹ chung',
                              value: '$_fundCount',
                              color: const Color(0xFFE53935),
                            ),
                          ),
                          Container(height: 36, width: 1, color: AppColors.border.withValues(alpha: 0.8)),
                          Expanded(
                            child: _statItem(
                              icon: Icons.pie_chart_rounded,
                              label: 'Hũ chi tiêu',
                              value: '$_jarCount',
                              color: const Color(0xFF00838F),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Bảo mật & Cài đặt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Vùng lớn gom nhóm các tính năng Cài đặt & Bảo mật
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _menuRow(
                            icon: Icons.pin_outlined,
                            iconColor: AppColors.lightBlue,
                            title: 'Mã PIN giao dịch',
                            subtitle: _hasPin ? 'Đã cài đặt mã PIN bảo vệ' : 'Chưa cài đặt mã PIN',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (_hasPin ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _hasPin ? 'Thay đổi' : 'Cài đặt',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _hasPin ? Colors.green[700] : Colors.orange[800],
                                ),
                              ),
                            ),
                            onTap: _showSetPinDialog,
                            isTop: true,
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: AppColors.border),
                          _menuRow(
                            icon: Icons.lock_reset_rounded,
                            iconColor: Colors.indigo,
                            title: 'Đổi mật khẩu',
                            subtitle: 'Cập nhật mật khẩu đăng nhập tài khoản',
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            onTap: () {
                              openChangePasswordScreen(context);
                            },
                            isBottom: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Nút Đăng xuất
                    AppButton(
                      text: 'Đăng xuất tài khoản',
                      style: AppButtonStyle.outline,
                      icon: Icons.logout_rounded,
                      isLoading: _isLoggingOut,
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mục thống kê không viền, nổi bật icon và chữ với màu chữ đồng bộ màu icon
  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Dòng chức năng cài đặt không viền trong vùng lớn, màu chữ đồng bộ màu icon
  Widget _menuRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    bool isTop = false,
    bool isBottom = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(20) : Radius.zero,
          bottom: isBottom ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Mở màn hình trang cá nhân
void openProfileScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
  );
}
