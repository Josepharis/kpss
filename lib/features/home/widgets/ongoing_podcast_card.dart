import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_podcast.dart';
import '../pages/podcasts_page.dart';

class OngoingPodcastCard extends StatelessWidget {
  final OngoingPodcast podcast;
  final bool isSmallScreen;
  final Future<void> Function()? onReset;

  const OngoingPodcastCard({
    super.key,
    required this.podcast,
    this.isSmallScreen = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // Compact Square Dimensions
    final double size = isSmallScreen ? 88 : 98;
    // Official Purple from AppColors
    final primaryColor = AppColors.gradientPurpleStart;
    final secondaryColor = AppColors.gradientPurpleEnd;
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
                    stops: const [0.2, 1.0],
                  ),
                ),
              ),
            ),

            // Vibrant visual element - Floating Music Note
            Positioned(
              right: -5,
              bottom: -5,
              child: Icon(
                Icons.music_note_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),

            // Highlighting glow
            Positioned(
              top: -20,
              right: -10,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),

            // Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (podcast.topicId != null && podcast.lessonId != null) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PodcastsPage(
                          topicName: podcast.topic.isNotEmpty
                              ? podcast.topic
                              : podcast.title,
                          podcastCount: 1,
                          topicId: podcast.topicId!,
                          lessonId: podcast.lessonId!,
                          initialPodcastId: podcast.id,
                          initialAudioUrl: podcast.audioUrl.isNotEmpty
                              ? podcast.audioUrl
                              : null,
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
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Podcast Topic
                      SizedBox(
                        height: isSmallScreen ? 22 : 26,
                        child: Text(
                          podcast.topic.isNotEmpty
                              ? podcast.topic
                              : podcast.title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 8 : 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            height: 1.05,
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

                      // Progress Bar
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${podcast.currentMinute}/${podcast.totalMinutes} dk',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7.5 : 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              Text(
                                '${(podcast.progress * 100).toInt()}%',
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
                              widthFactor: podcast.progress.clamp(0.05, 1.0),
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
    return Icons.mic_rounded;
  }
}
