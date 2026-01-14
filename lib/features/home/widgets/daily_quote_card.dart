import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class DailyQuoteCard extends StatelessWidget {
  final String quote;
  final bool isSmallScreen;

  const DailyQuoteCard({
    super.key,
    required this.quote,
    this.isSmallScreen = false,
  });

  String _getQuoteOfDay() {
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    
    final quotes = [
      'Başarı, hazırlık ve fırsatın buluştuğu noktadır.',
      'Bugün yaptığın çalışma, yarının başarısını belirler.',
      'Her soru, seni hedefine bir adım daha yaklaştırır.',
      'Azim ve sabır, başarının anahtarıdır.',
      'Çalışmak, hayallerini gerçeğe dönüştüren tek yoldur.',
      'Başarısızlık, başarının öğretmenidir.',
      'Küçük adımlar, büyük hedeflere götürür.',
      'Disiplin, yetenekten daha önemlidir.',
      'Her gün biraz daha iyi ol, dününden daha iyi.',
      'Hedefin yoksa, her yol seni bir yere götürür.',
    ];
    
    return quotes[dayOfYear % quotes.length];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final quoteText = quote.isNotEmpty ? quote : _getQuoteOfDay();

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: isSmallScreen ? 4.0 : 6.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.12),
            AppColors.gradientPurpleStart.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 14.0),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12.0 : 14.0,
          vertical: isSmallScreen ? 10.0 : 12.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quote icon - compact
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6.0 : 7.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.gradientPurpleStart,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.format_quote_rounded,
                color: Colors.white,
                size: isSmallScreen ? 16.0 : 18.0,
              ),
            ),
            SizedBox(width: isSmallScreen ? 10.0 : 12.0),
            // Quote text - compact single line
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final textColor = isDark ? Colors.white : AppColors.textPrimary;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Günün Sözü',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 9.0 : 10.0,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 4.0 : 5.0),
                          Text(
                            quoteText,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11.0 : 12.0,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                              height: 1.4,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
