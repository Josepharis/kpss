import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/lessons_service.dart';
import '../widgets/lesson_card.dart';
import 'lesson_detail_page.dart';

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  final LessonsService _lessonsService = LessonsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock progress data - will be replaced with real user progress data later
  double _getProgress(String lessonId) {
    // TODO: Replace with real user progress from Firestore
    return 0.0;
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
        .where((lesson) =>
            lesson.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            lesson.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0xFF8B5CF6),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            // Custom AppBar with Status Bar (like homepage but different color)
            Container(
              padding: EdgeInsets.only(
                top: statusBarHeight,
                bottom: isSmallScreen ? 10.0 : 14.0,
                left: isTablet ? 24.0 : 16.0,
                right: isTablet ? 24.0 : 16.0,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF8B5CF6),
                    const Color(0xFF7C3AED),
                    const Color(0xFF6D28D9),
                  ],
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
                                final count = snapshot.hasData ? snapshot.data!.length : 0;
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ders ara...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
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
                  final genelYetenek = _filterLessons(
                      allLessons.where((l) => l.category == 'genel_yetenek').toList());
                  final genelKultur = _filterLessons(
                      allLessons.where((l) => l.category == 'genel_kultur').toList());
                  final alanDersleri = _filterLessons(
                      allLessons.where((l) => l.category == 'alan_dersleri').toList());

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (genelYetenek.isNotEmpty)
                        _buildCategorySection(
                          context: context,
                          title: _getCategoryTitle('genel_yetenek'),
                          lessons: genelYetenek,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                        ),
                      if (genelYetenek.isNotEmpty && genelKultur.isNotEmpty)
                        const SizedBox(height: 16),
                      if (genelKultur.isNotEmpty)
                        _buildCategorySection(
                          context: context,
                          title: _getCategoryTitle('genel_kultur'),
                          lessons: genelKultur,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
                        ),
                      if (genelKultur.isNotEmpty && alanDersleri.isNotEmpty)
                        const SizedBox(height: 16),
                      if (alanDersleri.isNotEmpty)
                        _buildCategorySection(
                          context: context,
                          title: _getCategoryTitle('alan_dersleri'),
                          lessons: alanDersleri,
                          isSmallScreen: isSmallScreen,
                          isTablet: isTablet,
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
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 4 : 3,
            crossAxisSpacing: isSmallScreen ? 8 : 10,
            mainAxisSpacing: isSmallScreen ? 8 : 10,
            childAspectRatio: isTablet ? 0.68 : 0.70,
          ),
          itemCount: lessons.length,
          itemBuilder: (context, index) {
            final lesson = lessons[index];
            final progress = _getProgress(lesson.id);
            return LessonCard(
              lesson: lesson,
              progress: progress,
              isSmallScreen: isSmallScreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonDetailPage(
                      lesson: lesson,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
