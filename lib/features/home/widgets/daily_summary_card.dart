import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/daily_summary.dart';

class DailySummaryCard extends StatelessWidget {
  final DailySummary summary;
  final bool isSmallScreen;

  const DailySummaryCard({
    super.key,
    required this.summary,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: isSmallScreen ? 2.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8.0 : 10.0,
              vertical: isSmallScreen ? 6.0 : 8.0,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryDarkBlue,
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSmallScreen ? 10.0 : 12.0),
                topRight: Radius.circular(isSmallScreen ? 10.0 : 12.0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.today_outlined,
                  color: Colors.white,
                  size: isSmallScreen ? 12.0 : 14.0,
                ),
                SizedBox(width: isSmallScreen ? 3.0 : 5.0),
                Flexible(
                  child: Text(
                    'Günlük Özet',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10.0 : 12.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 4.0 : 5.0,
                    vertical: isSmallScreen ? 1.5 : 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _getFormattedDate(),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 8.0 : 9.0,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stats
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8.0 : 10.0,
              vertical: isSmallScreen ? 6.0 : 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.quiz_outlined,
                  value: '${summary.solvedQuestions}',
                  label: 'Soru',
                  color: AppColors.primaryBlue,
                  isSmallScreen: isSmallScreen,
                ),
                _buildDivider(isSmallScreen: isSmallScreen),
                _buildStatItem(
                  icon: Icons.access_time_outlined,
                  value: summary.studyTimeFormatted,
                  label: 'Süre',
                  color: AppColors.gradientYellowStart,
                  isSmallScreen: isSmallScreen,
                ),
                _buildDivider(isSmallScreen: isSmallScreen),
                _buildStatItem(
                  icon: Icons.menu_book_outlined,
                  value: '${summary.lessonCount}',
                  label: 'Ders',
                  color: AppColors.gradientRedStart,
                  isSmallScreen: isSmallScreen,
                ),
                _buildDivider(isSmallScreen: isSmallScreen),
                _buildStatItem(
                  icon: Icons.trending_up_outlined,
                  value: '${summary.successRate.toStringAsFixed(0)}%',
                  label: 'Başarı',
                  color: AppColors.gradientPurpleStart,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${now.day} ${months[now.month - 1]}';
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 4.0 : 5.0),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 14.0 : 16.0,
              color: color,
            ),
          ),
          SizedBox(height: isSmallScreen ? 3.0 : 4.0),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 10.0 : 12.0,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 1.0 : 2.0),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 7.0 : 8.0,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider({required bool isSmallScreen}) {
    return Container(
      width: 1,
      height: isSmallScreen ? 28.0 : 32.0,
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 3.0 : 4.0),
      color: AppColors.progressGray,
    );
  }
}
