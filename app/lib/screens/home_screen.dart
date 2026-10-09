import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';
import 'test_login_screen.dart';

/// Màn hình chính, hiển thị sau khi đăng nhập thành công.
/// TODO: thay nội dung này bằng trang chủ thật của ứng dụng ví.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _walletMessage;
  String? _walletError;
  bool _loadedWallet = false;

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

  void _logout() {
    AppScope.of(context).logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví điện tử'),
        actions: [
          IconButton(
            tooltip: 'Test đăng nhập',
            icon: const Icon(Icons.science_outlined),
            color: AppColors.lightBlue,
            onPressed: () => openTestLoginScreen(context),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: AppColors.lightBlue),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
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
                const SizedBox(height: 24),
                AppButton(
                  text: 'Test tính năng đăng nhập',
                  style: AppButtonStyle.outline,
                  icon: Icons.science_outlined,
                  onPressed: () => openTestLoginScreen(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
