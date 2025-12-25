import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MotivationalQuote extends StatelessWidget {
  final String quote;
  final bool isSmallScreen;

  const MotivationalQuote({
    super.key,
    required this.quote,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0,
        vertical: isSmallScreen ? 2.0 : 4.0,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.1),
            AppColors.gradientPurpleStart.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.format_quote,
              color: AppColors.primaryBlue,
              size: isSmallScreen ? 14.0 : 18.0,
            ),
          ),
          SizedBox(width: isSmallScreen ? 8.0 : 12.0),
          Expanded(
            child: Text(
              quote,
              style: TextStyle(
                fontSize: isSmallScreen ? 10.0 : 12.0,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
