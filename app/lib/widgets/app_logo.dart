import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo nằm giữa màn hình, lấy từ assets/images/logo.png.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.lightBlue.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        // Nếu chưa có file logo.png thì hiển thị icon mặc định thay vì crash.
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.account_balance_wallet_rounded,
          color: AppColors.lightBlue,
          size: 48,
        ),
      ),
    );
  }
}