import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/info_card.dart';
import '../widgets/info_card_widget.dart';

class InfoCardsListPage extends StatelessWidget {
  final List<InfoCard> infoCards;

  const InfoCardsListPage({
    super.key,
    required this.infoCards,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Bilgi Kartları',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: infoCards.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz bilgi kartı eklenmemiş',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                crossAxisSpacing: isSmallScreen ? 12 : 16,
                mainAxisSpacing: isSmallScreen ? 12 : 16,
                childAspectRatio: isTablet ? 0.75 : 0.8,
              ),
              itemCount: infoCards.length,
              itemBuilder: (context, index) {
                final infoCard = infoCards[index];
                return InfoCardWidget(
                  infoCard: infoCard,
                  isSmallScreen: isSmallScreen,
                );
              },
            ),
    );
  }
}
