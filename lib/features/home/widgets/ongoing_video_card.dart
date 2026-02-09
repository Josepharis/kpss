import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_video.dart';
import '../../../core/models/video.dart';
import '../pages/video_player_page.dart';
import '../pages/videos_page.dart';

class OngoingVideoCard extends StatelessWidget {
  final OngoingVideo video;
  final bool isSmallScreen;
  final Future<void> Function()? onReset;

  const OngoingVideoCard({
    super.key,
    required this.video,
    this.isSmallScreen = false,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    // Compact Square Dimensions
    final double size = isSmallScreen ? 88 : 98;

    // Proper Red (Not Pink)
    const primaryColor = Color(0xFFF44336);
    const secondaryColor = Color(0xFFD32F2F);

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
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Solid Vibrant RED Gradient Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                ),
              ),
            ),

            // Visual element - Play icon overlay
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 72,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),

            // Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  if (video.videoUrl.isNotEmpty && video.videoUrl != '') {
                    final videoObj = Video(
                      id: video.id,
                      title: video.title,
                      description: video.topic,
                      videoUrl: video.videoUrl,
                      durationMinutes: video.totalMinutes,
                      topicId: video.topicId,
                      lessonId: video.lessonId,
                      order: 0,
                    );
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerPage(
                          video: videoObj,
                          topicName: video.topic,
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
                  } else if (video.topicId.isNotEmpty &&
                      video.lessonId.isNotEmpty) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideosPage(
                          topicName: video.topic,
                          videoCount: 1,
                          topicId: video.topicId,
                          lessonId: video.lessonId,
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
                      // Video Topic
                      SizedBox(
                        height: isSmallScreen ? 22 : 26,
                        child: Text(
                          video.topic,
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

                      // Progress Bar
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${video.currentMinute}/${video.totalMinutes} dk',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7.5 : 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              Text(
                                '${(video.progress * 100).toInt()}%',
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
                              widthFactor: video.progress.clamp(0.05, 1.0),
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
    final title = video.topic.toLowerCase();
    if (title.contains('matematik')) return Icons.play_lesson_rounded;
    if (title.contains('türkçe')) return Icons.video_library_rounded;
    if (title.contains('tarih')) return Icons.history_edu_rounded;
    if (title.contains('coğrafya')) return Icons.explore_rounded;
    return Icons.play_circle_fill_rounded;
  }
}
