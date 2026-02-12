import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : AppColors.backgroundLight,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const FloatingHomeButton(),
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 70 : 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryBlue, AppColors.primaryDarkBlue],
                  ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : AppColors.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                // Watermark
                Positioned(
                  top: -10,
                  right: -10,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'KPSS',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.08),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
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
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _topic.name,
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
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      // Favorite button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final oldFavoriteState = _isFavorite;
                            final newFavoriteState = !oldFavoriteState;

                            // Optimistic UI Update
                            setState(() {
                              _isFavorite = newFavoriteState;
                            });

                            try {
                              // Perform actual toggle in background
                              final result =
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

                              if (mounted && result != newFavoriteState) {
                                setState(() {
                                  _isFavorite = result;
                                });
                              }

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
                              _isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: _isFavorite ? Colors.amber : Colors.white,
                              size: isSmallScreen ? 18 : 20,
                            ),
                          ),
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
      body: !_canAccess && !_subscriptionService.isTopicFree(_topic)
          ? _buildPremiumRequiredScreen(
              context,
              isDark,
              isSmallScreen,
              isTablet,
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 14,
                      vertical: isSmallScreen ? 10 : 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSuccessPathLayout(
                          context: context,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                          isDark: isDark,
                        ),
                        if (!_isLoadingAiContent &&
                            (_aiQuestions.isNotEmpty ||
                                _aiMaterial != null)) ...[
                          SizedBox(height: isSmallScreen ? 14 : 18),
                          _buildAiGeneratedSection(
                            isDark: isDark,
                            isSmallScreen: isSmallScreen,
                            isTablet: isTablet,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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

    void addCard(Widget card) {
      allCards.add(card);
    }

    // Konu Anlatımı
    if (widget.lessonName.toLowerCase() != 'türkçe') {
      addCard(
        _buildModernPathCard(
          context: context,
          title: 'Konu Anlatımı',
          count: _isLoadingContent ? 0 : _topic.pdfCount,
          countLabel: 'içerik',
          icon: Icons.picture_as_pdf_rounded,
          color: const Color(0xFFFF9800),
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
      addCard(
        _buildModernPathCard(
          context: context,
          title: 'Çıkmış Sorular',
          subtitle: 'Soru Dağılımı',
          count: _topic.averageQuestionCount,
          countLabel: 'soru',
          icon: Icons.analytics_rounded,
          color: const Color(0xFFFF6B35),
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
    addCard(
      _buildModernPathCard(
        context: context,
        title: 'Testler',
        count: _isLoadingContent ? 0 : _topic.averageQuestionCount,
        countLabel: 'soru',
        icon: Icons.quiz_rounded,
        color: AppColors.primaryBlue,
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
      addCard(
        _buildModernPathCard(
          context: context,
          title: 'Podcastler',
          count: _isLoadingContent ? 0 : _topic.podcastCount,
          countLabel: 'içerik',
          icon: Icons.podcasts_rounded,
          color: AppColors.gradientPurpleStart,
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
      addCard(
        _buildModernPathCard(
          context: context,
          title: 'Videolar',
          count: _isLoadingContent ? 0 : _topic.videoCount,
          countLabel: 'içerik',
          icon: Icons.video_library_rounded,
          color: const Color(0xFFE74C3C),
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
      addCard(
        _buildModernPathCard(
          context: context,
          title: 'Bilgi Kartları',
          count: _isLoadingContent ? 0 : _topic.flashCardCount,
          countLabel: 'içerik',
          icon: Icons.style_rounded,
          color: AppColors.gradientRedStart,
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
    addCard(
      _buildModernPathCard(
        context: context,
        title: 'Notlar',
        count: _isLoadingContent ? 0 : _topic.noteCount,
        countLabel: 'içerik',
        icon: Icons.note_rounded,
        color: AppColors.gradientGreenStart,
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

    // Her zaman dar ekran düzenini kullan: önce görsel, altında kartlar (tek sütun)
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: double.infinity,
            height: 160,
            child: Image.asset('assets/images/succes.jpg', fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        ...allCards.map(
          (w) => Padding(
            padding: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
            child: w,
          ),
        ),
      ],
    );
  }

  /// Görsele uyumlu, modern yol kenarı kartı.
  Widget _buildModernPathCard({
    required BuildContext context,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 14 : 16,
            vertical: isSmallScreen ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : color.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.12 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.3 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(icon, size: 22, color: color)),
                    if (isTestCompleted)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.gradientGreenStart,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white60
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: isDark ? Colors.white38 : AppColors.textLight,
              ),
            ],
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
