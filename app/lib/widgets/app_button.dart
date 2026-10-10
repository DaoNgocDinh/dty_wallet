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
    this.width,
    this.height = 52,
    this.fontSize = 16,
    this.padding,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool isLoading;

  /// null: nút chiếm hết chiều ngang. Truyền số để giới hạn bề rộng.
  final double? width;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isFilled = style == AppButtonStyle.filled;
    final foreground = isFilled ? Colors.white : AppColors.lightBlue;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isFilled ? AppColors.lightBlue : Colors.white,
          foregroundColor: foreground,
          padding: padding ?? (width != null ? const EdgeInsets.symmetric(horizontal: 6) : null),
          disabledBackgroundColor: isFilled
              ? AppColors.lightBlue.withValues(alpha: 0.5)
              : Colors.white,
          disabledForegroundColor: foreground.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isFilled
                ? BorderSide.none
                : const BorderSide(color: AppColors.lightBlue, width: 1.4),
          ),
          textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foreground,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        text,
                        maxLines: 1,
                        style: TextStyle(
                          color: foreground,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
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
