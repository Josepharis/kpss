import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/saved_cards_service.dart';
import 'weakness_lesson_detail_page.dart';
import 'saved_card_lesson_detail_page.dart';

class WeaknessesPage extends StatefulWidget {
  const WeaknessesPage({super.key});

  @override
  State<WeaknessesPage> createState() => _WeaknessesPageState();
}

class _WeaknessesPageState extends State<WeaknessesPage> with SingleTickerProviderStateMixin {
  Map<String, List<WeaknessQuestion>> _groupedByLesson = {};
  Map<String, List<SavedCard>> _savedCardsGroupedByLesson = {};
  List<Lesson> _allLessons = [];
  bool _isLoading = true;
  final LessonsService _lessonsService = LessonsService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadLessons();
    await _loadWeaknesses();
    await _loadSavedCards();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedCards() async {
    try {
      final grouped = await SavedCardsService.getSavedCardsGroupedByLesson();
      
      if (mounted) {
        setState(() {
          _savedCardsGroupedByLesson = grouped;
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await _lessonsService.getAllLessons();
      if (mounted) {
        setState(() {
          _allLessons = lessons;
        });
      }
    } catch (e) {
      debugPrint('Error loading lessons: $e');
    }
  }

  Future<void> _loadWeaknesses() async {
    final grouped = await WeaknessesService.getWeaknessesGroupedByLesson();
    
    if (mounted) {
      setState(() {
        _groupedByLesson = grouped;
      });
    }
  }

  // Eksik soru olan dersleri getir
  List<Lesson> _getLessonsWithWeaknesses() {
    return _allLessons.where((lesson) {
      return _groupedByLesson.containsKey(lesson.id) &&
          _groupedByLesson[lesson.id]!.isNotEmpty;
    }).toList();
  }

  // Kaydedilmiş kartları olan dersleri getir
  List<Lesson> _getLessonsWithSavedCards() {
    return _allLessons.where((lesson) {
      return _savedCardsGroupedByLesson.containsKey(lesson.id) &&
          _savedCardsGroupedByLesson[lesson.id]!.isNotEmpty;
    }).toList();
  }

  // Bir dersteki eksik soru sayısını getir
  int _getWeaknessCountForLesson(String lessonId) {
    return _groupedByLesson[lessonId]?.length ?? 0;
  }

  // Bir dersteki kaydedilmiş kart sayısını getir
  int _getSavedCardCountForLesson(String lessonId) {
    return _savedCardsGroupedByLesson[lessonId]?.length ?? 0;
  }

  // Bir dersteki eksik soru olan konu sayısını getir
  int _getTopicCountForLesson(String lessonId) {
    final weaknesses = _groupedByLesson[lessonId];
    if (weaknesses == null || weaknesses.isEmpty) return 0;
    
    final uniqueTopics = weaknesses.map((w) => w.topicName).toSet();
    return uniqueTopics.length;
  }

  // Bir dersteki kaydedilmiş kart olan konu sayısını getir
  int _getSavedCardTopicCountForLesson(String lessonId) {
    final savedCards = _savedCardsGroupedByLesson[lessonId];
    if (savedCards == null || savedCards.isEmpty) return 0;
    
    final uniqueTopics = savedCards.map((c) => c.topicName).toSet();
    return uniqueTopics.length;
  }

  // Ders ikonunu getir
  IconData _getLessonIcon(String icon) {
    switch (icon) {
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'history':
        return Icons.history_rounded;
      case 'map':
        return Icons.map_rounded;
      case 'gavel':
        return Icons.gavel_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      default:
        return Icons.book_rounded;
    }
  }

  // Ders rengini getir
  Color _getLessonColor(String color) {
    switch (color.toLowerCase()) {
      case 'orange':
        return const Color(0xFFFF6B35);
      case 'blue':
        return AppColors.primaryBlue;
      case 'red':
        return const Color(0xFFE74C3C);
      case 'green':
        return const Color(0xFF27AE60);
      case 'purple':
        return const Color(0xFF9B59B6);
      case 'teal':
        return const Color(0xFF16A085);
      case 'indigo':
        return const Color(0xFF5C6BC0);
      case 'pink':
        return const Color(0xFFE91E63);
      default:
        return AppColors.primaryBlue;
    }
  }

  // Basit ders kartı widget'ı
  Widget _buildSimpleLessonCard({
    required Lesson lesson,
    required int weaknessCount,
    required int topicCount,
    required bool isTablet,
    required bool isSmallScreen,
  }) {
    final color = _getLessonColor(lesson.color);
    final icon = _getLessonIcon(lesson.icon);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeaknessLessonDetailPage(
              lesson: lesson,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.85),
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
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // İkon
              Icon(
                icon,
                size: isSmallScreen ? 26 : 30,
                color: Colors.white,
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              // Ders adı
              Text(
                lesson.name,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              // Konu ve soru sayısı (şık tasarım)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Konu sayısı (mavi/turuncu)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_books_rounded,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 5),
                        Text(
                          '$topicCount konu',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 5 : 6),
                  // Soru sayısı (kırmızı)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.quiz_rounded,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 5),
                        Text(
                          '$weaknessCount soru',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final lessonsWithWeaknesses = _getLessonsWithWeaknesses();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: const Text(
          'Kaydedilenler',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Test Soruları'),
            Tab(text: 'Bilgi Kartları'),
          ],
        ),
        actions: [
          if (lessonsWithWeaknesses.isNotEmpty || _getLessonsWithSavedCards().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadData,
              tooltip: 'Yenile',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Test Soruları Sekmesi
                _buildQuestionsTab(isTablet, isSmallScreen, lessonsWithWeaknesses),
                // Bilgi Kartları Sekmesi
                _buildCardsTab(isTablet, isSmallScreen),
              ],
            ),
    );
  }

  Widget _buildQuestionsTab(bool isTablet, bool isSmallScreen, List<Lesson> lessonsWithWeaknesses) {
    if (lessonsWithWeaknesses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz kaydedilmiş soru yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Test çözerken yanlış yaptığınız sorular\nveya manuel olarak eklediğiniz sorular\nburada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        children: [
          // İstatistik Kartı
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue,
                  AppColors.primaryDarkBlue,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.quiz_rounded,
                  color: Colors.white,
                  size: isSmallScreen ? 18 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Toplam: ${_groupedByLesson.values.fold<int>(0, (sum, list) => sum + list.length)} soru',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          // Dersler Listesi
          Text(
            'Dersler',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet ? 4 : 3,
              crossAxisSpacing: isSmallScreen ? 8 : 10,
              mainAxisSpacing: isSmallScreen ? 8 : 10,
              childAspectRatio: isTablet ? 0.70 : 0.75,
            ),
            itemCount: lessonsWithWeaknesses.length,
            itemBuilder: (context, index) {
              final lesson = lessonsWithWeaknesses[index];
              final weaknessCount = _getWeaknessCountForLesson(lesson.id);
              final topicCount = _getTopicCountForLesson(lesson.id);
              
              return _buildSimpleLessonCard(
                lesson: lesson,
                weaknessCount: weaknessCount,
                topicCount: topicCount,
                isTablet: isTablet,
                isSmallScreen: isSmallScreen,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardsTab(bool isTablet, bool isSmallScreen) {
    final lessonsWithSavedCards = _getLessonsWithSavedCards();
    
    if (lessonsWithSavedCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.style_outlined,
              size: 80,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz kaydedilmiş bilgi kartı yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bilgi kartları sayfasında kaydet butonuna\nbastığınız kartlar burada görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryBlue,
      child: ListView(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        children: [
          // İstatistik Kartı
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.gradientGreenStart,
                  AppColors.gradientGreenEnd,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientGreenStart.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.style_rounded,
                  color: Colors.white,
                  size: isSmallScreen ? 18 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Toplam: ${_savedCardsGroupedByLesson.values.fold<int>(0, (sum, list) => sum + list.length)} kart',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          // Dersler Listesi
          Text(
            'Dersler',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isTablet ? 4 : 3,
              crossAxisSpacing: isSmallScreen ? 8 : 10,
              mainAxisSpacing: isSmallScreen ? 8 : 10,
              childAspectRatio: isTablet ? 0.70 : 0.75,
            ),
            itemCount: lessonsWithSavedCards.length,
            itemBuilder: (context, index) {
              final lesson = lessonsWithSavedCards[index];
              final cardCount = _getSavedCardCountForLesson(lesson.id);
              final topicCount = _getSavedCardTopicCountForLesson(lesson.id);
              
              return _buildSavedCardLessonCard(
                lesson: lesson,
                cardCount: cardCount,
                topicCount: topicCount,
                isTablet: isTablet,
                isSmallScreen: isSmallScreen,
              );
            },
          ),
        ],
      ),
    );
  }

  // Kaydedilmiş kartlar için ders kartı
  Widget _buildSavedCardLessonCard({
    required Lesson lesson,
    required int cardCount,
    required int topicCount,
    required bool isTablet,
    required bool isSmallScreen,
  }) {
    final color = _getLessonColor(lesson.color);
    final icon = _getLessonIcon(lesson.icon);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SavedCardLessonDetailPage(
              lesson: lesson,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.85),
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
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // İkon
              Icon(
                icon,
                size: isSmallScreen ? 26 : 30,
                color: Colors.white,
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              // Ders adı
              Text(
                lesson.name,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmallScreen ? 6 : 8),
              // Konu ve kart sayısı
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Konu sayısı
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_books_rounded,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 5),
                        Text(
                          '$topicCount konu',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 5 : 6),
                  // Kart sayısı
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 4 : 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientGreenStart,
                          AppColors.gradientGreenEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gradientGreenStart.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.style_rounded,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 5),
                        Text(
                          '$cardCount kart',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
