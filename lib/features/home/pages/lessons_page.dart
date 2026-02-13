import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/progress_service.dart';
import '../widgets/lesson_card.dart';
import 'lesson_detail_page.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> with WidgetsBindingObserver {
  final LessonsService _lessonsService = LessonsService();
  final ProgressService _progressService = ProgressService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Navigate to detail page
  Future<void> _navigateToDetail(Lesson lesson) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LessonDetailPage(lesson: lesson)),
    );
    // Stream will automatically update when progress changes
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'genel_yetenek':
        return 'Genel Yetenek';
      case 'genel_kultur':
        return 'Genel Kültür';
      case 'alan_dersleri':
        return 'Alan Dersleri';
      default:
        return '';
    }
  }

  List<Lesson> _filterLessons(List<Lesson> lessons) {
    if (_searchQuery.isEmpty) {
      return lessons;
    }
    return lessons
        .where(
          (lesson) =>
              lesson.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              lesson.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stream will automatically update when app resumes
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final orientation = MediaQuery.of(context).orientation;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor1 = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFF8B5CF6);
    final headerColor2 = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFF7C3AED);
    final headerColor3 = isDark
        ? const Color(0xFF121212)
        : const Color(0xFF6D28D9);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark
            ? const Color(0xFF121212)
            : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          children: [
            // Custom AppBar with Status Bar (like homepage but different color)
            Container(
              padding: EdgeInsets.only(
                top: statusBarHeight,
                bottom: isSmallScreen ? 6.0 : 8.0,
                left: isTablet ? 24.0 : 16.0,
                right: isTablet ? 24.0 : 16.0,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [headerColor1, headerColor2, headerColor3],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dersler',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 20 : 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            StreamBuilder<List<Lesson>>(
                              stream: _lessonsService.streamAllLessons(),
                              builder: (context, snapshot) {
                                final count = snapshot.hasData
                                    ? snapshot.data!.length
                                    : 0;
                                return Text(
                                  '$count ders • Tüm konular',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 12),
                  // Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: isDark
                          ? Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      cursorColor: isDark
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ders ara...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white.withOpacity(0.65)
                              : Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark
                              ? Colors.white.withOpacity(0.65)
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: StreamBuilder<List<Lesson>>(
                stream: _lessonsService.streamAllLessons(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Veriler yüklenirken bir hata oluştu',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {});
                            },
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz ders eklenmemiş',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allLessons = _filterLessons(snapshot.data!);
                  final genelKultur = _filterLessons(
                    allLessons
                        .where((l) => l.category == 'genel_kultur')
                        .toList(),
                  );
                  final genelYetenek = _filterLessons(
                    allLessons
                        .where((l) => l.category == 'genel_yetenek')
                        .toList(),
                  );

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      isSmallScreen ? 10 : 12,
                      4.0,
                      isSmallScreen ? 10 : 12,
                      isSmallScreen ? 10 : 12,
                    ),
                    children: [
                      if (genelKultur.isNotEmpty)
                        _buildCategorySection(
                          context: context,
                          title: _getCategoryTitle('genel_kultur'),
                          lessons: genelKultur,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                          orientation: orientation,
                        ),
                      if (genelKultur.isNotEmpty && genelYetenek.isNotEmpty)
                        const SizedBox(height: 16),
                      if (genelYetenek.isNotEmpty)
                        _buildCategorySection(
                          context: context,
                          title: _getCategoryTitle('genel_yetenek'),
                          lessons: genelYetenek,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                          orientation: orientation,
                        ),
                      if (allLessons.isEmpty && _searchQuery.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Aradığınız ders bulunamadı',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection({
    required BuildContext context,
    required String title,
    required List<Lesson> lessons,
    required bool isSmallScreen,
    required bool isTablet,
    required Orientation orientation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: isSmallScreen ? 16 : 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF8B5CF6),
                      const Color(0xFF8B5CF6).withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 10),
              Builder(
                builder: (context) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  final textColor = isDark
                      ? Colors.white
                      : AppColors.textPrimary;

                  return Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 0.3,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;

            // Hedef: kart genişliği ~145-190px bandında kalsın (telefon landscape dahil).
            // Bu sayede yatay modda kartlar "çok büyük" görünmez.
            final isLandscape = orientation == Orientation.landscape;
            final spacing = isSmallScreen ? 10.0 : 14.0;
            final targetCardWidth = isTablet
                ? 210.0
                : (isLandscape ? 160.0 : 170.0);

            var crossAxisCount = (availableWidth / targetCardWidth).floor();
            final minCount = 2;
            final maxCount = isTablet ? 6 : 5;
            crossAxisCount = crossAxisCount.clamp(minCount, maxCount);

            // Ultra-Premium Compact Grid Layout
            final double mainAxisExtent = isTablet
                ? (isLandscape ? 145 : 160)
                : (isLandscape ? 125 : (isSmallScreen ? 125 : 135));

            // Kart genişliği kontrolü
            final approxCardWidth =
                (availableWidth - spacing * (crossAxisCount - 1)) /
                crossAxisCount;
            if (approxCardWidth > (isTablet ? 230 : 210) &&
                crossAxisCount < maxCount) {
              crossAxisCount = math.min(maxCount, crossAxisCount + 1);
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                mainAxisExtent: mainAxisExtent,
              ),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                return StreamBuilder<double?>(
                  stream: _progressService.streamLessonProgress(lesson.id),
                  builder: (context, snapshot) {
                    double progress = 0.0;

                    if (snapshot.hasData && snapshot.data != null) {
                      progress = snapshot.data!;
                    } else if (snapshot.connectionState ==
                            ConnectionState.waiting ||
                        !snapshot.hasData) {
                      return FutureBuilder<double?>(
                        future: _progressService.getLessonProgress(lesson.id),
                        builder: (context, cacheSnapshot) {
                          final cachedProgress =
                              cacheSnapshot.hasData &&
                                  cacheSnapshot.data != null
                              ? cacheSnapshot.data!
                              : 0.0;
                          return LessonCard(
                            lesson: lesson,
                            progress: cachedProgress,
                            isSmallScreen: isSmallScreen,
                            onTap: () => _navigateToDetail(lesson),
                          );
                        },
                      );
                    }

                    return LessonCard(
                      lesson: lesson,
                      progress: progress,
                      isSmallScreen: isSmallScreen,
                      onTap: () => _navigateToDetail(lesson),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
