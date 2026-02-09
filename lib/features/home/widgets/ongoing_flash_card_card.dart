import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_flash_card.dart';
import '../pages/flash_cards_page.dart';

class OngoingFlashCardCard extends StatelessWidget {
  final OngoingFlashCard flashCard;
  final bool isSmallScreen;
  final Future<void> Function()? onReset;

  const OngoingFlashCardCard({
    super.key,
    required this.flashCard,
    this.isSmallScreen = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // Compact Square Dimensions
    final double size = isSmallScreen ? 88 : 98;
    // Official Green from AppColors
    final primaryColor = AppColors.gradientGreenStart;
    final secondaryColor = AppColors.gradientGreenEnd;
    final borderRadius = isSmallScreen ? 18.0 : 22.0;

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
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
            // Solid Vibrant Gradient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                ),
              ),
            ),

            // Visual element - Stack of cards icon
            Positioned(
              right: -5,
              top: 15,
              child: Opacity(
                opacity: 0.15,
                child: Icon(Icons.style_rounded, size: 72, color: Colors.white),
              ),
            ),

            // Subtle highlight
            Positioned(
              left: -10,
              top: -10,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),

            // Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FlashCardsPage(
                        topicName: flashCard.topic,
                        cardCount: flashCard.totalCards,
                        topicId: flashCard.topicId,
                        lessonId: flashCard.lessonId,
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  if (result == true) {
                    final mainScreen = MainScreen.of(context);
                    if (mainScreen != null) {
                      mainScreen.refreshHomePage();
                    }
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Topic Name
                      SizedBox(
                        height: isSmallScreen ? 22 : 26,
                        child: Text(
                          flashCard.topic,
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
                          child: const Icon(
                            Icons.filter_none_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Progress Bar
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${flashCard.currentCard}/${flashCard.totalCards} Kart',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7.5 : 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              Text(
                                '${(flashCard.progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7 : 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: 3,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: flashCard.progress.clamp(0.05, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Delete button
            if (onReset != null)
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onReset,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
