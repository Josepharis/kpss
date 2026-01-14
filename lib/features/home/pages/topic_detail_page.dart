import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/subscription_service.dart';
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
  bool _isLoadingContent = true;
  bool _canAccess = true;

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    // Sayfa hemen açılsın, kontroller arka planda yapılsın
    _isLoadingContent = false;
    
    // Cache'den sayıları hemen yükle (synchronous - çok hızlı)
    _loadCachedCounts();
    
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
      
      // Erişim var, içerikleri yükle (arka planda)
      if (mounted) {
        if (_topic.videoCount == 0 && _topic.podcastCount == 0 && _topic.averageQuestionCount == 0 && 
            _topic.noteCount == 0 && _topic.flashCardCount == 0 && _topic.pdfCount == 0) {
          // Arka planda yükle, sayfa hemen açılsın
          _loadContentCounts();
        } else {
          // Sayılar var ama güncel olmayabilir, arka planda güncelle
          _loadContentCounts();
        }
      }
    });
  }

  /// Cache'den sayıları hemen yükle (synchronous - çok hızlı)
  Future<void> _loadCachedCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Önce content_counts cache'inden tüm sayıları yükle (en hızlı)
      final contentCountsKey = 'content_counts_${_topic.id}';
      final contentCountsJson = prefs.getString(contentCountsKey);
      
      if (contentCountsJson != null && contentCountsJson.isNotEmpty) {
        try {
          final Map<String, dynamic> counts = jsonDecode(contentCountsJson);
          final videoCount = counts['videoCount'] as int? ?? _topic.videoCount;
          final podcastCount = counts['podcastCount'] as int? ?? _topic.podcastCount;
          final flashCardCount = counts['flashCardCount'] as int? ?? _topic.flashCardCount;
          final noteCount = counts['noteCount'] as int? ?? _topic.noteCount;
          final pdfCount = counts['pdfCount'] as int? ?? _topic.pdfCount;
          final testQuestionCount = counts['testQuestionCount'] as int? ?? _topic.averageQuestionCount;
          
          // Cache'deki sayıları hemen göster
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
          debugPrint('✅ Loaded all content counts from cache immediately (videos: $videoCount, podcasts: $podcastCount, questions: $testQuestionCount)');
          return; // Cache'den yüklendi, soru sayısını tekrar kontrol etmeye gerek yok
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
          debugPrint('✅ Loaded question count from cache immediately: $braceCount');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cached counts: $e');
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
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
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
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryDarkBlue,
                    ],
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: !_canAccess && !_subscriptionService.isTopicFree(_topic)
          ? _buildPremiumRequiredScreen(context, isDark, isSmallScreen, isTablet)
          : Column(
                  children: [
                    // Content
                    Expanded(
                      child: SingleChildScrollView(
              padding: EdgeInsets.all(isTablet ? 20 : 14),
              child: Column(
                children: [
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // 2x3 Grid for main content
                  // Tablet ve büyük ekranlarda kartların maksimum boyutunu sınırla
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTablet ? 600 : double.infinity,
                      ),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: isSmallScreen ? 10 : 12,
                        mainAxisSpacing: isSmallScreen ? 10 : 12,
                        childAspectRatio: 1.15,
                        children: [
                      // Konu Anlatımı - Türkçe için gizle
                      if (widget.lessonName.toLowerCase() != 'türkçe')
                        _buildPremiumCard(
                          context: context,
                          title: 'Konu Anlatımı',
                          count: _isLoadingContent ? 0 : _topic.pdfCount,
                          icon: Icons.picture_as_pdf_rounded,
                          color: const Color(0xFFFF9800),
                          isSmallScreen: isSmallScreen,
                          onTap: () async {
                          debugPrint('📄 Konu Anlatımı kartına tıklandı');
                          debugPrint('   PDF Count: ${_topic.pdfCount}');
                          debugPrint('   Topic ID: ${_topic.id}');
                          debugPrint('   Lesson ID: ${_topic.lessonId}');
                          
                          // Her zaman PDF sayfasına git (PDF'ler Storage'dan yüklenecek)
                          // PDF sayısı 0 olsa bile, Storage'da PDF olabilir
                          debugPrint('✅ Navigating to PDFsPage (PDFs will be loaded from Storage)...');
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
                          if (result == true) {
                            final mainScreen = MainScreen.of(context);
                            if (mainScreen != null) {
                              mainScreen.refreshHomePage();
                            }
                          }
                        },
                      ),
                      // Çıkmış Sorular / Soru Dağılımı - Matematik için gizle
                      if (widget.lessonName.toLowerCase() != 'matematik')
                        _buildPremiumCard(
                          context: context,
                        title: 'Çıkmış Sorular',
                        subtitle: 'Soru Dağılımı',
                        count: _topic.averageQuestionCount,
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFFFF6B35),
                        isSmallScreen: isSmallScreen,
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
                      // Testler
                      _buildPremiumCard(
                        context: context,
                        title: 'Testler',
                        count: _isLoadingContent ? 0 : _topic.averageQuestionCount, // Soru sayısını göster
                        icon: Icons.quiz_rounded,
                        color: AppColors.primaryBlue,
                        isSmallScreen: isSmallScreen,
                        onTap: () async {
                          // Eğer birden fazla test varsa liste ekranına git
                          if (_topic.testCount > 1) {
                            // Testleri oluştur (şimdilik testCount kadar test oluştur)
                            final tests = <Map<String, dynamic>>[];
                            for (int i = 1; i <= _topic.testCount; i++) {
                              tests.add({
                                'name': 'Test $i',
                                'questionCount': 10, // Varsayılan soru sayısı, gerçekte servisten alınabilir
                              });
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
                            // If test list page returned true, refresh home page
                            if (result == true) {
                              final mainScreen = MainScreen.of(context);
                              if (mainScreen != null) {
                                mainScreen.refreshHomePage();
                              }
                            }
                          } else {
                            // Tek test varsa direkt test sayfasına git
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
                          // If test page returned true, refresh home page
                          if (result == true) {
                            final mainScreen = MainScreen.of(context);
                            if (mainScreen != null) {
                              mainScreen.refreshHomePage();
                              }
                            }
                          }
                        },
                      ),
                      // Podcastler - Matematik için gizle
                      if (widget.lessonName.toLowerCase() != 'matematik')
                        _buildPremiumCard(
                          context: context,
                        title: 'Podcastler',
                        count: _isLoadingContent ? 0 : _topic.podcastCount,
                        icon: Icons.podcasts_rounded,
                        color: AppColors.gradientPurpleStart,
                        isSmallScreen: isSmallScreen,
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
                          // If podcast page returned true, refresh home page
                          if (result == true) {
                            final mainScreen = MainScreen.of(context);
                            if (mainScreen != null) {
                              mainScreen.refreshHomePage();
                            }
                          }
                        },
                      ),
                      // Videolar - Türkçe ve Matematik için gizle
                      if (widget.lessonName.toLowerCase() != 'türkçe' && widget.lessonName.toLowerCase() != 'matematik')
                        _buildPremiumCard(
                          context: context,
                        title: 'Videolar',
                        count: _isLoadingContent ? 0 : _topic.videoCount,
                        icon: Icons.video_library_rounded,
                        color: const Color(0xFFE74C3C),
                        isSmallScreen: isSmallScreen,
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
                          // If videos page returned true, refresh home page
                          if (result == true) {
                            final mainScreen = MainScreen.of(context);
                            if (mainScreen != null) {
                              mainScreen.refreshHomePage();
                            }
                          }
                        },
                      ),
                      // Bilgi Kartları - Matematik için gizle
                      if (widget.lessonName.toLowerCase() != 'matematik')
                        _buildPremiumCard(
                          context: context,
                        title: 'Bilgi Kartları',
                        count: _isLoadingContent ? 0 : _topic.flashCardCount,
                        icon: Icons.style_rounded,
                        color: AppColors.gradientRedStart,
                        isSmallScreen: isSmallScreen,
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
                          // If flash cards page returned true, refresh home page
                          if (result == true) {
                            final mainScreen = MainScreen.of(context);
                            if (mainScreen != null) {
                              mainScreen.refreshHomePage();
                            }
                          }
                        },
                      ),
                      // Notlar
                      _buildPremiumCard(
                        context: context,
                        title: 'Notlar',
                        count: _isLoadingContent ? 0 : _topic.noteCount,
                        icon: Icons.note_rounded,
                        color: AppColors.gradientGreenStart,
                        isSmallScreen: isSmallScreen,
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
                    ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 280,
          maxHeight: 240,
        ),
        child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.2,
                      colors: [
                        Colors.white.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Pattern overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Decorative glow
              Positioned(
                top: -12,
                right: -12,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon container
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.25),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: isSmallScreen ? 22 : 24,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    // Title and count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: isSmallScreen ? 2 : 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SizedBox(height: isSmallScreen ? 4 : 6),
                          Text(
                            subtitle != null && subtitle.contains('Soru') 
                               ? '$count soru'
                               : title == 'Testler'
                                   ? '$count soru'
                                   : '$count içerik',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.95),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                );
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
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
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
