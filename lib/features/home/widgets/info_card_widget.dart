import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/info_card.dart';
import '../pages/flash_cards_page.dart';

class InfoCardWidget extends StatelessWidget {
  final InfoCard infoCard;
  final bool isSmallScreen;

  const InfoCardWidget({
    super.key,
    required this.infoCard,
    this.isSmallScreen = false,
  });

  Color _getGradientStartColor() {
    switch (infoCard.color) {
      case 'blue':
        return AppColors.gradientBlueStart;
      case 'yellow':
        return AppColors.gradientYellowStart;
      case 'red':
        return AppColors.gradientRedStart;
      case 'purple':
        return AppColors.gradientPurpleStart;
      case 'green':
        return AppColors.gradientGreenStart;
      case 'orange':
        return AppColors.gradientOrangeStart;
      case 'teal':
        return AppColors.gradientTealStart;
      case 'pink':
        return const Color(0xFFE91E63);
      default:
        return AppColors.gradientBlueStart;
    }
  }

  Color _getGradientEndColor() {
    switch (infoCard.color) {
      case 'blue':
        return AppColors.gradientBlueEnd;
      case 'yellow':
        return AppColors.gradientYellowEnd;
      case 'red':
        return AppColors.gradientRedEnd;
      case 'purple':
        return AppColors.gradientPurpleEnd;
      case 'green':
        return AppColors.gradientGreenEnd;
      case 'orange':
        return AppColors.gradientOrangeEnd;
      case 'teal':
        return AppColors.gradientTealEnd;
      case 'pink':
        return const Color(0xFFC2185B);
      default:
        return AppColors.gradientBlueEnd;
    }
  }

  IconData _getIcon() {
    switch (infoCard.icon) {
      case 'info':
        return Icons.info_rounded;
      case 'book':
        return Icons.book_rounded;
      case 'lightbulb':
        return Icons.lightbulb_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'tips':
        return Icons.tips_and_updates_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = isSmallScreen ? 18.0 : 22.0;
    final primaryColor = _getGradientStartColor();
    final secondaryColor = _getGradientEndColor();

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashCardsPage(
              topicName: infoCard.title,
              cardCount: infoCard.cardCount,
              topicId: infoCard.topicId,
              lessonId: infoCard.lessonId,
            ),
          ),
        );
        if (result == true) {
          final mainScreen = MainScreen.of(context);
          if (mainScreen != null) {
            mainScreen.refreshHomePage();
          }
        }
      },
      child: Container(
        width: isSmallScreen ? 88 : 98,
        height: isSmallScreen ? 88 : 98,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryColor, secondaryColor],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            children: [
              // Glossy highlights
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    SizedBox(
                      height: isSmallScreen ? 22 : 26,
                      child: Text(
                        infoCard.title,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 8.5 : 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const Spacer(),

                    // Glassy Icon
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 4 : 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          _getIcon(),
                          size: isSmallScreen ? 14 : 16,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Count Description
                    Text(
                      infoCard.description,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 7.5 : 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
