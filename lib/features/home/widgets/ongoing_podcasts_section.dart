import 'package:flutter/material.dart';
import '../../../../main.dart';
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
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFF6C5CE7),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Devam Eden Podcastler',
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
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.6),
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
                          OngoingPodcastsListPage(podcasts: podcasts),
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
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Hepsi',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF6C5CE7),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.7),
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
