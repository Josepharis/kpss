import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_test.dart';
import '../pages/tests_page.dart';

class OngoingTestCard extends StatelessWidget {
  final OngoingTest test;
  final bool isSmallScreen;
  final Future<void> Function()? onReset;

  const OngoingTestCard({
    super.key,
    required this.test,
    this.isSmallScreen = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // Compact Square Dimensions
    final double size = isSmallScreen ? 88 : 98;
    final primaryColor = AppColors.gradientBlueStart;
    final secondaryColor = AppColors.gradientBlueEnd;
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
            // Solid Gradient Background using AppColors
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

            // Modern "Glow" highlights (not mesh, just clean highlights)
            Positioned(
              top: -15,
              left: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
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
                      builder: (context) => TestsPage(
                        topicName: test.topic,
                        testCount: test.totalQuestions,
                        lessonId: test.lessonId,
                        topicId: test.topicId,
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
                          test.topic,
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

                      // Glassy Icon Container
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

                      // Progress Area
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${test.currentQuestion}/${test.totalQuestions}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7.5 : 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              if (test.score > 0)
                                Text(
                                  '${test.score}P',
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
                              widthFactor: test.progress.clamp(0.05, 1.0),
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

  IconData _getIcon() {
    final title = test.topic.toLowerCase();
    if (title.contains('matematik')) return Icons.functions_rounded;
    if (title.contains('türkçe')) return Icons.spellcheck_rounded;
    if (title.contains('tarih')) return Icons.auto_stories_rounded;
    if (title.contains('coğrafya')) return Icons.public_rounded;

    switch (test.icon) {
      case 'atom':
        return Icons.psychology_outlined;
      case 'chart':
        return Icons.insert_chart_outlined_rounded;
      case 'globe':
        return Icons.language_rounded;
      case 'megaphone':
        return Icons.notification_important_rounded;
      default:
        return Icons.assignment_outlined;
    }
  }
}
