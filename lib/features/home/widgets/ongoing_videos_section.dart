import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_video.dart';
import 'ongoing_video_card.dart';
import '../pages/ongoing_videos_list_page.dart';

class OngoingVideosSection extends StatelessWidget {
  final List<OngoingVideo> videos;
  final bool isSmallScreen;
  final double availableHeight;
  final Future<void> Function(OngoingVideo video)? onReset;

  const OngoingVideosSection({
    super.key,
    required this.videos,
    this.isSmallScreen = false,
    this.availableHeight = 130.0,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cardHeight = isSmallScreen ? 105.0 : 115.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24.0 : 16.0,
            vertical: 10.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEB3349).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEB3349).withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xFFEB3349),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Devam Eden Videolar',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.0 : 15.0,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      Container(
                        width: 16,
                        height: 2.5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEB3349).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          OngoingVideosListPage(videos: videos),
                    ),
                  );
                  if (context.mounted) {
                    MainScreen.of(context)?.refreshHomePage();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB3349).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFEB3349).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Hepsi',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFEB3349),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: const Color(0xFFEB3349).withValues(alpha: 0.7),
                      ),
                    ],
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
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 24.0 : 16.0),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < videos.length - 1 ? 12.0 : 0,
                ),
                child: OngoingVideoCard(
                  video: videos[index],
                  isSmallScreen: isSmallScreen,
                  onReset: onReset != null
                      ? () => onReset!(videos[index])
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
