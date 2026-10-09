import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppButtonStyle { filled, outline }

/// Nút dùng chung cho toàn bộ giao diện.
/// - [AppButtonStyle.filled]: nền xanh dương nhạt, chữ trắng.
/// - [AppButtonStyle.outline]: nền trắng, chữ xanh dương nhạt.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool isLoading;

  /// true: nút chiếm hết chiều ngang. false: nút vừa đủ bề rộng nội dung.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isFilled = style == AppButtonStyle.filled;
    final foreground = isFilled ? Colors.white : AppColors.lightBlue;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isFilled ? AppColors.lightBlue : Colors.white,
          foregroundColor: foreground,
          disabledBackgroundColor:
              isFilled ? AppColors.lightBlue.withValues(alpha: 0.5) : Colors.white,
          disabledForegroundColor: foreground.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isFilled
                ? BorderSide.none
                : const BorderSide(color: AppColors.lightBlue, width: 1.4),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: foreground),
                    const SizedBox(width: 8),
                  ],
                  Text(text, style: TextStyle(color: foreground)),
                ],
              ),
      ),
    );
  }
}