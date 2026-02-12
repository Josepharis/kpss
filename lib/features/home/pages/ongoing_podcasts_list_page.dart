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

  const OngoingPodcastsListPage({super.key, required this.podcasts});

  @override
  State<OngoingPodcastsListPage> createState() =>
      _OngoingPodcastsListPageState();
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'İlerleme sıfırlansın mı?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${podcast.title}" için kaldığın yer silinecek.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sıfırla',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _resetPodcast(OngoingPodcast podcast) async {
    final confirmed = await _confirmReset(podcast);
    if (!confirmed) return;

    await _progressService.deletePodcastProgress(podcast.id, podcast.lessonId);
    if (!mounted) return;

    setState(() {
      _podcasts.removeWhere((p) => p.id == podcast.id);
      _didChange = true;
    });
    await _saveToCache();

    if (!mounted) return;
    MainScreen.of(context)?.refreshHomePage();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F0F1A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gradientPurpleStart,
                AppColors.gradientPurpleEnd,
              ],
            ),
          ),
        ),
        elevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(_didChange),
        ),
        title: const Text(
          'Devam Eden Podcastler',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _podcasts.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _podcasts.length,
              itemBuilder: (context, index) {
                final podcast = _podcasts[index];
                return _buildUltraCompactCard(podcast, isDark);
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.podcasts_outlined,
            size: 48,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Devam eden bulunmuyor',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltraCompactCard(OngoingPodcast podcast, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
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
                  MainScreen.of(context)?.refreshHomePage();
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  // Smaller Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gradientPurpleStart,
                          AppColors.gradientPurpleEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.podcasts_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          podcast.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              podcast.topic.isNotEmpty
                                  ? podcast.topic
                                  : 'Podcast',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.gradientPurpleStart
                                    : AppColors.primaryBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(
                              '${podcast.currentMinute}/${podcast.totalMinutes} dk',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Linear Progress
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: podcast.progress,
                            backgroundColor:
                                (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.gradientPurpleStart,
                            ),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  IconButton(
                    onPressed: () => _resetPodcast(podcast),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red.withOpacity(0.4),
                      size: 18,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
