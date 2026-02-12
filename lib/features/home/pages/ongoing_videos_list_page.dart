import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_video.dart';
import '../../../core/models/video.dart';
import '../../../core/services/progress_service.dart';
import '../../../../main.dart';
import 'video_player_page.dart';

class OngoingVideosListPage extends StatefulWidget {
  final List<OngoingVideo> videos;

  const OngoingVideosListPage({super.key, required this.videos});

  @override
  State<OngoingVideosListPage> createState() => _OngoingVideosListPageState();
}

class _OngoingVideosListPageState extends State<OngoingVideosListPage> {
  final ProgressService _progressService = ProgressService();
  late List<OngoingVideo> _videos;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _videos = List<OngoingVideo>.from(widget.videos);
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_videos.map((v) => v.toMap()).toList());
      await prefs.setString('ongoing_videos_cache', jsonStr);
    } catch (_) {
      // silent
    }
  }

  Future<bool> _confirmReset(OngoingVideo video) async {
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
          '"${video.title}" için kaldığın yer silinecek.',
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

  Future<void> _resetVideo(OngoingVideo video) async {
    final confirmed = await _confirmReset(video);
    if (!confirmed) return;

    await _progressService.deleteVideoProgress(video.id, video.lessonId);
    if (!mounted) return;

    setState(() {
      _videos.removeWhere((v) => v.id == video.id);
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
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
          'Devam Eden Videolar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _videos.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                return _buildUltraCompactCard(video, isDark);
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
            Icons.video_library_outlined,
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

  Widget _buildUltraCompactCard(OngoingVideo video, bool isDark) {
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
              final videoObj = Video(
                id: video.id,
                title: video.title,
                description: '',
                videoUrl: video.videoUrl,
                durationMinutes: video.totalMinutes,
                topicId: video.topicId,
                lessonId: video.lessonId,
                order: 0,
              );
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VideoPlayerPage(video: videoObj, topicName: video.topic),
                ),
              );
              if (!context.mounted) return;
              if (result == true) {
                MainScreen.of(context)?.refreshHomePage();
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
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
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
                              video.topic.isNotEmpty ? video.topic : 'Video',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE74C3C).withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Text(
                              '${video.currentMinute}/${video.totalMinutes} dk',
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
                            value: video.currentMinute / video.totalMinutes,
                            backgroundColor:
                                (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.05),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE74C3C),
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
                    onPressed: () => _resetVideo(video),
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
