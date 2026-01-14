import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_test.dart';
import '../../../core/models/ongoing_podcast.dart';
import '../../../core/models/ongoing_video.dart';
import '../../../core/models/ongoing_flash_card.dart';
import '../../../core/models/info_card.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/lessons_service.dart';
import '../widgets/ongoing_tests_section.dart';
import '../widgets/ongoing_podcasts_section.dart';
import '../widgets/ongoing_videos_section.dart';
import '../widgets/ongoing_flash_cards_section.dart';
import '../widgets/info_cards_section.dart';
import '../widgets/daily_quote_card.dart';
import '../widgets/exam_countdown_card.dart';
import '../../../../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProgressService _progressService = ProgressService();
  final LessonsService _lessonsService = LessonsService();
  List<OngoingTest> _ongoingTests = [];
  List<OngoingPodcast> _ongoingPodcasts = [];
  List<OngoingVideo> _ongoingVideos = [];
  List<OngoingFlashCard> _ongoingFlashCards = [];
  List<InfoCard> _infoCards = [];
  int _userTotalScore = 0;

  @override
  void initState() {
    super.initState();
    // Önce cache'den hızlıca yükle (sayfa açılışını engellemez)
    _loadOngoingContentFromCache();
    _loadUserScore();
    // Arka planda Firestore'dan güncelle (non-blocking)
    Future.microtask(() {
      _loadOngoingContent();
      _loadUserScore();
    });
  }

  /// Load user total score from cache and Firestore
  Future<void> _loadUserScore() async {
    try {
      // Önce cache'den yükle
      final prefs = await SharedPreferences.getInstance();
      final cachedScore = prefs.getInt('user_total_score');
      if (cachedScore != null) {
        if (mounted) {
          setState(() {
            _userTotalScore = cachedScore;
          });
        }
      }
      
      // Firestore'dan güncelle
      final score = await _progressService.getUserTotalScore();
      if (mounted) {
        setState(() {
          _userTotalScore = score;
        });
      }
      
      // Cache'e kaydet
      await prefs.setInt('user_total_score', score);
    } catch (e) {
      // Silent error handling
    }
  }

  /// Cache'den devam eden içerikleri hemen yükle (synchronous - çok hızlı)
  Future<void> _loadOngoingContentFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Testler
      final testsJson = prefs.getString('ongoing_tests_cache');
      if (testsJson != null && testsJson.isNotEmpty) {
        try {
          final List<dynamic> testsList = jsonDecode(testsJson);
          final tests = testsList.map((json) => OngoingTest.fromMap(json as Map<String, dynamic>)).toList();
          if (mounted) {
            setState(() {
              _ongoingTests = tests;
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Podcastler
      final podcastsJson = prefs.getString('ongoing_podcasts_cache');
      if (podcastsJson != null && podcastsJson.isNotEmpty) {
        try {
          final List<dynamic> podcastsList = jsonDecode(podcastsJson);
          final podcasts = podcastsList.map((json) => OngoingPodcast.fromMap(json as Map<String, dynamic>)).toList();
          if (mounted) {
            setState(() {
              _ongoingPodcasts = podcasts;
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Videolar
      final videosJson = prefs.getString('ongoing_videos_cache');
      if (videosJson != null && videosJson.isNotEmpty) {
        try {
          final List<dynamic> videosList = jsonDecode(videosJson);
          final videos = videosList.map((json) => OngoingVideo.fromMap(json as Map<String, dynamic>)).toList();
          if (mounted) {
            setState(() {
              _ongoingVideos = videos;
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Flash Cards (devam eden bilgi kartları)
      final flashCardsJson = prefs.getString('ongoing_flash_cards_cache');
      if (flashCardsJson != null && flashCardsJson.isNotEmpty) {
        try {
          final List<dynamic> flashCardsList = jsonDecode(flashCardsJson);
          final flashCards = flashCardsList.map((json) => OngoingFlashCard.fromMap(json as Map<String, dynamic>)).toList();
          if (mounted) {
            setState(() {
              _ongoingFlashCards = flashCards;
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Info Cards (flash cards) - cache'den yükle
      final infoCardsJson = prefs.getString('info_cards_cache');
      if (infoCardsJson != null && infoCardsJson.isNotEmpty) {
        try {
          final List<dynamic> infoCardsList = jsonDecode(infoCardsJson);
          final infoCards = infoCardsList.map((json) => InfoCard.fromMap(json as Map<String, dynamic>)).toList();
          if (mounted) {
            setState(() {
              _infoCards = infoCards;
            });
          }
        } catch (e) {
          // Silent error handling
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _loadOngoingContent() async {
    try {
      // Paralel yükleme - tüm devam eden içerikleri aynı anda çek
      final results = await Future.wait([
        _progressService.getOngoingTests(),
        _progressService.getOngoingPodcasts(),
        _progressService.getOngoingVideos(),
        _progressService.getOngoingFlashCards(),
        _lessonsService.getAllTopics(), // InfoCards için
      ]);
      
      final tests = results[0] as List<OngoingTest>;
      final podcasts = results[1] as List<OngoingPodcast>;
      final videos = results[2] as List<OngoingVideo>;
      final flashCards = results[3] as List<OngoingFlashCard>;
      final allTopics = results[4] as List<Topic>;
      
      // Load topics with flash cards (videoCount > 0 means flash cards exist)
      final topicsWithFlashCards = allTopics
          .where((topic) => topic.videoCount > 0)
          .toList();
      
      // Convert topics to InfoCards
      final infoCards = topicsWithFlashCards.map((topic) {
        // Generate color based on topic name hash
        final colors = ['green', 'orange', 'teal', 'purple', 'blue', 'yellow', 'red'];
        final colorIndex = topic.name.hashCode.abs() % colors.length;
        
        return InfoCard(
          id: topic.id,
          title: topic.name,
          description: '${topic.videoCount} kart',
          icon: 'book',
          color: colors[colorIndex],
          topicId: topic.id,
          lessonId: topic.lessonId,
          cardCount: topic.videoCount,
        );
      }).toList();

      // Cache'e kaydet
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Testler
        final testsJson = jsonEncode(tests.map((t) => t.toMap()).toList());
        await prefs.setString('ongoing_tests_cache', testsJson);
        
        // Podcastler
        final podcastsJson = jsonEncode(podcasts.map((p) => p.toMap()).toList());
        await prefs.setString('ongoing_podcasts_cache', podcastsJson);
        
        // Videolar
        final videosJson = jsonEncode(videos.map((v) => v.toMap()).toList());
        await prefs.setString('ongoing_videos_cache', videosJson);
        
        // Flash Cards
        final flashCardsJson = jsonEncode(flashCards.map((f) => f.toMap()).toList());
        await prefs.setString('ongoing_flash_cards_cache', flashCardsJson);
        
        // Info Cards
        final infoCardsJson = jsonEncode(infoCards.map((c) => c.toMap()).toList());
        await prefs.setString('info_cards_cache', infoCardsJson);
        
      } catch (e) {
        // Silent error handling
      }

      if (mounted) {
        setState(() {
          _ongoingTests = tests;
          _ongoingPodcasts = podcasts;
          _ongoingVideos = videos;
          _ongoingFlashCards = flashCards;
          _infoCards = infoCards;
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Public method to refresh content from outside
  void refreshContent() {
    _loadOngoingContent();
    _loadUserScore(); // Puanı da güncelle
  }

  Widget _buildEmptyState(bool isSmallScreen, bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 24.0 : 32.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.1),
            AppColors.primaryDarkBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İkon
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              size: isSmallScreen ? 48.0 : 64.0,
              color: AppColors.primaryBlue,
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 24.0),
          // Başlık
          Text(
            'Hoş Geldiniz!',
            style: TextStyle(
              fontSize: isSmallScreen ? 22.0 : 28.0,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
          // Açıklama
          Text(
            'Çalışmaya başlamak için dersler bölümünden\nbir konu seçebilirsiniz.',
            style: TextStyle(
              fontSize: isSmallScreen ? 14.0 : 16.0,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isSmallScreen ? 24.0 : 32.0),
          // Hızlı Erişim Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickActionButton(
                icon: Icons.library_books_rounded,
                label: 'Dersler',
                color: AppColors.primaryBlue,
                isSmallScreen: isSmallScreen,
                onTap: () {
                  // Dersler sayfasına git
                  final mainScreen = MainScreen.of(context);
                  if (mainScreen != null) {
                    mainScreen.navigateToTab(1);
                  }
                },
              ),
              SizedBox(width: isSmallScreen ? 12.0 : 16.0),
              _buildQuickActionButton(
                icon: Icons.school_rounded,
                label: 'Çalışma',
                color: AppColors.gradientGreenStart,
                isSmallScreen: isSmallScreen,
                onTap: () {
                  // Çalışma sayfasına git
                  final mainScreen = MainScreen.of(context);
                  if (mainScreen != null) {
                    mainScreen.navigateToTab(3);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 20.0 : 24.0,
          vertical: isSmallScreen ? 12.0 : 16.0,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isSmallScreen ? 20.0 : 24.0,
            ),
            SizedBox(width: isSmallScreen ? 8.0 : 10.0),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Günaydın';
    } else if (hour < 18) {
      return 'İyi günler';
    } else {
      return 'İyi akşamlar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    
    // Responsive font sizes
    final greetingFontSize = isSmallScreen ? 12.0 : 14.0;
    final titleFontSize = isSmallScreen ? 16.0 : 20.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? const Color(0xFF1E1E1E) : AppColors.primaryBlue;
    final headerDarkColor = isDark ? const Color(0xFF121212) : AppColors.primaryDarkBlue;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          children: [
            // Custom AppBar with Status Bar
            Container(
              padding: EdgeInsets.only(
                top: statusBarHeight,
                bottom: isSmallScreen ? 8.0 : 12.0,
                left: isTablet ? 24.0 : 16.0,
                right: isTablet ? 24.0 : 16.0,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    headerColor,
                    headerDarkColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: greetingFontSize,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'KPSS & AGS 2026',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Puan göster
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 10.0 : 12.0,
                      vertical: isSmallScreen ? 6.0 : 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: isSmallScreen ? 16 : 18,
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 6),
                        Text(
                          '$_userTotalScore',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content - Fits in single screen
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hasOngoingContent = _ongoingTests.isNotEmpty || 
                                           _ongoingPodcasts.isNotEmpty || 
                                           _ongoingVideos.isNotEmpty || 
                                           _ongoingFlashCards.isNotEmpty ||
                                           _infoCards.isNotEmpty;
                  
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Daily Quote Card
                            DailyQuoteCard(
                              quote: '',
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Exam Countdown Card
                            ExamCountdownCard(
                              examDate: DateTime(2026, 7, 1), // KPSS & AGS 2026 sınav tarihi
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Ongoing Tests Section
                            if (_ongoingTests.isNotEmpty)
                            OngoingTestsSection(
                                  tests: _ongoingTests,
                                isSmallScreen: isSmallScreen,
                                availableHeight: constraints.maxHeight * 0.35,
                            ),
                            if (_ongoingTests.isNotEmpty)
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Ongoing Podcasts Section
                            if (_ongoingPodcasts.isNotEmpty)
                            OngoingPodcastsSection(
                                  podcasts: _ongoingPodcasts,
                                isSmallScreen: isSmallScreen,
                                availableHeight: constraints.maxHeight * 0.35,
                              ),
                            if (_ongoingPodcasts.isNotEmpty)
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Ongoing Videos Section
                            if (_ongoingVideos.isNotEmpty)
                            OngoingVideosSection(
                                videos: _ongoingVideos,
                              isSmallScreen: isSmallScreen,
                              availableHeight: constraints.maxHeight * 0.35,
                            ),
                            if (_ongoingVideos.isNotEmpty)
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Ongoing Flash Cards Section
                            if (_ongoingFlashCards.isNotEmpty)
                            OngoingFlashCardsSection(
                                  flashCards: _ongoingFlashCards,
                                isSmallScreen: isSmallScreen,
                                availableHeight: constraints.maxHeight * 0.35,
                            ),
                            if (_ongoingFlashCards.isNotEmpty)
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Info Cards Section (Flash Cards)
                            if (_infoCards.isNotEmpty) ...[
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            InfoCardsSection(
                                infoCards: _infoCards,
                              isSmallScreen: isSmallScreen,
                              availableHeight: constraints.maxHeight * 0.35,
                            ),
                            ],
                            // Boş durum - devam eden içerik yoksa
                            if (!hasOngoingContent) ...[
                              SizedBox(height: isSmallScreen ? 20.0 : 32.0),
                              _buildEmptyState(isSmallScreen, isTablet),
                            ],
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
