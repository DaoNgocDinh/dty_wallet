import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/back_label.dart';
import '../widgets/error_message.dart';

/// Độ dài tối thiểu của mật khẩu, phải khớp với server (MIN_PASSWORD_LENGTH).
const int kMinPasswordLength = 6;

/// Màn hình đăng ký: Tài khoản + Mật khẩu + Xác thực mật khẩu.
/// Nhãn "Trở về" nằm trên cùng bên trái để quay lại màn hình đăng nhập.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AppScope.of(context).register(
        account: _accountController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đăng ký thành công tài khoản "${_accountController.text.trim()}"',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BackLabel(onTap: _goBack),
                        const SizedBox(height: 20),
                        const Center(child: AppLogo(size: 112)),
                        const SizedBox(height: 24),
                        const Text(
                          'Đăng ký',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tạo tài khoản mới để sử dụng ví điện tử',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AuthTextField(
                          label: 'Tài khoản',
                          hintText: 'Nhập tài khoản của bạn',
                          icon: Icons.person_outline_rounded,
                          controller: _accountController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập tài khoản';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          label: 'Mật khẩu',
                          hintText: 'Tối thiểu $kMinPasswordLength ký tự',
                          icon: Icons.lock_outline_rounded,
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (value.length < kMinPasswordLength) {
                              return 'Mật khẩu tối thiểu $kMinPasswordLength ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          label: 'Xác thực mật khẩu',
                          hintText: 'Nhập lại mật khẩu',
                          icon: Icons.lock_reset_rounded,
                          controller: _confirmPasswordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) { _handleRegister(); },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác thực mật khẩu';
                            }
                            if (value != _passwordController.text) {
                              return 'Mật khẩu xác thực không khớp';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          ErrorMessage(message: _error!),
                        ],
                        const SizedBox(height: 28),
                        AppButton(
                          text: 'Xác nhận đăng ký',
                          isLoading: _isLoading,
                          onPressed: _handleRegister,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}