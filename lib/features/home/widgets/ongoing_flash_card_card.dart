import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_flash_card.dart';
import '../pages/flash_cards_page.dart';

class OngoingFlashCardCard extends StatelessWidget {
  final OngoingFlashCard flashCard;
  final bool isSmallScreen;

  const OngoingFlashCardCard({
    super.key,
    required this.flashCard,
    this.isSmallScreen = false,
  });

  Color _getGradientStartColor() {
    switch (flashCard.progressColor) {
      case 'green':
        return AppColors.gradientGreenStart;
      case 'orange':
        return AppColors.gradientOrangeStart;
      case 'teal':
        return AppColors.gradientTealStart;
      case 'purple':
        return AppColors.gradientPurpleStart;
      case 'blue':
        return AppColors.gradientBlueStart;
      case 'yellow':
        return AppColors.gradientYellowStart;
      case 'red':
        return AppColors.gradientRedStart;
      default:
        return AppColors.gradientGreenStart;
    }
  }

  Color _getGradientEndColor() {
    switch (flashCard.progressColor) {
      case 'green':
        return AppColors.gradientGreenEnd;
      case 'orange':
        return AppColors.gradientOrangeEnd;
      case 'teal':
        return AppColors.gradientTealEnd;
      case 'purple':
        return AppColors.gradientPurpleEnd;
      case 'blue':
        return AppColors.gradientBlueEnd;
      case 'yellow':
        return AppColors.gradientYellowEnd;
      case 'red':
        return AppColors.gradientRedEnd;
      default:
        return AppColors.gradientGreenEnd;
    }
  }

  IconData _getIcon() {
    return Icons.book_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = isSmallScreen ? 16.0 : 18.0;
    
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlashCardsPage(
              topicName: flashCard.topic,
              lessonId: flashCard.lessonId,
              topicId: flashCard.topicId,
              cardCount: flashCard.totalCards,
            ),
          ),
        );
        // If flash cards page returned true, refresh home page
        if (result == true) {
          // Find MainScreen and refresh home page
          final mainScreen = MainScreen.of(context);
          if (mainScreen != null) {
            mainScreen.refreshHomePage();
          }
        }
      },
      child: Container(
        width: isSmallScreen ? 85 : 95,
        height: isSmallScreen ? 85 : 95,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getGradientStartColor(),
              _getGradientEndColor(),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: _getGradientStartColor().withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: _getGradientStartColor().withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Multi-layer gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.6,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Pattern overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.04),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Decorative glow
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  width: isSmallScreen ? 40 : 50,
                  height: isSmallScreen ? 40 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -12,
                left: -12,
                child: Container(
                  width: isSmallScreen ? 50 : 60,
                  height: isSmallScreen ? 50 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top section - Konu (topic)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Topic name
                        Text(
                          flashCard.topic,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 9 : 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.2,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    
                    // Center - Icon with more space
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.38),
                                Colors.white.withValues(alpha: 0.18),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 3,
                                offset: const Offset(-1, -1),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getIcon(),
                            size: isSmallScreen ? 14 : 16,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom - Progress section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${flashCard.currentCard}/${flashCard.totalCards}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 8 : 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 4 : 5,
                                vertical: isSmallScreen ? 1 : 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${(flashCard.progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7 : 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 5),
                        // Progress bar
                        Container(
                          height: isSmallScreen ? 4 : 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: flashCard.progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.22),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: isSmallScreen ? 4 : 5,
                            ),
                          ),
                        ),
                      ],
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
