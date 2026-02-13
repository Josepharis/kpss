import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../main.dart';

/// Şık, yuvarlak sadece ev ikonlu buton.
/// Bunu `Scaffold.floatingActionButton` içinde kullanacağız.
class FloatingHomeButton extends StatelessWidget {
  const FloatingHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 10), // Move it 10 pixels down
      child: GestureDetector(
        onTap: () {
          // Nerede olursa olsun anasayfaya dön (tab: 0).
          // - Eğer zaten MainScreen altındaysak: tab'ı 0'a al.
          // - Değilse: root navigator üzerinden stack'i sıfırlayıp /home'a git.
          try {
            final main = MainScreen.of(context);
            if (main != null) {
              main.navigateToTab(0);
              return;
            }
          } catch (_) {
            // Ignore and fallback to route reset.
          }
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, AppColors.primaryDarkBlue],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
