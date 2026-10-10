import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_logo.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'test_login_screen.dart';

/// Trang chủ tạm thời: nút Đổi mật khẩu và Đăng xuất nằm trên cùng bên phải,
/// mỗi nút rộng bằng 1/5 bề ngang giao diện.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _walletMessage;
  String? _walletError;
  bool _loadedWallet = false;
  bool _isLoggingOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gọi ở didChangeDependencies vì cần truy cập AppScope qua context.
    if (!_loadedWallet) {
      _loadedWallet = true;
      _loadWallet();
    }
  }

  /// Gọi API cần token để kiểm tra phiên đăng nhập còn hiệu lực.
  Future<void> _loadWallet() async {
    try {
      final wallet = await AppScope.of(context).fetchWallet();
      if (!mounted) return;
      setState(() => _walletMessage = 'Số dư: ${wallet['walletBalance'] ?? 0}');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _walletError = error.message);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    await AppScope.of(context).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    // Mỗi nút rộng bằng 1/5 bề ngang giao diện.
    final buttonWidth = MediaQuery.sizeOf(context).width / 5;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => openTestLoginScreen(context),
                    icon: const Icon(Icons.science_outlined),
                    color: AppColors.lightBlue,
                    tooltip: 'Màn hình test đăng nhập',
                  ),
                  SizedBox(
                    width: buttonWidth,
                    child: AppButton(
                      text: 'Đổi mật khẩu',
                      style: AppButtonStyle.outline,
                      height: 40,
                      fontSize: 13,
                      onPressed: () => openChangePasswordScreen(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: buttonWidth,
                    child: AppButton(
                      text: 'Đăng xuất',
                      height: 40,
                      fontSize: 13,
                      isLoading: _isLoggingOut,
                      onPressed: _logout,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(size: 96),
                        const SizedBox(height: 24),
                        Text(
                          'Xin chào, ${user?.name ?? ''}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_walletMessage != null)
                          Text(
                            _walletMessage!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lightBlue,
                            ),
                          )
                        else if (_walletError != null)
                          Text(
                            _walletError!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
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
      ),
    );
  }
}