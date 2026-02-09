import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_podcast.dart';
import '../../../core/services/progress_service.dart';
import '../../../../main.dart';
import 'podcasts_page.dart';

class OngoingPodcastsListPage extends StatefulWidget {
  final List<OngoingPodcast> podcasts;

  const OngoingPodcastsListPage({
    super.key,
    required this.podcasts,
  });

  @override
  State<OngoingPodcastsListPage> createState() => _OngoingPodcastsListPageState();
}

class _OngoingPodcastsListPageState extends State<OngoingPodcastsListPage> {
  final ProgressService _progressService = ProgressService();
  late List<OngoingPodcast> _podcasts;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _podcasts = List<OngoingPodcast>.from(widget.podcasts);
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_podcasts.map((p) => p.toMap()).toList());
      await prefs.setString('ongoing_podcasts_cache', jsonStr);
    } catch (_) {
      // silent
    }
  }

  Future<bool> _confirmReset(OngoingPodcast podcast) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Podcast ilerlemesi sıfırlansın mı?'),
        content: Text('"${podcast.title}" için kaldığın yer silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _resetPodcast(OngoingPodcast podcast) async {
    final confirmed = await _confirmReset(podcast);
    if (!confirmed) return;

    await _progressService.deletePodcastProgress(podcast.id);
    if (!mounted) return;

    setState(() {
      _podcasts.removeWhere((p) => p.id == podcast.id);
      _didChange = true;
    });
    await _saveToCache();

    if (!mounted) return;
    MainScreen.of(context)?.refreshHomePage();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Podcast ilerlemesi sıfırlandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.gradientPurpleStart,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(_didChange),
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
      body: _podcasts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.podcasts_outlined,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Devam eden podcast bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              itemCount: _podcasts.length,
              itemBuilder: (context, index) {
                final podcast = _podcasts[index];
                return Card(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
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
                              initialPodcastId: podcast.id,
                              initialAudioUrl: podcast.audioUrl.isNotEmpty ? podcast.audioUrl : null, // Cache'den direkt yükle
                            ),
                          ),
                        );
                        if (!context.mounted) return;
                        // If podcast page returned true, refresh home page
                        if (result == true) {
                          MainScreen.of(context)?.refreshHomePage();
                        }
                      }
                    },
                    contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    leading: Container(
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
                    title: Text(
                      podcast.title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
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
                          if (podcast.topic.isNotEmpty) const SizedBox(height: 4),
                          Text(
                            '${podcast.currentMinute} / ${podcast.totalMinutes} dakika',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sıfırla',
                          onPressed: () => _resetPodcast(podcast),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: isSmallScreen ? 20 : 22,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? Colors.white54 : Colors.grey.shade400,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

}

