import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
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
import '../../../core/services/auth_service.dart';
import '../widgets/quick_access_section.dart';
import '../../../core/models/study_program.dart';
import '../../../core/services/study_program_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProgressService _progressService = ProgressService();
  final LessonsService _lessonsService = LessonsService();
  final AuthService _authService = AuthService();

  // Memory cache for instant display
  static List<OngoingTest> _cachedTests = [];
  static List<OngoingPodcast> _cachedPodcasts = [];
  static List<OngoingVideo> _cachedVideos = [];
  static List<OngoingFlashCard> _cachedFlashCards = [];
  static List<InfoCard> _cachedInfoCards = [];
  static int _cachedScore = 0;
  static String? _cachedUserId;

  List<OngoingTest> _ongoingTests = _cachedTests;
  List<OngoingPodcast> _ongoingPodcasts = _cachedPodcasts;
  List<OngoingVideo> _ongoingVideos = _cachedVideos;
  List<OngoingFlashCard> _ongoingFlashCards = _cachedFlashCards;
  List<InfoCard> _infoCards = _cachedInfoCards;
  String _userName = 'Kullanıcı';
  int _userTotalScore = _cachedScore;

  // Study Program Active Task
  bool _showCurrentTask = true;
  StudyProgramTask? _activeTask;
  int? _activeTaskWeekday;
  StreamSubscription? _programSubscription;

  @override
  void dispose() {
    _programSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Safety check: if user changed, clear memory statics
    final currentUid = _authService.getUserId();
    if (_cachedUserId != null && _cachedUserId != currentUid) {
      _clearStaticMemoryCaches();
    }
    _cachedUserId = currentUid;

    _loadOngoingContentFromCache();
    _loadUserScore();
    _loadUserData();
    Future.microtask(() {
      _loadOngoingContent();
      _loadUserScore();
      _loadUserData();
      _loadUserData();
      _loadActiveTask();
    });

    _programSubscription = StudyProgramService.instance.onProgramUpdated.listen(
      (_) {
        if (mounted) _loadActiveTask();
      },
    );
  }

  void _clearStaticMemoryCaches() {
    _cachedTests = [];
    _cachedPodcasts = [];
    _cachedVideos = [];
    _cachedFlashCards = [];
    _cachedInfoCards = [];
    _cachedScore = 0;
    _ongoingTests = [];
    _ongoingPodcasts = [];
    _ongoingVideos = [];
    _ongoingFlashCards = [];
    _infoCards = [];
    _userTotalScore = 0;
  }

  Future<void> _loadUserScore() async {
    try {
      final uid = _authService.getUserId();
      final prefs = await SharedPreferences.getInstance();
      final cachedScore = prefs.getInt('user_total_score_${uid ?? "anon"}');
      if (cachedScore != null) {
        if (mounted) setState(() => _userTotalScore = cachedScore);
      }
      final score = await _progressService.getUserTotalScore();
      if (mounted) {
        setState(() {
          _userTotalScore = score;
          _cachedScore = score;
        });
      }
      await prefs.setInt('user_total_score_${uid ?? "anon"}', score);
    } catch (e) {}
  }

  Future<void> _loadUserData() async {
    try {
      final name = await _authService.getUserName();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _userName = name);
      }
    } catch (e) {}
  }

  Future<void> _loadOngoingContentFromCache() async {
    try {
      final uid = _authService.getUserId();
      final userKey = uid ?? 'anon';
      final prefs = await SharedPreferences.getInstance();

      final testsJson = prefs.getString('ongoing_tests_cache_$userKey');
      if (testsJson != null && testsJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(testsJson);
          final items = list
              .map((j) => OngoingTest.fromMap(j as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _ongoingTests = items);
        } catch (e) {}
      }
      final podcastsJson = prefs.getString('ongoing_podcasts_cache_$userKey');
      if (podcastsJson != null && podcastsJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(podcastsJson);
          final items = list
              .map((j) => OngoingPodcast.fromMap(j as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _ongoingPodcasts = items);
        } catch (e) {}
      }
      final videosJson = prefs.getString('ongoing_videos_cache_$userKey');
      if (videosJson != null && videosJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(videosJson);
          final items = list
              .map((j) => OngoingVideo.fromMap(j as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _ongoingVideos = items);
        } catch (e) {}
      }
      final flashCardsJson = prefs.getString(
        'ongoing_flash_cards_cache_$userKey',
      );
      if (flashCardsJson != null && flashCardsJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(flashCardsJson);
          final items = list
              .map((j) => OngoingFlashCard.fromMap(j as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _ongoingFlashCards = items);
        } catch (e) {}
      }
      final infoCardsJson = prefs.getString('info_cards_cache_$userKey');
      if (infoCardsJson != null && infoCardsJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(infoCardsJson);
          final items = list
              .map((j) => InfoCard.fromMap(j as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() => _infoCards = items);
        } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> _loadOngoingContent() async {
    try {
      final results = await Future.wait([
        _progressService.getOngoingTests(),
        _progressService.getOngoingPodcasts(),
        _progressService.getOngoingVideos(),
        _progressService.getOngoingFlashCards(),
        _lessonsService.getAllTopics(),
      ]);

      final tests = results[0] as List<OngoingTest>;
      final podcasts = results[1] as List<OngoingPodcast>;
      final videos = results[2] as List<OngoingVideo>;
      final flashCards = results[3] as List<OngoingFlashCard>;
      final allTopics = results[4] as List<Topic>;

      final topicsWithFlashCards = allTopics
          .where((topic) => topic.videoCount > 0)
          .toList();
      final infoCards = topicsWithFlashCards.map((topic) {
        final colors = [
          'green',
          'orange',
          'teal',
          'purple',
          'blue',
          'yellow',
          'red',
        ];
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

      final prefs = await SharedPreferences.getInstance();
      final uid = _authService.getUserId();
      final userKey = uid ?? 'anon';

      await prefs.setString(
        'ongoing_tests_cache_$userKey',
        jsonEncode(tests.map((t) => t.toMap()).toList()),
      );
      await prefs.setString(
        'ongoing_podcasts_cache_$userKey',
        jsonEncode(podcasts.map((p) => p.toMap()).toList()),
      );
      await prefs.setString(
        'ongoing_videos_cache_$userKey',
        jsonEncode(videos.map((v) => v.toMap()).toList()),
      );
      await prefs.setString(
        'ongoing_flash_cards_cache_$userKey',
        jsonEncode(flashCards.map((f) => f.toMap()).toList()),
      );
      await prefs.setString(
        'info_cards_cache_$userKey',
        jsonEncode(infoCards.map((c) => c.toMap()).toList()),
      );

      if (mounted) {
        setState(() {
          _ongoingTests = tests;
          _ongoingPodcasts = podcasts;
          _ongoingVideos = videos;
          _ongoingFlashCards = flashCards;
          _infoCards = infoCards;
          _cachedTests = tests;
          _cachedPodcasts = podcasts;
          _cachedVideos = videos;
          _cachedFlashCards = flashCards;
          _cachedInfoCards = infoCards;
        });
      }
    } catch (e) {}
  }

  void refreshContent() {
    _loadOngoingContentFromCache();
    _loadOngoingContent();
    _loadUserScore();
    _loadActiveTask();
  }

  Future<void> _loadActiveTask() async {
    final prefs = await SharedPreferences.getInstance();
    final show = prefs.getBool('show_current_task_on_home') ?? true;

    if (!show) {
      if (mounted) {
        setState(() {
          _showCurrentTask = false;
          _activeTask = null;
        });
      }
      return;
    }

    final program = await StudyProgramService.instance.getProgram();
    if (program == null) {
      if (mounted) setState(() => _showCurrentTask = false);
      return;
    }

    final now = DateTime.now();
    final weekday = now.weekday;
    final dayData = program.days.firstWhere(
      (d) => d.weekday == weekday,
      orElse: () => StudyProgramDay(weekday: weekday, tasks: []),
    );

    StudyProgramTask? active;
    for (var t in dayData.tasks) {
      if (!t.isCompleted) {
        active = t;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _showCurrentTask = true;
        _activeTask = active;
        _activeTaskWeekday = weekday;
      });
    }
  }

  Future<void> _completeActiveTask() async {
    if (_activeTask == null || _activeTaskWeekday == null) return;

    final program = await StudyProgramService.instance.getProgram();
    if (program == null) return;

    final updatedDays = program.days.map((day) {
      if (day.weekday == _activeTaskWeekday) {
        final updatedTasks = day.tasks.map((task) {
          if (task.start == _activeTask!.start &&
              task.title == _activeTask!.title) {
            return task.copyWith(isCompleted: true);
          }
          return task;
        }).toList();
        return StudyProgramDay(weekday: day.weekday, tasks: updatedTasks);
      }
      return day;
    }).toList();

    final updatedProgram = StudyProgram(
      createdAtMillis: program.createdAtMillis,
      title: program.title,
      subtitle: program.subtitle,
      days: updatedDays,
    );

    await StudyProgramService.instance.saveProgram(updatedProgram);
    HapticFeedback.mediumImpact();
    _loadActiveTask();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Günaydın';
    if (hour >= 12 && hour < 18) return 'İyi günler';
    if (hour >= 18 && hour < 23) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            // Layer 1: Immersive Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // Layer 2: Main Content
            Column(
              children: [
                // Premium Integrated Header (AppBar-less feel)
                _buildPremiumHeader(
                  statusBarHeight,
                  isDark,
                  screenWidth,
                  isSmallScreen,
                ),

                // Content Area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final hasOngoingContent =
                          _ongoingTests.isNotEmpty ||
                          _ongoingPodcasts.isNotEmpty ||
                          _ongoingVideos.isNotEmpty ||
                          _ongoingFlashCards.isNotEmpty ||
                          _infoCards.isNotEmpty;

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12.0,
                                4.0,
                                12.0,
                                2.0,
                              ),
                              child: Column(
                                children: [
                                  DailyQuoteCard(
                                    quote: '',
                                    isSmallScreen: isSmallScreen,
                                    isCompactLayout: true,
                                  ),
                                  const SizedBox(height: 4.0),
                                  ExamCountdownCard(
                                    isSmallScreen: isSmallScreen,
                                    isCompactLayout: true,
                                  ),
                                  if (_showCurrentTask &&
                                      _activeTask != null) ...[
                                    const SizedBox(height: 4.0),
                                    _buildActiveTaskSection(
                                      isDark,
                                      isSmallScreen,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 2.0),
                          ),

                          // 2. Quick Access Section
                          SliverToBoxAdapter(
                            child: QuickAccessSection(
                              isSmallScreen: isSmallScreen,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 2.0),
                          ),

                          // 3. Ongoing Sections
                          if (_ongoingTests.isNotEmpty)
                            SliverToBoxAdapter(
                              child: OngoingTestsSection(
                                tests: _ongoingTests,
                                isSmallScreen: isSmallScreen,
                                availableHeight: isSmallScreen ? 160 : 200,
                              ),
                            ),
                          if (_ongoingTests.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 6.0),
                            ),

                          if (_ongoingPodcasts.isNotEmpty)
                            SliverToBoxAdapter(
                              child: OngoingPodcastsSection(
                                podcasts: _ongoingPodcasts,
                                isSmallScreen: isSmallScreen,
                                availableHeight: isSmallScreen ? 160 : 200,
                              ),
                            ),
                          if (_ongoingPodcasts.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 6.0),
                            ),

                          if (_ongoingVideos.isNotEmpty)
                            SliverToBoxAdapter(
                              child: OngoingVideosSection(
                                videos: _ongoingVideos,
                                isSmallScreen: isSmallScreen,
                                availableHeight: isSmallScreen ? 160 : 200,
                              ),
                            ),
                          if (_ongoingVideos.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 6.0),
                            ),

                          if (_ongoingFlashCards.isNotEmpty)
                            SliverToBoxAdapter(
                              child: OngoingFlashCardsSection(
                                flashCards: _ongoingFlashCards,
                                isSmallScreen: isSmallScreen,
                                availableHeight: isSmallScreen ? 160 : 200,
                              ),
                            ),
                          if (_ongoingFlashCards.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 6.0),
                            ),

                          if (_infoCards.isNotEmpty)
                            SliverToBoxAdapter(
                              child: InfoCardsSection(
                                infoCards: _infoCards,
                                isSmallScreen: isSmallScreen,
                                availableHeight: isSmallScreen ? 160 : 200,
                              ),
                            ),

                          // Empty State Centering
                          if (!hasOngoingContent)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(
                                isSmallScreen,
                                screenWidth > 600,
                              ),
                            ),

                          if (hasOngoingContent)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 100),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF010101) : const Color(0xFFF8FAFF),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D0221),
                    const Color(0xFF010101),
                    const Color(0xFF050505),
                  ]
                : [const Color(0xFFF0F4FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            // Ultra-Vivid Glow 1: Top Right
            Positioned(
              top: -screenWidth * 0.3,
              right: -screenWidth * 0.3,
              child: _buildBlurCircle(
                size: screenWidth * 1.5,
                color: isDark
                    ? const Color(0xFF6366F1).withOpacity(0.25)
                    : const Color(0xFF818CF8).withOpacity(0.2),
              ),
            ),

            // Ultra-Vivid Glow 2: Bottom Left
            Positioned(
              bottom: -screenWidth * 0.4,
              left: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.6,
                color: isDark
                    ? const Color(0xFFA855F7).withOpacity(0.18)
                    : const Color(0xFFC084FC).withOpacity(0.15),
              ),
            ),

            // Vivid Accent 3: Top Left (Subtle)
            Positioned(
              top: 100,
              left: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth,
                color: isDark
                    ? const Color(0xFF22D3EE).withOpacity(0.08)
                    : const Color(0xFF67E8F9).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.1, 1.0],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(
    double statusBarHeight,
    bool isDark,
    double screenWidth,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 4,
        bottom: 8,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? Colors.black : const Color(0xFF1E1E2E)).withOpacity(
              isDark ? 0.4 : 0.05,
            ),
            Colors.transparent,
          ],
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.blueAccent.shade100
                            : Colors.blueAccent.shade700,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildScorePill(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScorePill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.03)]
              : [
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.01),
                ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium Glow Icon Container
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.amber.shade300, Colors.orange.shade600],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          // Score Text Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_userTotalScore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: 0.5,
                  height: 1.1,
                ),
              ),
              Text(
                'PUAN',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: isDark
                      ? Colors.blueAccent.shade200
                      : Colors.blueAccent.shade700,
                  letterSpacing: 1.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallScreen, bool isTablet) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centering contents
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 64,
              color: AppColors.primaryBlue.withOpacity(0.2),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hadi Başlayalım!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Çalışmaya başlamak için dersler bölümünden bir konu seçebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTaskSection(bool isDark, bool isSmallScreen) {
    if (_activeTask == null) return const SizedBox.shrink();

    final grad = [
      AppColors.primaryBlue,
      AppColors.primaryBlue.withOpacity(0.7),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: grad),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: grad[0].withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SIRADAKİ GÖREV",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark
                        ? Colors.blueAccent.shade100
                        : Colors.blueAccent.shade700,
                  ),
                ),
                Text(
                  _activeTask!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (_activeTask!.lesson.isNotEmpty)
                  Text(
                    "${_activeTask!.start} - ${_activeTask!.lesson}",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isDark ? Colors.white : AppColors.textSecondary)
                          .withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _completeActiveTask,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.05,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.1,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: isDark ? Colors.greenAccent : Colors.green.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
