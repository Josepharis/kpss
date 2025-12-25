import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../widgets/lesson_card.dart';
import 'lesson_detail_page.dart';

class LessonsPage extends StatelessWidget {
  const LessonsPage({super.key});

  List<Lesson> get _allLessons {
    return [
      Lesson(
        id: '1',
        name: 'Türkçe',
        category: 'genel_yetenek',
        icon: 'menu_book',
        color: 'orange',
        topicCount: 12,
        questionCount: 450,
        description: 'Sözcükte anlam, cümlede anlam, paragraf ve dil bilgisi',
      ),
      Lesson(
        id: '2',
        name: 'Matematik',
        category: 'genel_yetenek',
        icon: 'calculate',
        color: 'blue',
        topicCount: 15,
        questionCount: 520,
        description: 'Temel matematik, geometri ve sayısal mantık',
      ),
      Lesson(
        id: '3',
        name: 'Tarih',
        category: 'genel_kultur',
        icon: 'history',
        color: 'red',
        topicCount: 18,
        questionCount: 680,
        description: 'Türk tarihi, Osmanlı tarihi ve dünya tarihi',
      ),
      Lesson(
        id: '4',
        name: 'Coğrafya',
        category: 'genel_kultur',
        icon: 'map',
        color: 'green',
        topicCount: 14,
        questionCount: 420,
        description: 'Türkiye coğrafyası ve genel coğrafya bilgileri',
      ),
      Lesson(
        id: '5',
        name: 'Vatandaşlık',
        category: 'genel_kultur',
        icon: 'gavel',
        color: 'purple',
        topicCount: 8,
        questionCount: 280,
        description: 'Anayasa, hukuk ve vatandaşlık bilgileri',
      ),
      Lesson(
        id: '6',
        name: 'Eğitim Bilimleri',
        category: 'alan_dersleri',
        icon: 'school',
        color: 'teal',
        topicCount: 20,
        questionCount: 750,
        description: 'Gelişim psikolojisi, öğrenme psikolojisi ve öğretim yöntemleri',
      ),
      Lesson(
        id: '7',
        name: 'Öğretmenlik Alan Bilgisi',
        category: 'alan_dersleri',
        icon: 'person',
        color: 'indigo',
        topicCount: 16,
        questionCount: 580,
        description: 'Alan bilgisi ve öğretim teknikleri',
      ),
      Lesson(
        id: '8',
        name: 'Rehberlik',
        category: 'alan_dersleri',
        icon: 'psychology',
        color: 'pink',
        topicCount: 10,
        questionCount: 320,
        description: 'Rehberlik ve psikolojik danışmanlık',
      ),
    ];
  }

  List<Lesson> _getLessonsByCategory(String category) {
    return _allLessons.where((lesson) => lesson.category == category).toList();
  }

  // Mock progress data - will be replaced with real data later
  double _getProgress(String lessonId) {
    switch (lessonId) {
      case '1':
        return 0.35; // 35% completed
      case '2':
        return 0.42;
      case '3':
        return 0.28;
      case '4':
        return 0.55;
      case '5':
        return 0.18;
      case '6':
        return 0.38;
      case '7':
        return 0.45;
      case '8':
        return 0.22;
      default:
        return 0.0;
    }
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
                            Text(
                              '${_allLessons.length} ders • Tüm konular',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
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
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
            _buildCategorySection(
              context: context,
              title: _getCategoryTitle('genel_yetenek'),
              lessons: _getLessonsByCategory('genel_yetenek'),
              isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
            ),
                  const SizedBox(height: 16),
            _buildCategorySection(
              context: context,
              title: _getCategoryTitle('genel_kultur'),
              lessons: _getLessonsByCategory('genel_kultur'),
              isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
            ),
                  const SizedBox(height: 16),
            _buildCategorySection(
              context: context,
              title: _getCategoryTitle('alan_dersleri'),
              lessons: _getLessonsByCategory('alan_dersleri'),
              isSmallScreen: isSmallScreen,
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 12),
                ],
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
