import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/saved_cards_service.dart';
import 'weakness_lesson_detail_page.dart';
import 'saved_card_lesson_detail_page.dart';
import 'all_saved_cards_page.dart';
import 'all_saved_questions_page.dart';

enum _SavedContentType { questions, cards }

class WeaknessesPage extends StatefulWidget {
  const WeaknessesPage({super.key});

  @override
  State<WeaknessesPage> createState() => _WeaknessesPageState();
}

class _WeaknessesPageState extends State<WeaknessesPage>
    with SingleTickerProviderStateMixin {
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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadLessons();
    await _loadWeaknesses();
    await _loadSavedCards();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSavedCards() async {
    try {
      final grouped = await SavedCardsService.getSavedCardsGroupedByLesson();
      if (mounted) setState(() => _savedCardsGroupedByLesson = grouped);
    } catch (_) {}
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await _lessonsService.getAllLessons();
      if (mounted) setState(() => _allLessons = lessons);
    } catch (e) {
      debugPrint('Error loading lessons: $e');
    }
  }

  Future<void> _loadWeaknesses() async {
    final grouped = await WeaknessesService.getWeaknessesGroupedByLesson();
    if (mounted) setState(() => _groupedByLesson = grouped);
  }

  List<Lesson> _getLessonsWithWeaknesses() {
    return _allLessons
        .where(
          (l) =>
              _groupedByLesson.containsKey(l.id) &&
              _groupedByLesson[l.id]!.isNotEmpty,
        )
        .toList();
  }

  List<Lesson> _getLessonsWithSavedCards() {
    return _allLessons
        .where(
          (l) =>
              _savedCardsGroupedByLesson.containsKey(l.id) &&
              _savedCardsGroupedByLesson[l.id]!.isNotEmpty,
        )
        .toList();
  }

  int _getWeaknessCountForLesson(String id) =>
      _groupedByLesson[id]?.length ?? 0;
  int _getSavedCardCountForLesson(String id) =>
      _savedCardsGroupedByLesson[id]?.length ?? 0;

  int _getTopicCountForLesson(String id) {
    final w = _groupedByLesson[id];
    if (w == null || w.isEmpty) return 0;
    return w.map((e) => e.topicName).toSet().length;
  }

  int _getSavedCardTopicCountForLesson(String id) {
    final c = _savedCardsGroupedByLesson[id];
    if (c == null || c.isEmpty) return 0;
    return c.map((e) => e.topicName).toSet().length;
  }

  IconData _lessonIcon(String icon) {
    const map = {
      'menu_book': Icons.menu_book_rounded,
      'calculate': Icons.calculate_rounded,
      'history': Icons.history_rounded,
      'map': Icons.map_rounded,
      'gavel': Icons.gavel_rounded,
      'school': Icons.school_rounded,
      'person': Icons.person_rounded,
      'psychology': Icons.psychology_rounded,
    };
    return map[icon] ?? Icons.book_rounded;
  }

  Color _lessonColor(String color) {
    const map = {
      'orange': Color(0xFFFF6B35),
      'blue': AppColors.primaryBlue,
      'red': Color(0xFFE74C3C),
      'green': Color(0xFF27AE60),
      'purple': Color(0xFF9B59B6),
      'teal': Color(0xFF16A085),
      'indigo': Color(0xFF5C6BC0),
      'pink': Color(0xFFE91E63),
    };
    return map[color.toLowerCase()] ?? AppColors.primaryBlue;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final totalQuestions = _groupedByLesson.values.fold<int>(
      0,
      (s, l) => s + l.length,
    );
    final totalCards = _savedCardsGroupedByLesson.values.fold<int>(
      0,
      (s, l) => s + l.length,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0D0D0D)
            : const Color(0xFFF8F9FA),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(
                context,
                isDark,
                topPadding,
                totalQuestions,
                totalCards,
              ),
              _buildTabBar(context, isDark),
              Expanded(
                child: _isLoading
                    ? _buildLoader(isDark)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildQuestionsTab(isDark),
                          _buildCardsTab(isDark),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    double topPadding,
    int totalQuestions,
    int totalCards,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  const Color(0xFF0F3460),
                ]
              : [
                  const Color(0xFF2563EB),
                  const Color(0xFF1D4ED8),
                  const Color(0xFF1E40AF),
                ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kaydedilenler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                // Refresh button removed
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatChip(
                  icon: Icons.quiz_rounded,
                  count: totalQuestions,
                  label: 'Soru',
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  icon: Icons.style_rounded,
                  count: totalCards,
                  label: 'Kart',
                  color: const Color(0xFF10B981),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _tabController.animation!,
                  builder: (context, _) {
                    final index = _tabController.animation!.value.round();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (index == 0)
                          Material(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AllSavedQuestionsPage(),
                                  ),
                                ).then((_) => _loadData());
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.quiz_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Soruları Birleştir',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (index == 1)
                          Material(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AllSavedCardsPage(),
                                  ),
                                ).then((_) => _loadData());
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_motion_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Kartları Birleştir',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: isDark ? const Color(0xFF2563EB) : AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color:
                    (isDark ? const Color(0xFF2563EB) : AppColors.primaryBlue)
                        .withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: isDark
              ? Colors.white54
              : AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Test Soruları'),
            Tab(text: 'Bilgi Kartları'),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isDark ? const Color(0xFF3B82F6) : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsTab(bool isDark) {
    final lessons = _getLessonsWithWeaknesses();
    if (lessons.isEmpty) {
      return _buildEmptyState(
        isDark: isDark,
        icon: Icons.quiz_outlined,
        title: 'Henüz kaydedilmiş soru yok',
        subtitle:
            'Test çözerken yanlış yaptığınız veya manuel eklediğiniz sorular burada görünecek.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryBlue,
      backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          final weaknessCount = _getWeaknessCountForLesson(lesson.id);
          final topicCount = _getTopicCountForLesson(lesson.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildLessonCard(
              isDark: isDark,
              lesson: lesson,
              type: _SavedContentType.questions,
              count: weaknessCount,
              topicCount: topicCount,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WeaknessLessonDetailPage(lesson: lesson),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardsTab(bool isDark) {
    final lessons = _getLessonsWithSavedCards();
    if (lessons.isEmpty) {
      return _buildEmptyState(
        isDark: isDark,
        icon: Icons.style_outlined,
        title: 'Henüz kaydedilmiş bilgi kartı yok',
        subtitle:
            'Bilgi kartları sayfasında kaydet butonuna bastığınız kartlar burada listelenir.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primaryBlue,
      backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          final cardCount = _getSavedCardCountForLesson(lesson.id);
          final topicCount = _getSavedCardTopicCountForLesson(lesson.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildLessonCard(
              isDark: isDark,
              lesson: lesson,
              type: _SavedContentType.cards,
              count: cardCount,
              topicCount: topicCount,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SavedCardLessonDetailPage(lesson: lesson),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.white10
                    : AppColors.primaryBlue.withValues(alpha: 0.08)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: isDark
                    ? Colors.white38
                    : AppColors.primaryBlue.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard({
    required bool isDark,
    required Lesson lesson,
    required _SavedContentType type,
    required int count,
    required int topicCount,
    required VoidCallback onTap,
  }) {
    final color = _lessonColor(lesson.color);
    final icon = _lessonIcon(lesson.icon);
    final isQuestions = type == _SavedContentType.questions;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lesson.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildMiniBadge(
                          isDark: isDark,
                          icon: Icons.folder_rounded,
                          text: '$topicCount konu',
                        ),
                        const SizedBox(width: 6),
                        _buildMiniBadge(
                          isDark: isDark,
                          icon: isQuestions
                              ? Icons.quiz_rounded
                              : Icons.style_rounded,
                          text: '$count ${isQuestions ? 'soru' : 'kart'}',
                          accentColor: isQuestions
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF10B981),
                        ),
                      ],
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

  Widget _buildMiniBadge({
    required bool isDark,
    required IconData icon,
    required String text,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color:
            (accentColor ??
                    (isDark ? Colors.white12 : AppColors.backgroundBeige))
                .withValues(
                  alpha: accentColor != null ? 0.2 : (isDark ? 0.5 : 1),
                ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color:
                accentColor ??
                (isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
