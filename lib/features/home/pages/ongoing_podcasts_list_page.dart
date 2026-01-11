import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_podcast.dart';
import '../../../../main.dart';
import 'podcasts_page.dart';

class OngoingPodcastsListPage extends StatelessWidget {
  final List<OngoingPodcast> podcasts;

  const OngoingPodcastsListPage({
    super.key,
    required this.podcasts,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.gradientPurpleStart,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Devam Eden Podcastler',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: podcasts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.podcasts_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Devam eden podcast bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              itemCount: podcasts.length,
              itemBuilder: (context, index) {
                final podcast = podcasts[index];
                return Card(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () async {
                      if (podcast.topicId != null && podcast.lessonId != null) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PodcastsPage(
                              topicName: podcast.topic.isNotEmpty ? podcast.topic : podcast.title,
                              podcastCount: 1, // Will be loaded in PodcastsPage
                              topicId: podcast.topicId!,
                              lessonId: podcast.lessonId!,
                              initialAudioUrl: podcast.audioUrl.isNotEmpty ? podcast.audioUrl : null, // Cache'den direkt yükle
                            ),
                          ),
                        );
                        // If podcast page returned true, refresh home page
                        if (result == true) {
                          final mainScreen = MainScreen.of(context);
                          if (mainScreen != null) {
                            mainScreen.refreshHomePage();
                          }
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      child: Row(
                        children: [
                          Container(
                            width: isSmallScreen ? 50 : 60,
                            height: isSmallScreen ? 50 : 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.gradientPurpleStart,
                                  AppColors.gradientPurpleEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.podcasts_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 24 : 28,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12 : 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (podcast.topic.isNotEmpty)
                                  Text(
                                    podcast.topic,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryBlue,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (podcast.topic.isNotEmpty)
                                  const SizedBox(height: 4),
                                Text(
                                  podcast.title,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${podcast.currentMinute} / ${podcast.totalMinutes} dakika',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                            size: isSmallScreen ? 20 : 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

}

