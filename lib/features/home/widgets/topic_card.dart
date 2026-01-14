import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const TopicCard({
    super.key,
    required this.topic,
    this.isSmallScreen = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = isSmallScreen ? 16.0 : 18.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : AppColors.cardShadow;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final progressBgColor = isDark ? Colors.white.withOpacity(0.1) : AppColors.backgroundLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
          child: Row(
            children: [
              // Topic info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6 : 8,
                            vertical: isSmallScreen ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: isSmallScreen ? 12 : 14,
                                color: AppColors.primaryBlue,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Ortalama ${topic.averageQuestionCount} soru',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              // Progress and arrow
              Column(
                children: [
                  // Progress indicator
                  SizedBox(
                    width: isSmallScreen ? 50 : 60,
                    height: isSmallScreen ? 50 : 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: isSmallScreen ? 50 : 60,
                          height: isSmallScreen ? 50 : 60,
                          child: CircularProgressIndicator(
                            value: topic.progress,
                            strokeWidth: isSmallScreen ? 4 : 5,
                            backgroundColor: progressBgColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        Text(
                          '${(topic.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: isSmallScreen ? 16 : 18,
                    color: secondaryTextColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

