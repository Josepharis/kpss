import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ContentSectionCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const ContentSectionCard({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.isSmallScreen = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isSmallScreen ? 16.0 : 18.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 28 : 32,
                  color: color,
                ),
              ),
              SizedBox(width: isSmallScreen ? 16 : 20),
              // Title and count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      '$count içerik',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: isSmallScreen ? 18 : 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

