import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../state/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/back_label.dart';
import '../widgets/error_message.dart';

/// Màn hình đổi mật khẩu: Mật khẩu cũ + Mật khẩu mới + Xác thực mật khẩu.
/// Gọi API POST /api/auth/change-password của server.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AppScope.of(context).changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmNewPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công')),
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
                          'Đổi mật khẩu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Nhập mật khẩu cũ và mật khẩu mới của bạn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        AuthTextField(
                          label: 'Mật khẩu cũ',
                          hintText: 'Nhập mật khẩu hiện tại',
                          icon: Icons.lock_outline_rounded,
                          controller: _currentPasswordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu cũ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          label: 'Mật khẩu mới',
                          hintText: 'Tối thiểu $kMinPasswordLength ký tự',
                          icon: Icons.lock_reset_rounded,
                          controller: _newPasswordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu mới';
                            }
                            if (value.length < kMinPasswordLength) {
                              return 'Mật khẩu mới tối thiểu $kMinPasswordLength ký tự';
                            }
                            if (value == _currentPasswordController.text) {
                              return 'Mật khẩu mới phải khác mật khẩu cũ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          label: 'Xác thực mật khẩu',
                          hintText: 'Nhập lại mật khẩu mới',
                          icon: Icons.verified_user_outlined,
                          controller: _confirmPasswordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) { _handleChangePassword(); },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác thực mật khẩu mới';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Xác thực mật khẩu không khớp';
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
                          text: 'Xác nhận đổi mật khẩu',
                          isLoading: _isLoading,
                          onPressed: _handleChangePassword,
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

/// Mở màn hình đổi mật khẩu từ trang chủ.
void openChangePasswordScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen()),
  );
}