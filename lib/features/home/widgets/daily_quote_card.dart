import 'package:flutter/material.dart';
import 'dart:ui';

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
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
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
    final quoteText = quote.isNotEmpty ? quote : _getQuoteOfDay();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF6366F1))
                .withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.65)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFF6366F1).withOpacity(0.12),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.format_quote_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GÜNÜN İLHAMI',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF4F46E5),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quoteText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withOpacity(0.9)
                                : const Color(0xFF1E293B),
                            height: 1.2,
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
      ),
    );
  }
}
