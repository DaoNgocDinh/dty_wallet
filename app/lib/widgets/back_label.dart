import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Nhãn "Trở về" nằm bên trái, dùng thay cho nút.
class BackLabel extends StatelessWidget {
  const BackLabel({super.key, required this.onTap, this.text = 'Trở về'});

  final VoidCallback onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: text,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded,
                    size: 18, color: AppColors.lightBlue),
                const SizedBox(width: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}