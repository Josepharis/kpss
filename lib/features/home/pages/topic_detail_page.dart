import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ai_material.dart';
import '../../../core/models/ai_question.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/ai_content_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/quick_access_service.dart';
import '../../../core/widgets/floating_home_button.dart';
import 'ai_material_page.dart';
import 'ai_questions_page.dart';
import 'tests_page.dart';
import 'podcasts_page.dart';
import 'flash_cards_page.dart';
import 'notes_page.dart';
import 'past_questions_page.dart';
import 'videos_page.dart';
import 'tests_list_page.dart';
import 'pdfs_page.dart';
import 'subscription_page.dart';

class TopicDetailPage extends StatefulWidget {
  final Topic topic;
  final String lessonName;

  const TopicDetailPage({
    super.key,
    required this.topic,
    required this.lessonName,
  });

  @override
  State<TopicDetailPage> createState() => _TopicDetailPageState();
}

class _TopicDetailPageState extends State<TopicDetailPage> {
  late Topic _topic;
  final LessonsService _lessonsService = LessonsService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final ProgressService _progressService = ProgressService();
  bool _isLoadingContent = true;
  bool _canAccess = true;
  bool _isTestCompleted = false;
  bool _isFavorite = false;
  bool _isLoadingAiContent = true;
  List<AiQuestion> _aiQuestions = [];
  AiMaterial? _aiMaterial;

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    // Sayfa hemen açılsın, kontroller arka planda yapılsın
    _isLoadingContent = false;

    // Cache'den sayıları hemen yükle (synchronous - çok hızlı)
    _loadCachedCounts();

    // AI içerikleri (soru/metin) - local cache'den yükle
    Future.microtask(_loadAiContent);

