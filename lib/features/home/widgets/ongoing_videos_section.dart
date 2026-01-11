import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_video.dart';
import 'ongoing_video_card.dart';
import '../pages/ongoing_videos_list_page.dart';

class OngoingVideosSection extends StatelessWidget {
  final List<OngoingVideo> videos;
  final bool isSmallScreen;
  final double availableHeight;

  const OngoingVideosSection({
    super.key,
    required this.videos,
    this.isSmallScreen = false,
    this.availableHeight = 130.0,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
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
                      builder: (context) => OngoingVideosListPage(
                        videos: videos,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.video_library_outlined,
                        size: isSmallScreen ? 16.0 : 18.0,
                        color: const Color(0xFFE74C3C),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    Text(
                      'Devam Eden Videolar',
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
                      builder: (context) => OngoingVideosListPage(
                        videos: videos,
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
            itemCount: videos.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < videos.length - 1 ? (isSmallScreen ? 10.0 : 12.0) : 0,
                ),
                child: OngoingVideoCard(
                  video: videos[index],
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

