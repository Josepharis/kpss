import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/models/video.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/video_download_service.dart';
import '../../../core/widgets/floating_home_button.dart';
import 'video_player_page.dart';

class VideosPage extends StatefulWidget {
  final String topicName;
  final int videoCount;
  final String topicId;
  final String lessonId;

  const VideosPage({
    super.key,
    required this.topicName,
    required this.videoCount,
    required this.topicId,
    required this.lessonId,
  });

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final StorageService _storageService = StorageService();
  final LessonsService _lessonsService = LessonsService();
  final VideoDownloadService _downloadService = VideoDownloadService();
  List<Video> _videos = [];
  bool _isLoading = true;
  bool _shouldRefresh = false; // Track if video player was used
  Map<String, bool> _downloadedVideos = {}; // Track downloaded videos
  Map<String, double> _downloadProgress = {}; // Track download progress
  Map<String, bool> _downloadingVideos = {}; // Track videos being downloaded

  @override
  void initState() {
    super.initState();
    // Önce video listesini yükle, sonra download kontrolü yap
    _initializeVideos();
  }

  /// Initialize videos - optimize edilmiş yükleme
  Future<void> _initializeVideos() async {
    await _loadVideos();
    _checkDownloadedVideos();
  }

  Future<void> _checkDownloadedVideos() async {
    for (final video in _videos) {
      final isDownloaded = await _downloadService.isVideoDownloaded(
        video.videoUrl,
      );
      if (mounted) {
        setState(() {
          _downloadedVideos[video.id] = isDownloaded;
        });
      }
    }
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoading = true;
      });

      debugPrint(
        '🔍 Loading videos from Storage for topicId: ${widget.topicId}',
      );

      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        debugPrint('⚠️ Lesson not found: ${widget.lessonId}');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Lesson name'i storage path'ine çevir
      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');

      // Topic base path'i bul (önce konular/ altına bakar, yoksa direkt ders altına bakar)
      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: widget.lessonId,
        topicId: widget.topicId,
        lessonNameForPath: lessonNameForPath,
      );

      // Storage yolunu oluştur
      String storagePath = '$basePath/video';

      // Storage'dan video dosyalarını listele
      final videoUrls = await _storageService.listVideoFiles(storagePath);

      // Video listesini oluştur
      _videos = [];
      for (int index = 0; index < videoUrls.length; index++) {
        final url = videoUrls[index];

        try {
          // URL'den sadece dosya adını çıkar (path değil)
          String fileName = '';
          try {
            final uri = Uri.parse(url);
            // Query parametrelerini kaldır ve sadece path'i al
            final pathWithoutQuery = uri.path;
            // Path'ten sadece dosya adını al (son segment)
            if (pathWithoutQuery.isNotEmpty) {
              final segments = pathWithoutQuery.split('/');
              fileName = segments.lastWhere(
                (s) => s.isNotEmpty,
                orElse: () => '',
              );
            }

            // Eğer hala boşsa, pathSegments'ten dene
            if (fileName.isEmpty && uri.pathSegments.isNotEmpty) {
              fileName = uri.pathSegments.last;
            }

            // Hala boşsa, URL'den son kısmı al
            if (fileName.isEmpty) {
              final parts = url.split('/');
              fileName = parts.isNotEmpty ? parts.last : '';
              // Query parametrelerini kaldır
              if (fileName.contains('?')) {
                fileName = fileName.split('?').first;
              }
            }

            // Decode et, ama hata olursa direkt kullan
            try {
              fileName = Uri.decodeComponent(fileName);
            } catch (e) {
              // Decode edilemezse direkt kullan
              debugPrint(
                '⚠️ Could not decode filename, using as-is: $fileName',
              );
            }
          } catch (e) {
            // URI parse edilemezse, URL'den son kısmı al
            final parts = url.split('/');
            fileName = parts.isNotEmpty ? parts.last : 'Video ${index + 1}';
            // Query parametrelerini kaldır
            if (fileName.contains('?')) {
              fileName = fileName.split('?').first;
            }
            debugPrint('⚠️ Could not parse URI, extracted filename: $fileName');
          }

          // Path karakterlerini temizle (sadece dosya adı kalmalı)
          fileName = fileName.replaceAll('\\', '/').split('/').last;

          // Dosya adından başlık oluştur
          final title = fileName
              .replaceAll('.mp4', '')
              .replaceAll('.mov', '')
              .replaceAll('.avi', '')
              .replaceAll('.mkv', '')
              .replaceAll('.webm', '')
              .replaceAll('_', ' ')
              .replaceAll('%20', ' ')
              .trim();

          _videos.add(
            Video(
              id: 'video_${widget.topicId}_$index',
              title: title.isNotEmpty ? title : 'Video ${index + 1}',
              description: '${widget.topicName} video',
              videoUrl: url,
              durationMinutes:
                  0, // Duration will be loaded when video is played
              topicId: widget.topicId,
              lessonId: widget.lessonId,
              order: index,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ Error processing video $index: $e');
          // Hata olsa bile video ekle (URL ile)
          _videos.add(
            Video(
              id: 'video_${widget.topicId}_$index',
              title: 'Video ${index + 1}',
              description: '${widget.topicName} video',
              videoUrl: url,
              durationMinutes: 0,
              topicId: widget.topicId,
              lessonId: widget.lessonId,
              order: index,
            ),
          );
        }
      }

      debugPrint('✅ Found ${_videos.length} videos from Storage');

      setState(() {
        _isLoading = false;
      });

      // Check downloaded status for all videos
      _checkDownloadedVideos();
    } catch (e) {
      debugPrint('❌ Error loading videos: $e');

      setState(() {
        _isLoading = false;
        _videos = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.backgroundLight,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const FloatingHomeButton(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 100 : 110),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
                  ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color(0xFFE74C3C).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop(_shouldRefresh); // Return refresh status
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.topicName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Videolar',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz video eklenmemiş',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
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
                return _buildVideoCard(video, isSmallScreen);
              },
            ),
    );
  }

  Widget _buildVideoCard(Video video, bool isSmallScreen) {
    final isDownloaded = _downloadedVideos[video.id] ?? false;
    final isDownloading = _downloadingVideos[video.id] ?? false;
    final downloadProgress = _downloadProgress[video.id] ?? 0.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  VideoPlayerPage(video: video, topicName: widget.topicName),
            ),
          );
          // If video player returned true, mark for refresh
          if (result == true) {
            setState(() {
              _shouldRefresh = true;
            });
            // Recheck downloaded status
            _checkDownloadedVideos();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              // Video thumbnail/icon
              Container(
                width: isSmallScreen ? 80 : 100,
                height: isSmallScreen ? 60 : 75,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: isSmallScreen ? 32 : 40,
                    ),
                    if (isDownloaded)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            video.description,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDownloaded)
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download_done,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'İndirildi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (isDownloading)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: downloadProgress,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFFE74C3C),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'İndiriliyor: ${(downloadProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Delete button (only show if downloaded)
              if (isDownloaded)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleDelete(video),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              if (isDownloaded) SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDelete(Video video) async {
    // Delete video
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Videoyu Sil'),
        content: Text(
          '${video.title} videosunu silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final deleted = await _downloadService.deleteVideo(video.videoUrl);
      if (deleted && mounted) {
        setState(() {
          _downloadedVideos[video.id] = false;
        });
        PremiumSnackBar.show(
          context,
          message: 'Video başarıyla silindi.',
          type: SnackBarType.success,
        );
      }
    }
  }
}
