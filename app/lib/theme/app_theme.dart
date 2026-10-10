import 'package:flutter/material.dart';

/// Độ dài tối thiểu của mật khẩu, phải khớp với server (MIN_PASSWORD_LENGTH).
const int kMinPasswordLength = 6;

/// Độ dài tối đa của tên tài khoản, phải khớp với server (maxNameLength).
const int kMaxAccountLength = 100;

/// Bảng màu của ứng dụng (xanh dương nhạt làm màu chủ đạt).
class AppColors {
  AppColors._();

  static const Color lightBlue = Color(0xFF03A9F4);
  static const Color lightBlueDark = Color(0xFF0288D1);
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF16202E);
  static const Color textSecondary = Color(0xFF71808F);
  static const Color border = Color(0xFFDCE4ED);
  static const Color error = Color(0xFFE53935);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.lightBlue,
        primary: AppColors.lightBlue,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lightBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      ),
    );
  }
}