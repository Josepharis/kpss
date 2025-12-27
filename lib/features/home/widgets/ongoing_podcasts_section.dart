import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_podcast.dart';
import 'ongoing_podcast_card.dart';
import '../pages/ongoing_podcasts_list_page.dart';

class OngoingPodcastsSection extends StatelessWidget {
  final List<OngoingPodcast> podcasts;
  final bool isSmallScreen;
  final double availableHeight;

  const OngoingPodcastsSection({
    super.key,
    required this.podcasts,
    this.isSmallScreen = false,
    this.availableHeight = 130.0,
  });

  @override
  Widget build(BuildContext context) {
    if (podcasts.isEmpty) {
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
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
                    decoration: BoxDecoration(
                      color: AppColors.gradientPurpleStart.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.podcasts_outlined,
                      size: isSmallScreen ? 16.0 : 18.0,
                      color: AppColors.gradientPurpleStart,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                  Text(
                    'Devam Eden Podcastler',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 18.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OngoingPodcastsListPage(
                        podcasts: podcasts,
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
            itemCount: podcasts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < podcasts.length - 1 ? (isSmallScreen ? 10.0 : 12.0) : 0,
                ),
                child: OngoingPodcastCard(
                  podcast: podcasts[index],
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
