import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/info_card.dart';
import 'info_card_widget.dart';
import '../pages/info_cards_list_page.dart';

class InfoCardsSection extends StatelessWidget {
  final List<InfoCard> infoCards;
  final bool isSmallScreen;
  final double availableHeight;

  const InfoCardsSection({
    super.key,
    required this.infoCards,
    this.isSmallScreen = false,
    this.availableHeight = 130.0,
  });

  @override
  Widget build(BuildContext context) {
    if (infoCards.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cardHeight = isSmallScreen ? 105.0 : 115.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24.0 : 16.0,
            vertical: isSmallScreen ? 4.0 : 6.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InfoCardsListPage(
                        infoCards: infoCards,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: isSmallScreen ? 16.0 : 18.0,
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    Text(
                      'Bilgi Kartları',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 18.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InfoCardsListPage(
                        infoCards: infoCards,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8.0 : 12.0,
                    vertical: isSmallScreen ? 4.0 : 8.0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Hepsi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11.0 : 13.0,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24.0 : 16.0,
            ),
            itemCount: infoCards.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < infoCards.length - 1 ? (isSmallScreen ? 10.0 : 12.0) : 0,
                ),
                child: InfoCardWidget(
                  infoCard: infoCards[index],
                  isSmallScreen: isSmallScreen,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

