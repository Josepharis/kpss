import 'package:flutter/material.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import '../constants/app_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? const Color(0xFF2D2D2D) : AppColors.backgroundWhite;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : AppColors.primaryLightBlue.withValues(alpha: 0.08);
    final inactiveColor = isDark ? Colors.white54 : AppColors.navInactive;
    final labelColor = isDark ? Colors.white70 : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CurvedNavigationBar(
        index: currentIndex,
        color: barColor,
        backgroundColor: backgroundColor,
        buttonBackgroundColor: barColor,
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 300),
        height: 62,
        onTap: onTap,
      items: [
        CurvedNavigationBarItem(
          child: Icon(
            Icons.home_rounded,
            size: 26,
            color: currentIndex == 0 ? AppColors.navActive : inactiveColor,
          ),
          label: 'Ana Sayfa',
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: currentIndex == 0 ? FontWeight.w600 : FontWeight.w500,
            color: currentIndex == 0 ? AppColors.navActive : labelColor,
          ),
        ),
        CurvedNavigationBarItem(
          child: Icon(
            Icons.menu_book_rounded,
            size: 26,
            color: currentIndex == 1 ? AppColors.navActive : inactiveColor,
          ),
          label: 'Dersler',
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: currentIndex == 1 ? FontWeight.w600 : FontWeight.w500,
            color: currentIndex == 1 ? AppColors.navActive : labelColor,
          ),
        ),
        CurvedNavigationBarItem(
          child: Icon(
            Icons.bookmark_rounded,
            size: 26,
            color: currentIndex == 2 ? AppColors.navActive : inactiveColor,
          ),
          label: 'Kaydedilenler',
          labelStyle: TextStyle(
            fontSize: 10,
            fontWeight: currentIndex == 2 ? FontWeight.w600 : FontWeight.w500,
            color: currentIndex == 2 ? AppColors.navActive : labelColor,
          ),
        ),
        CurvedNavigationBarItem(
          child: Icon(
            Icons.school_rounded,
            size: 26,
            color: currentIndex == 3 ? AppColors.navActive : inactiveColor,
          ),
          label: 'Çalışma',
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: currentIndex == 3 ? FontWeight.w600 : FontWeight.w500,
            color: currentIndex == 3 ? AppColors.navActive : labelColor,
          ),
        ),
        CurvedNavigationBarItem(
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 26,
            color: currentIndex == 4 ? AppColors.navActive : inactiveColor,
          ),
          label: 'AI',
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: currentIndex == 4 ? FontWeight.w600 : FontWeight.w500,
            color: currentIndex == 4 ? AppColors.navActive : labelColor,
          ),
        ),
        CurvedNavigationBarItem(
          child: Icon(
            Icons.person_rounded,
            size: 26,
            color: currentIndex == 5 ? AppColors.navActive : inactiveColor,
          ),
          label: 'Profil',
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: currentIndex == 5 ? FontWeight.w600 : FontWeight.w500,
            color: currentIndex == 5 ? AppColors.navActive : labelColor,
          ),
        ),
      ],
      ),
    );
  }
}
