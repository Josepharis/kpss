import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;
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
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildHeader(
                    context,
                    isDark,
                    statusBarHeight,
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
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D0221),
                    const Color(0xFF0F0F1A),
                    const Color(0xFF19102E),
                  ]
                : [const Color(0xFFF0F4FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -screenWidth * 0.4,
              left: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: isDark
                    ? const Color(0xFF4C1D95).withValues(alpha: 0.15)
                    : const Color(0xFFC4B5FD).withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              top: 200,
              right: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.0,
                color: isDark
                    ? const Color(0xFFBE185D).withValues(alpha: 0.1)
                    : const Color(0xFFFBCFE8).withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              bottom: -100,
              left: 50,
              child: _buildBlurCircle(
                size: screenWidth * 0.8,
                color: isDark
                    ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                    : const Color(0xFFCCFBF1).withValues(alpha: 0.2),
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
          center: Alignment.center,
          radius: 0.5,
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.1, 1.0],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    double statusBarHeight,
    int totalQuestions,
    int totalCards,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, statusBarHeight + 10, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF4F46E5).withValues(alpha: 0.9),
                        const Color(0xFF1E1B4B).withValues(alpha: 0.85),
                      ]
                    : [
                        const Color(0xFF4F46E5).withValues(alpha: 0.95),
                        const Color(0xFF3B82F6).withValues(alpha: 0.9),
                      ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kaydedilenler',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.2,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.quiz_rounded,
                      count: totalQuestions,
                      label: 'Soru',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 10),
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
                              _buildActionButton(
                                icon: Icons.auto_awesome_rounded,
                                label: 'Tüm Sorular',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AllSavedQuestionsPage(),
                                    ),
                                  ).then((_) => _loadData());
                                },
                              ),
                            if (index == 1)
                              _buildActionButton(
                                icon: Icons.grid_view_rounded,
                                label: 'Tüm Kartlar',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AllSavedCardsPage(),
                                    ),
                                  ).then((_) => _loadData());
                                },
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
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFA5B4FC)],
                      ).createShader(bounds),
                      child: Icon(icon, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      height: 46,
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E1E2E) : Colors.white).withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.5),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4F46E5), const Color(0xFF7C3AED)]
                : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isDark ? const Color(0xFF4F46E5) : const Color(0xFF3B82F6))
                      .withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_rounded, size: 16),
                SizedBox(width: 6),
                Text('Sorular'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style_rounded, size: 16),
                SizedBox(width: 6),
                Text('Kartlar'),
              ],
            ),
          ),
        ],
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
              color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
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
      color: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          final weaknessCount = _getWeaknessCountForLesson(lesson.id);
          final topicCount = _getTopicCountForLesson(lesson.id);
          return _buildLessonCard(
            isDark: isDark,
            lesson: lesson,
            type: _SavedContentType.questions,
            count: weaknessCount,
            topicCount: topicCount,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeaknessLessonDetailPage(lesson: lesson),
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
      color: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: lessons.length,
        itemBuilder: (context, index) {
          final lesson = lessons[index];
          final cardCount = _getSavedCardCountForLesson(lesson.id);
          final topicCount = _getSavedCardTopicCountForLesson(lesson.id);
          return _buildLessonCard(
            isDark: isDark,
            lesson: lesson,
            type: _SavedContentType.cards,
            count: cardCount,
            topicCount: topicCount,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedCardLessonDetailPage(lesson: lesson),
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
                    : const Color(0xFF2563EB).withValues(alpha: 0.08)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: isDark
                    ? Colors.white38
                    : const Color(0xFF2563EB).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white.withOpacity(0.06) : Colors.white)
                  .withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.white,
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1E293B),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _buildMiniBadge(
                                  isDark: isDark,
                                  icon: Icons.folder_rounded,
                                  text: '$topicCount konu',
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 6),
                                _buildMiniBadge(
                                  isDark: isDark,
                                  icon: isQuestions
                                      ? Icons.quiz_rounded
                                      : Icons.style_rounded,
                                  text:
                                      '$count ${isQuestions ? 'soru' : 'kart'}',
                                  color: isQuestions
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF10B981),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge({
    required bool isDark,
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