    // Favori durumunu kontrol et (arka planda, non-blocking)
    Future.microtask(() async {
      final isFavorite = await QuickAccessService.isInQuickAccess(_topic.id);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
        });
      }
    });

    // Abonelik kontrolünü arka planda yap (non-blocking)
    Future.microtask(() async {
      final canAccess = await _subscriptionService.canAccessTopic(_topic);
      if (mounted) {
        setState(() {
          _canAccess = canAccess;
        });

        if (!canAccess) {
          // Erişim yok, içerik yükleme
          return;
        }
      }

      // Erişim var, içerikleri kontrol et (arka planda)
      if (mounted) {
        // Cache geçerliyse Storage'dan çekme, sadece cache yoksa veya geçersizse çek
        _loadContentCountsIfNeeded();

        // Test tamamlanma durumunu kontrol et
        _checkTestCompletion();
      }
    });
  }

  Future<void> _loadAiContent() async {
    try {
      setState(() => _isLoadingAiContent = true);
      final questions = await AiContentService.instance.getQuestions(_topic.id);
      final material = await AiContentService.instance.getMaterial(_topic.id);
      if (!mounted) return;
      setState(() {
        _aiQuestions = questions;
        _aiMaterial = material;
        _isLoadingAiContent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAiContent = false);
    }
  }

  /// Cache'den sayıları hemen yükle (synchronous - çok hızlı)
  Future<void> _loadCachedCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Önce content_counts cache'inden tüm sayıları yükle (en hızlı)
      final contentCountsKey = 'content_counts_${_topic.id}';
      final contentCountsTimeKey = 'content_counts_time_${_topic.id}';
      final contentCountsJson = prefs.getString(contentCountsKey);
      final cacheTime = prefs.getInt(contentCountsTimeKey);

      // Cache geçerlilik süresi: 7 gün (içerik sayıları çok sık değişmez)
      const cacheValidDuration = Duration(days: 7);
      final now = DateTime.now().millisecondsSinceEpoch;
      final isCacheValid =
          cacheTime != null &&
          (now - cacheTime) < cacheValidDuration.inMilliseconds;

      if (contentCountsJson != null &&
          contentCountsJson.isNotEmpty &&
          isCacheValid) {
        try {
          final Map<String, dynamic> counts = jsonDecode(contentCountsJson);
          final videoCount = counts['videoCount'] as int? ?? _topic.videoCount;
          final podcastCount =
              counts['podcastCount'] as int? ?? _topic.podcastCount;
          final flashCardCount =
              counts['flashCardCount'] as int? ?? _topic.flashCardCount;
          final noteCount = counts['noteCount'] as int? ?? _topic.noteCount;
          final pdfCount = counts['pdfCount'] as int? ?? _topic.pdfCount;
          final testQuestionCount =
              counts['testQuestionCount'] as int? ??
              _topic.averageQuestionCount;

          // Cache'deki sayıları hemen göster
          if (mounted) {
            setState(() {
              _topic = Topic(
                id: _topic.id,
                lessonId: _topic.lessonId,
                name: _topic.name,
                subtitle: _topic.subtitle,
                duration: _topic.duration,
                averageQuestionCount: testQuestionCount,
                testCount: testQuestionCount > 0 ? 1 : 0,
                podcastCount: podcastCount,
                videoCount: videoCount,
                noteCount: noteCount,
                flashCardCount: flashCardCount,
                pdfCount: pdfCount,
                progress: _topic.progress,
                order: _topic.order,
                pdfUrl: _topic.pdfUrl,
              );
            });
          }

          // Eğer temel bilgiler (soru sayısı gibi) 0 ise, cache'e güvenme ve Storage'dan çekilmesine izin ver
          if (testQuestionCount > 0 || videoCount > 0 || pdfCount > 0) {
            debugPrint('✅ Loaded all content counts from cache immediately');
            return;
          }
          debugPrint('⚠️ Cache has 0 counts, will check Storage/Firestore');
        } catch (e) {
          debugPrint('⚠️ Error parsing content counts cache: $e');
        }
      }

      // Eğer content_counts cache'i yoksa, sadece soru sayısını cache'den çek (geriye dönük uyumluluk)
      final cacheKey = 'questions_${_topic.id}';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        // Çok hızlı: Sadece '{' karakterlerini say (parse etmeden)
        int braceCount = 0;
        for (int i = 0; i < cachedJson.length; i++) {
          if (cachedJson[i] == '{') braceCount++;
        }

        if (braceCount > 0 && braceCount != _topic.averageQuestionCount) {
          // Cache'deki sayıyı hemen göster
          setState(() {
            _topic = Topic(
              id: _topic.id,
              lessonId: _topic.lessonId,
              name: _topic.name,
              subtitle: _topic.subtitle,
              duration: _topic.duration,
              averageQuestionCount: braceCount,
              testCount: braceCount > 0 ? 1 : 0,
              podcastCount: _topic.podcastCount,
              videoCount: _topic.videoCount,
              noteCount: _topic.noteCount,
              flashCardCount: _topic.flashCardCount,
              pdfCount: _topic.pdfCount,
              progress: _topic.progress,
              order: _topic.order,
              pdfUrl: _topic.pdfUrl,
            );
          });
          debugPrint(
            '✅ Loaded question count from cache immediately: $braceCount',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cached counts: $e');
    }
  }

  /// İçerik sayılarını yükle - sadece cache yoksa veya geçersizse Storage'dan çek
  Future<void> _loadContentCountsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentCountsKey = 'content_counts_${_topic.id}';
      final contentCountsTimeKey = 'content_counts_time_${_topic.id}';
      final contentCountsJson = prefs.getString(contentCountsKey);
      final cacheTime = prefs.getInt(contentCountsTimeKey);

      // Cache geçerlilik süresi: 7 gün
      const cacheValidDuration = Duration(days: 7);
      final now = DateTime.now().millisecondsSinceEpoch;
      final isCacheValid =
          cacheTime != null &&
          (now - cacheTime) < cacheValidDuration.inMilliseconds;

      // Cache geçerliyse Storage'dan ÇEKME - hiç istek atma
      if (contentCountsJson != null &&
          contentCountsJson.isNotEmpty &&
          isCacheValid) {
        print(
          '✅ Content counts loaded from cache (NO Storage request - saving MB!)',
        );
        return;
      }

      // Cache yok veya geçersizse Storage'dan çek
      print('🌐 Loading content counts from Storage (cache miss or expired)');
      print('⚠️ WARNING: This will make Storage requests and use MB!');
      await _loadContentCounts();
    } catch (e) {
      print('⚠️ Error checking cache, loading from Storage: $e');
      await _loadContentCounts();
    }
  }

  Future<void> _loadContentCounts() async {
    // Arka planda içerik sayılarını çek (non-blocking)
    final updatedTopic = await _lessonsService.getTopicContentCounts(_topic);
    if (mounted) {
      setState(() {
        _topic = updatedTopic;
        // _isLoadingContent zaten false, sayfa açık
      });

      // Cache'e kaydet (timestamp ile)
      try {
        final prefs = await SharedPreferences.getInstance();
        final contentCountsKey = 'content_counts_${_topic.id}';
        final contentCountsTimeKey = 'content_counts_time_${_topic.id}';
        await prefs.setString(
          contentCountsKey,
          jsonEncode({
            'videoCount': _topic.videoCount,
            'podcastCount': _topic.podcastCount,
            'flashCardCount': _topic.flashCardCount,
            'noteCount': _topic.noteCount,
            'pdfCount': _topic.pdfCount,
            'testQuestionCount': _topic.averageQuestionCount,
          }),
        );
        await prefs.setInt(
          contentCountsTimeKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        print('✅ Saved content counts to cache (valid for 7 days)');
      } catch (e) {
        print('⚠️ Error saving content counts to cache: $e');
      }

      // Hızlı erişimdeki içerik sayılarını güncelle (PDF sayısı dahil)
      await QuickAccessService.updateContentCounts(
        topicId: _topic.id,
        podcastCount: _topic.podcastCount,
        videoCount: _topic.videoCount,
        flashCardCount: _topic.flashCardCount,
        pdfCount: _topic.pdfCount,
      );

      // Eğer favoriye ekliyse, anasayfayı yenile
      final isFavorite = await QuickAccessService.isInQuickAccess(_topic.id);
      if (isFavorite) {
        final mainScreen = MainScreen.of(context);
        if (mainScreen != null) {
          mainScreen.refreshHomePage();
        }
      }
    }
  }

  Future<void> _checkTestCompletion() async {
    if (_topic.averageQuestionCount == 0) return;

    try {
      final testResult = await _progressService.getTestResult(_topic.id);
      if (mounted) {
        setState(() {
          _isTestCompleted = testResult != null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error checking test completion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: const FloatingHomeButton(),
        body: Stack(
          children: [
            // Layer 1: Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // Layer 2: Main Content
            Column(
              children: [
                // Layer 3: Premium Header (instead of AppBar)
                _buildPremiumHeader(
                  context,
                  isDark,
                  isSmallScreen,
                  MediaQuery.of(context).padding.top,
                ),

                // Layer 4: Content
                Expanded(
                  child:
                      !_canAccess && !_subscriptionService.isTopicFree(_topic)
                      ? _buildPremiumRequiredScreen(
                          context,
                          isDark,
                          isSmallScreen,
                          isTablet,
                        )
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isTablet ? 800 : double.infinity,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 32 : 16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 8),
                                    _buildModernHeader(isDark),
                                    const SizedBox(height: 12),
                                    _buildSuccessPathLayout(
                                      context: context,
                                      isSmallScreen: isSmallScreen,
                                      isTablet: isTablet,
                                      isDark: isDark,
                                    ),
                                    if (!_isLoadingAiContent &&
                                        (_aiQuestions.isNotEmpty ||
                                            _aiMaterial != null)) ...[
                                      const SizedBox(height: 32),
                                      _buildAiGeneratedSection(
                                        isDark: isDark,
                                        isSmallScreen: isSmallScreen,
                                        isTablet: isTablet,
                                      ),
                                    ],
                                    const SizedBox(
                                      height: 120,
                                    ), // For floating button
                                  ],
                                ),
                              ),
                            ),
                          ),
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
        color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
        child: Stack(
          children: [
            _buildBlurCircle(
              -screenWidth * 0.2,
              -screenWidth * 0.2,
              screenWidth * 0.8,
              const Color(0xFF2563EB).withOpacity(isDark ? 0.12 : 0.08),
            ),
            _buildBlurCircle(
              screenWidth * 0.4,
              screenWidth * 0.1,
              screenWidth * 0.7,
              const Color(0xFF7C3AED).withOpacity(isDark ? 0.1 : 0.06),
            ),
            _buildBlurCircle(
              screenWidth * 0.1,
              screenWidth * 0.6,
              screenWidth * 0.9,
              const Color(0xFF2563EB).withOpacity(isDark ? 0.08 : 0.05),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double top, double left, double size, Color color) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(
    BuildContext context,
    bool isDark,
    bool isSmallScreen,
    double statusBarHeight,
  ) {
    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 4,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F0F1A) : Colors.white).withOpacity(
          0.8,
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03),
                padding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'KONU DETAYI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2563EB),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    _topic.name,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: _isFavorite
                    ? Colors.amber
                    : (isDark ? Colors.white70 : Colors.black54),
                size: 24,
              ),
              style: IconButton.styleFrom(
                backgroundColor: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.05),
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final oldFavoriteState = _isFavorite;
    final newFavoriteState = !oldFavoriteState;

    setState(() {
      _isFavorite = newFavoriteState;
    });

    try {
      await QuickAccessService.toggleQuickAccessItem(
        topicId: _topic.id,
        lessonId: _topic.lessonId,
        topicName: _topic.name,
        lessonName: widget.lessonName,
        podcastCount: _topic.podcastCount,
        videoCount: _topic.videoCount,
        flashCardCount: _topic.flashCardCount,
        pdfCount: _topic.pdfCount,
      );

      if (mounted) {
        final mainScreen = MainScreen.of(context);
        if (mainScreen != null) {
          mainScreen.refreshHomePage();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFavorite = oldFavoriteState;
        });
      }
    }
  }

  Widget _buildModernHeader(bool isDark) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/succes.jpg', // Using existing asset
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'BAŞARI YOLU',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adım adım hedefe doğru ilerleyelim.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Başarı yolu görseli üstte, altında içerik kartları.
  Widget _buildSuccessPathLayout({
    required BuildContext context,
    required bool isSmallScreen,
    required bool isTablet,
    required bool isDark,
  }) {
    final allCards = <Widget>[];

    // Card styling tokens
    Color getCardColor(String type) {
      switch (type) {
        case 'pdf':
          return const Color(0xFFF59E0B); // Amber
        case 'questions':
          return const Color(0xFFEF4444); // Red
        case 'tests':
          return const Color(0xFF3B82F6); // Blue
        case 'podcasts':
          return const Color(0xFF8B5CF6); // Purple
        case 'videos':
          return const Color(0xFFF43F5E); // Rose
        case 'flashcards':
          return const Color(0xFF10B981); // Emerald
        case 'notes':
          return const Color(0xFF06B6D4); // Cyan
        default:
          return Colors.blue;
      }
    }

    // Konu Anlatımı
    if (widget.lessonName.toLowerCase() != 'türkçe') {
      allCards.add(
        _buildModernPathCard(
          context: context,
          type: 'pdf',
          title: 'Konu Anlatımı',
          count: _isLoadingContent ? 0 : _topic.pdfCount,
          countLabel: 'içerik',
          icon: Icons.auto_stories_rounded,
          color: getCardColor('pdf'),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfsPage(
                  topicName: _topic.name,
                  pdfCount: _topic.pdfCount,
                  topicId: _topic.id,
                  lessonId: _topic.lessonId,
                  topic: _topic,
                ),
              ),
            );
            if (result == true && mounted) {
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) mainScreen.refreshHomePage();
            }
          },
        ),
      );
    }
    // Çıkmış Sorular
    if (widget.lessonName.toLowerCase() != 'matematik') {
      allCards.add(
        _buildModernPathCard(
          context: context,
          type: 'questions',
          title: 'Çıkmış Sorular',
          subtitle: 'Soru Dağılımı',
          count: _topic.averageQuestionCount,
          countLabel: 'soru',
          icon: Icons.history_edu_rounded,
          color: getCardColor('questions'),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PastQuestionsPage(
                  topicName: _topic.name,
                  averageQuestionCount: _topic.averageQuestionCount,
                ),
              ),
            );
          },
        ),
      );
    }
    // Testler
    allCards.add(
      _buildModernPathCard(
        context: context,
        type: 'tests',
        title: 'Konu Testleri',
        count: _isLoadingContent ? 0 : _topic.averageQuestionCount,
        countLabel: 'soru',
        icon: Icons.checklist_rtl_rounded,
        color: getCardColor('tests'),
        isSmallScreen: isSmallScreen,
        isDark: isDark,
        isTestCompleted: _isTestCompleted,
        onTap: () async {
          if (_topic.testCount > 1) {
            final tests = <Map<String, dynamic>>[];
            for (int i = 1; i <= _topic.testCount; i++) {
              tests.add({'name': 'Test $i', 'questionCount': 10});
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TestsListPage(
                  topicName: _topic.name,
                  lessonId: _topic.lessonId,
                  topicId: _topic.id,
                  testCount: _topic.testCount,
                  tests: tests,
                ),
              ),
            );
            if (result == true && mounted) {
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) mainScreen.refreshHomePage();
            }
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TestsPage(
                  topicName: _topic.name,
                  testCount: _topic.testCount,
                  lessonId: _topic.lessonId,
                  topicId: _topic.id,
                ),
              ),
            );
            if (result == true && mounted) {
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) mainScreen.refreshHomePage();
              _checkTestCompletion();
            }
          }
        },
      ),
    );
    // Podcastler
    if (widget.lessonName.toLowerCase() != 'matematik') {
      allCards.add(
        _buildModernPathCard(
          context: context,
          type: 'podcasts',
          title: 'Podcastler',
          count: _isLoadingContent ? 0 : _topic.podcastCount,
          countLabel: 'içerik',
          icon: Icons.headphones_rounded,
          color: getCardColor('podcasts'),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PodcastsPage(
                  topicName: _topic.name,
                  podcastCount: _topic.podcastCount,
                  topicId: _topic.id,
                  lessonId: _topic.lessonId,
                ),
              ),
            );
            if (result == true && mounted) {
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) mainScreen.refreshHomePage();
            }
          },
        ),
      );
    }
    // Videolar
    if (widget.lessonName.toLowerCase() != 'türkçe' &&
        widget.lessonName.toLowerCase() != 'matematik') {
      allCards.add(
        _buildModernPathCard(
          context: context,
          type: 'videos',
          title: 'Videolar',
          count: _isLoadingContent ? 0 : _topic.videoCount,
          countLabel: 'içerik',
          icon: Icons.play_circle_fill_rounded,
          color: getCardColor('videos'),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideosPage(
                  topicName: _topic.name,
                  videoCount: _topic.videoCount,
                  topicId: _topic.id,
                  lessonId: _topic.lessonId,
                ),
              ),
            );
            if (result == true && mounted) {
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) mainScreen.refreshHomePage();
            }
          },
        ),
      );
    }
    // Bilgi Kartları
    if (widget.lessonName.toLowerCase() != 'matematik') {
      allCards.add(
        _buildModernPathCard(
          context: context,
          type: 'flashcards',
          title: 'Bilgi Kartları',
          count: _isLoadingContent ? 0 : _topic.flashCardCount,
          countLabel: 'içerik',
          icon: Icons.layers_rounded,
          color: getCardColor('flashcards'),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FlashCardsPage(
                  topicName: _topic.name,
                  cardCount: _topic.flashCardCount,
                  topicId: _topic.id,
                  lessonId: _topic.lessonId,
                ),
              ),
            );
            if (result == true && mounted) {
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) mainScreen.refreshHomePage();
            }
          },
        ),
      );
    }
    // Notlar
    allCards.add(
      _buildModernPathCard(
        context: context,
        type: 'notes',
        title: 'Özel Notlar',
        count: _isLoadingContent ? 0 : _topic.noteCount,
        countLabel: 'içerik',
        icon: Icons.push_pin_rounded,
        color: getCardColor('notes'),
        isSmallScreen: isSmallScreen,
        isDark: isDark,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotesPage(
                topicName: _topic.name,
                noteCount: _topic.noteCount,
              ),
            ),
          );
        },
      ),
    );

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allCards.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: allCards[index],
        );
      },
    );
  }

  /// Redesigned Modern Card
  Widget _buildModernPathCard({
    required BuildContext context,
    required String type,
    required String title,
    String? subtitle,
    required int count,
    required String countLabel,
    required IconData icon,
    required Color color,
    required bool isSmallScreen,
    required bool isDark,
    required VoidCallback onTap,
    bool isTestCompleted = false,
  }) {
    final label = countLabel == 'soru' ? '$count soru' : '$count içerik';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Icon Box with specific type style
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, color: color, size: 22),
                      if (isTestCompleted)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Text Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF334155),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (subtitle != null) ...[
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    (isDark
                                            ? Colors.white
                                            : const Color(0xFF64748B))
                                        .withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.03,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiGeneratedSection({
    required bool isDark,
    required bool isSmallScreen,
    required bool isTablet,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 900
        ? 1100.0
        : (isTablet ? 800.0 : double.infinity);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  decoration: BoxDecoration(
                    color: AppColors.gradientPurpleStart.withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.gradientPurpleStart,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI İçerikler',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 10 : 12),
            if (_aiQuestions.isNotEmpty)
              _buildAiQuestionsCard(
                isDark: isDark,
                isSmallScreen: isSmallScreen,
              ),
            if (_aiQuestions.isNotEmpty && _aiMaterial != null)
              const SizedBox(height: 12),
            if (_aiMaterial != null)
              _buildAiMaterialCard(
                isDark: isDark,
                isSmallScreen: isSmallScreen,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiQuestionsCard({
    required bool isDark,
    required bool isSmallScreen,
  }) {
    final previewCount = _aiQuestions.length >= 2 ? 2 : _aiQuestions.length;
    final accent = AppColors.gradientPurpleStart;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : accent.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  color: accent,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Sorular',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_aiQuestions.length} soru kaydedildi',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiQuestionsPage(
                        topicId: _topic.id,
                        topicName: _topic.name,
                      ),
                    ),
                  );
                  await _loadAiContent();
                },
                child: const Text('Hepsi'),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          ...List.generate(previewCount, (i) {
            final q = _aiQuestions[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == previewCount - 1 ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF242424)
                      : const Color(0xFFF7F7FB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '• ${q.question}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    height: 1.35,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAiMaterialCard({
    required bool isDark,
    required bool isSmallScreen,
  }) {
    final accent = const Color(0xFFFF9800);
    final content = _aiMaterial?.content ?? '';
    final preview = content.trim().isEmpty
        ? ''
        : (content.length > 220
              ? '${content.substring(0, 220).trim()}…'
              : content.trim());

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : accent.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: accent,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Konu Metni',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 15 : 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _aiMaterial?.title ?? 'Kaydedilmiş çalışma metni',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AiMaterialPage(
                        topicId: _topic.id,
                        topicName: _topic.name,
                      ),
                    ),
                  );
                  await _loadAiContent();
                },
                child: const Text('Aç'),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            SizedBox(height: isSmallScreen ? 10 : 12),
            Text(
              preview,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.4,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumRequiredScreen(
    BuildContext context,
    bool isDark,
    bool isSmallScreen,
    bool isTablet,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: isSmallScreen ? 40 : 60),
            // Lock Icon
            Container(
              width: isSmallScreen ? 100 : 120,
              height: isSmallScreen ? 100 : 120,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: isSmallScreen ? 50 : 60,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            // Title
            Text(
              'Premium Gerekli',
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            // Description
            Text(
              'Bu konuya erişmek için Premium aboneliğe ihtiyacınız var.\n\n'
              'Her dersin ilk konusu ücretsizdir. Diğer konular için Premium\'a geçin.',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),
            // Upgrade Button
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionPage(),
                  ),
                );
                // Premium aktif edildiyse erişim durumunu yeniden kontrol et
                if (result == true && mounted) {
                  final canAccess = await _subscriptionService.canAccessTopic(
                    _topic,
                  );
                  setState(() {
                    _canAccess = canAccess;
                  });
                  // Erişim varsa içerikleri yükle
                  if (canAccess) {
                    _loadContentCounts();
                    _checkTestCompletion();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 32 : 40,
                  vertical: isSmallScreen ? 14 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'Premium\'a Geç',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            // Features
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium ile:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildFeatureItem(
                    'Tüm konulara sınırsız erişim',
                    isDark,
                    isSmallScreen,
                  ),
                  _buildFeatureItem(
                    'Sınırsız video ve podcast',
                    isDark,
                    isSmallScreen,
                  ),
                  _buildFeatureItem(
                    'Sınırsız PDF indirme',
                    isDark,
                    isSmallScreen,
                  ),
                  _buildFeatureItem(
                    'Gelişmiş istatistikler',
                    isDark,
                    isSmallScreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, bool isDark, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 10),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: isSmallScreen ? 18 : 20,
            color: AppColors.primaryBlue,
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
