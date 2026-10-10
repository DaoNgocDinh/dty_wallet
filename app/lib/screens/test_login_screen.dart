import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/error_message.dart';

/// Màn hình test tính năng đăng nhập: nhập tài khoản / mật khẩu rồi gọi
/// POST /api/auth/login và hiển thị kết quả trả về từ server.
class TestLoginScreen extends StatefulWidget {
  const TestLoginScreen({super.key, this.authService});

  /// Dùng cho test: truyền vào [AuthService] giả.
  final AuthService? authService;

  @override
  State<TestLoginScreen> createState() => _TestLoginScreenState();
}

class _TestLoginScreenState extends State<TestLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: '123456');
  late final AuthService _authService = widget.authService ?? AuthService();

  bool _isLoading = false;
  bool _isCheckingToken = false;
  String? _error;
  AuthResult? _result;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runLoginTest() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await _authService.login(
        account: _accountController.text,
        password: _passwordController.text,
      );
      if (mounted) setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Kiểm tra token vừa nhận được có dùng được cho API khác không.
  Future<void> _runTokenTest() async {
    final token = _result?.token;
    if (token == null) return;
    setState(() => _isCheckingToken = true);

    try {
      await _authService.wallet(token);
      if (mounted) {
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token hợp lệ: GET /api/wallet thành công'),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token không hợp lệ: ${error.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingToken = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Test đăng nhập')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API đang test',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'POST $kApiBaseUrl/auth/login',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      label: 'Tài khoản',
                      icon: Icons.person_outline_rounded,
                      controller: _accountController,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Nhập tài khoản'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    AuthTextField(
                      label: 'Mật khẩu',
                      icon: Icons.lock_outline_rounded,
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        _runLoginTest();
                      },
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Nhập mật khẩu'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Test đăng nhập',
                      icon: Icons.play_arrow_rounded,
                      isLoading: _isLoading,
                      onPressed: _runLoginTest,
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Kiểm tra token (GET /api/wallet)',
                        style: AppButtonStyle.outline,
                        isLoading: _isCheckingToken,
                        onPressed: _runTokenTest,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'KẾT QUẢ: THẤT BẠI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ErrorMessage(message: _error!),
                    ],
                    if (result != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'KẾT QUẢ: THÀNH CÔNG',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow('Tên tài khoản', result.user.name),
                            _infoRow('Email', result.user.email),
                            _infoRow(
                              'Số dư',
                              result.user.walletBalance.toStringAsFixed(0),
                            ),
                            _infoRow('Token', _shortToken(result.token)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mở màn hình test từ màn hình chính (giữ phiên đăng nhập hiện tại).
void openTestLoginScreen(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const TestLoginScreen()));
}

/// Rút gọn token cho dễ đọc.
String _shortToken(String token) =>
    token.length <= 24 ? token : '${token.substring(0, 24)}...';
