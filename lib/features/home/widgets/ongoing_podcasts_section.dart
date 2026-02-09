import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_podcast.dart';
import 'ongoing_podcast_card.dart';
import '../pages/ongoing_podcasts_list_page.dart';

class OngoingPodcastsSection extends StatelessWidget {
  final List<OngoingPodcast> podcasts;
  final bool isSmallScreen;
  final double availableHeight;
  final Future<void> Function(OngoingPodcast podcast)? onReset;

  const OngoingPodcastsSection({
    super.key,
    required this.podcasts,
    this.isSmallScreen = false,
    this.availableHeight = 130.0,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (podcasts.isEmpty) return const SizedBox.shrink();

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
            vertical: 8.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Devam Eden Podcastler',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16.0 : 18.0,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        OngoingPodcastsListPage(podcasts: podcasts),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(
                    0xFF6C5CE7,
                  ).withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Hepsi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C5CE7),
                    fontWeight: FontWeight.bold,
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
            itemCount: podcasts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < podcasts.length - 1 ? 12.0 : 0,
                ),
                child: OngoingPodcastCard(
                  podcast: podcasts[index],
                  isSmallScreen: isSmallScreen,
                  onReset: onReset != null
                      ? () => onReset!(podcasts[index])
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
