import 'package:flutter/material.dart';

class DailyQuoteCard extends StatelessWidget {
  final String quote;
  final bool isSmallScreen;
  final bool isCompactLayout;

  const DailyQuoteCard({
    super.key,
    required this.quote,
    this.isSmallScreen = false,
    this.isCompactLayout = false,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallDevice = screenHeight < 700;
    final quoteText = quote.isNotEmpty ? quote : _getQuoteOfDay();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Responsive padding & sizing (tablet yatayda kompakt mod)
    final horizontalMargin = isCompactLayout ? 0.0 : (isTablet ? 24.0 : 16.0);
    final cardPadding = isCompactLayout ? 12.0 : (isSmallDevice ? 12.0 : 14.0);
    final iconSize = isCompactLayout ? 22.0 : (isSmallDevice ? 24.0 : 28.0);
    final titleFontSize = isCompactLayout ? 9.0 : (isSmallDevice ? 10.0 : 11.0);
    final quoteFontSize = isCompactLayout ? 11.5 : (isSmallDevice ? 12.5 : 13.5);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: isCompactLayout ? 4.0 : (isSmallDevice ? 4.0 : 6.0),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [
                const Color(0xFF2C3E50).withValues(alpha: 0.9),
                const Color(0xFF34495E).withValues(alpha: 0.85),
              ]
            : [
                const Color(0xFF667EEA),
                const Color(0xFF764BA2),
              ],
        ),
        borderRadius: BorderRadius.circular(isSmallDevice ? 14.0 : 16.0),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withValues(alpha: 0.4)
              : const Color(0xFF667EEA).withValues(alpha: 0.3),
            blurRadius: isSmallDevice ? 10 : 12,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -24,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Quote Icon
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(isSmallDevice ? 9 : 10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.25,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.format_quote_rounded,
                      color: Colors.white,
                      size: isSmallDevice ? 16.0 : 18.0,
                    ),
                  ),
                ),
                SizedBox(width: isSmallDevice ? 10.0 : 12.0),
                // Quote Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title with decorative line
                      Row(
                        children: [
                          Text(
                            'GÜNÜN SÖZÜ',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.95),
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 1.25,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.5),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallDevice ? 6.0 : 7.0),
                      // Quote Text
                      Text(
                        '"$quoteText"',
                        style: TextStyle(
                          fontSize: quoteFontSize,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.3,
                        ),
                        maxLines: isSmallDevice ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
