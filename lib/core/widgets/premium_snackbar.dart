import 'package:flutter/material.dart';

class PremiumSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    required SnackBarType type,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case SnackBarType.success:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        break;
      case SnackBarType.error:
        icon = Icons.error_rounded;
        color = const Color(0xFFEF4444);
        break;
      case SnackBarType.info:
        icon = Icons.info_rounded;
        color = const Color(0xFF3B82F6);
        break;
      case SnackBarType.warning:
        icon = Icons.warning_rounded;
        color = const Color(0xFFF59E0B);
        break;
    }

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}

enum SnackBarType { success, error, info, warning }
