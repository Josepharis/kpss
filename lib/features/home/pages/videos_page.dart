import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/video.dart';
import '../../../core/services/storage_service.dart';
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
  List<Video> _videos = [];
  bool _isLoading = true;
  bool _shouldRefresh = false; // Track if video player was used

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      print('🔍 Loading videos from Storage for topicId: ${widget.topicId}');
      
      // Storage yolunu oluştur: video/{lessonName}
      final lessonName = widget.lessonId.replaceAll('_lesson', '').replaceAll('_', '');
      final storagePath = 'video/$lessonName';
      
      print('📂 Storage path: $storagePath');
      
      // Storage'dan video dosyalarını listele
      final videoUrls = await _storageService.listVideoFiles(storagePath);
      
      // Video listesini oluştur
      _videos = [];
      for (int index = 0; index < videoUrls.length; index++) {
        final url = videoUrls[index];
        
        try {
          final uri = Uri.parse(url);
          var fileName = uri.pathSegments.last;
          fileName = Uri.decodeComponent(fileName);
          
          // Dosya adından başlık oluştur
          final title = fileName
              .replaceAll('.mp4', '')
              .replaceAll('.mov', '')
              .replaceAll('.avi', '')
              .replaceAll('.mkv', '')
              .replaceAll('.webm', '')
              .replaceAll('_', ' ')
              .trim();
          
          _videos.add(Video(
            id: 'video_${widget.topicId}_$index',
            title: title,
            description: '${widget.topicName} video',
            videoUrl: url,
            durationMinutes: 0, // Duration will be loaded when video is played
            topicId: widget.topicId,
            lessonId: widget.lessonId,
            order: index,
          ));
        } catch (e) {
          print('⚠️ Error processing video $index: $e');
        }
      }
      
      // Mock video ekle (test için)
      if (_videos.isEmpty) {
        _videos.add(Video(
          id: 'mock_video_1',
          title: 'Örnek Video - KPSS Hazırlık',
          description: 'Bu bir test videosudur. Video oynatıcıyı test etmek için kullanılabilir.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          durationMinutes: 10,
          topicId: widget.topicId,
          lessonId: widget.lessonId,
          order: 0,
        ));
        print('📹 Mock video added for testing');
      }
      
      print('✅ Found ${_videos.length} videos from Storage');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading videos: $e');
      
      // Hata durumunda da mock video ekle
      _videos = [
        Video(
          id: 'mock_video_1',
          title: 'Örnek Video - KPSS Hazırlık',
          description: 'Bu bir test videosudur. Video oynatıcıyı test etmek için kullanılabilir.',
          videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          durationMinutes: 10,
          topicId: widget.topicId,
          lessonId: widget.lessonId,
          order: 0,
        ),
      ];
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 100 : 110),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFE74C3C),
                const Color(0xFFC0392B),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
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
                            Navigator.of(context).pop(_shouldRefresh); // Return refresh status
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
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _videos.isEmpty
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
                        'Henüz video eklenmemiş',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
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
    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerPage(
                video: video,
                topicName: widget.topicName,
              ),
            ),
          );
          // If video player returned true, mark for refresh
          if (result == true) {
            setState(() {
              _shouldRefresh = true;
            });
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
                    colors: [
                      const Color(0xFFE74C3C),
                      const Color(0xFFC0392B),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.play_circle_filled,
                  color: Colors.white,
                  size: isSmallScreen ? 32 : 40,
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
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      video.description,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
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
}

