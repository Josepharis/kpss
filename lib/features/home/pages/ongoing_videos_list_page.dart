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

  const OngoingVideosListPage({
    super.key,
    required this.videos,
  });

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
        title: const Text('Video ilerlemesi sıfırlansın mı?'),
        content: Text('"${video.title}" için kaldığın yer silinecek.'),
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

  Future<void> _resetVideo(OngoingVideo video) async {
    final confirmed = await _confirmReset(video);
    if (!confirmed) return;

    await _progressService.deleteVideoProgress(video.id);
    if (!mounted) return;

    setState(() {
      _videos.removeWhere((v) => v.id == video.id);
      _didChange = true;
    });
    await _saveToCache();

    if (!mounted) return;
    MainScreen.of(context)?.refreshHomePage();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video ilerlemesi sıfırlandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE74C3C),
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
          'Devam Eden Videolar',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _videos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Devam eden video bulunmuyor',
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
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                return Card(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: () async {
                      // Create Video object from OngoingVideo
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
                          builder: (context) => VideoPlayerPage(
                            video: videoObj,
                            topicName: video.topic,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      // If video page returned true, refresh home page
                      if (result == true) {
                        MainScreen.of(context)?.refreshHomePage();
                      }
                    },
                    contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    leading: Container(
                      width: isSmallScreen ? 50 : 60,
                      height: isSmallScreen ? 50 : 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE74C3C),
                            Color(0xFFC0392B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    title: Text(
                      video.title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${video.currentMinute} / ${video.totalMinutes} dakika',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sıfırla',
                          onPressed: () => _resetVideo(video),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: isSmallScreen ? 20 : 22,
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
                );
              },
            ),
    );
  }

}

