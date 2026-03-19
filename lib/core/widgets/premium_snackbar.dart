import 'package:flutter/material.dart';
import 'dart:ui';

class PremiumSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    required SnackBarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    IconData icon;
    Color baseColor;
    String defaultTitle;

    switch (type) {
      case SnackBarType.success:
        icon = Icons.check_circle_outline_rounded;
        baseColor = const Color(0xFF10B981);
        defaultTitle = 'Başarılı';
        break;
      case SnackBarType.error:
        icon = Icons.error_outline_rounded;
        baseColor = const Color(0xFFEF4444);
        defaultTitle = 'Hata';
        break;
      case SnackBarType.info:
        icon = Icons.info_outline_rounded;
        baseColor = const Color(0xFF3B82F6);
        defaultTitle = 'Bilgi';
        break;
      case SnackBarType.warning:
        icon = Icons.warning_amber_rounded;
        baseColor = const Color(0xFFF59E0B);
        defaultTitle = 'Uyarı';
        break;
    }

    final effectiveTitle = title ?? defaultTitle;
    final gradient = LinearGradient(
      colors: [
        baseColor,
        baseColor.withValues(alpha: 0.8),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effectiveTitle.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}

enum SnackBarType { success, error, info, warning }

