import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic.dart';
import 'tests_page.dart';
import 'podcasts_page.dart';
import 'flash_cards_page.dart';
import 'notes_page.dart';
import 'past_questions_page.dart';
import 'geography_explanation_page.dart';

class TopicDetailPage extends StatelessWidget {
  final Topic topic;
  final String lessonName;

  const TopicDetailPage({
    super.key,
    required this.topic,
    required this.lessonName,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 100 : 110),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryDarkBlue,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Watermark
                Positioned(
                  top: -10,
                  right: -10,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'KPSS',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.08),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lessonName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              topic.name,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
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
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Compact Progress Card - AppBar altında
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 20 : 14,
              isSmallScreen ? 10 : 12,
              isTablet ? 20 : 14,
              0,
            ),
            child: _buildProgressCard(
              progress: topic.progress,
              isSmallScreen: isSmallScreen,
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 14),
              child: Column(
                children: [
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // 2x3 Grid for main content
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: isSmallScreen ? 10 : 12,
                    mainAxisSpacing: isSmallScreen ? 10 : 12,
                    childAspectRatio: 1.15,
                    children: [
                      // Konu Anlatımı
                      _buildPremiumCard(
                        context: context,
                        title: 'Konu Anlatımı',
                        count: 8,
                        icon: Icons.play_circle_outline_rounded,
                        color: const Color(0xFFFF9800),
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GeographyExplanationPage(
                                topicName: topic.name,
                              ),
                            ),
                          );
                        },
                      ),
                      // Çıkmış Sorular / Soru Dağılımı
                      _buildPremiumCard(
                        context: context,
                        title: 'Çıkmış Sorular',
                        subtitle: 'Soru Dağılımı',
                        count: topic.averageQuestionCount,
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFFFF6B35),
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PastQuestionsPage(
                                topicName: topic.name,
                                averageQuestionCount: topic.averageQuestionCount,
                              ),
                            ),
                          );
                        },
                      ),
                      // Testler
                      _buildPremiumCard(
                        context: context,
                        title: 'Testler',
                        count: topic.testCount,
                        icon: Icons.quiz_rounded,
                        color: AppColors.primaryBlue,
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TestsPage(
                                topicName: topic.name,
                                testCount: topic.testCount,
                                lessonId: topic.lessonId,
                              ),
                            ),
                          );
                        },
                      ),
                      // Podcastler
                      _buildPremiumCard(
                        context: context,
                        title: 'Podcastler',
                        count: topic.podcastCount,
                        icon: Icons.podcasts_rounded,
                        color: AppColors.gradientPurpleStart,
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PodcastsPage(
                                topicName: topic.name,
                                podcastCount: topic.podcastCount,
                              ),
                            ),
                          );
                        },
                      ),
                      // Ezber Kartları
                      _buildPremiumCard(
                        context: context,
                        title: 'Ezber Kartları',
                        count: topic.videoCount,
                        icon: Icons.style_rounded,
                        color: AppColors.gradientRedStart,
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashCardsPage(
                                topicName: topic.name,
                                cardCount: topic.videoCount,
                              ),
                            ),
                          );
                        },
                      ),
                      // Notlar
                      _buildPremiumCard(
                        context: context,
                        title: 'Notlar',
                        count: topic.noteCount,
                        icon: Icons.note_rounded,
                        color: AppColors.gradientGreenStart,
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotesPage(
                                topicName: topic.name,
                                noteCount: topic.noteCount,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.2,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
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
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Decorative glow
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon container
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: isSmallScreen ? 22 : 24,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    // Title and count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: isSmallScreen ? 2 : 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
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
                        ],
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Text(
                          subtitle != null && subtitle.contains('Soru') 
                              ? '$count soru'
                              : '$count içerik',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 2,
                              ),
                            ],
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

  Widget _buildProgressCard({
    required double progress,
    required bool isSmallScreen,
  }) {
    final progressPercent = (progress * 100).toStringAsFixed(0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryDarkBlue,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              size: isSmallScreen ? 18 : 20,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          // Progress info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İlerleme',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 10,
                        vertical: isSmallScreen ? 3 : 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$progressPercent%',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: isSmallScreen ? 5 : 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
