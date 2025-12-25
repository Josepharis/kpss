import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import 'weakness_lesson_detail_page.dart';

class WeaknessesPage extends StatefulWidget {
  const WeaknessesPage({super.key});

  @override
  State<WeaknessesPage> createState() => _WeaknessesPageState();
}

class _WeaknessesPageState extends State<WeaknessesPage> {
  Map<String, List<WeaknessQuestion>> _groupedByLesson = {};
  bool _isLoading = true;

  // Tüm dersler listesi
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

  @override
  void initState() {
    super.initState();
    _initializeMockData();
  }

  Future<void> _initializeMockData() async {
    // Mock sorunun zaten ekli olup olmadığını kontrol et
    final existing = await WeaknessesService.isQuestionInWeaknesses(
      'mock_1',
      'de/da Bağlacı',
      lessonId: '1', // Türkçe dersi
    );

    if (!existing) {
      // Mock soruyu ekle
      final mockWeakness = WeaknessQuestion(
        id: 'mock_1',
        question: 'Aşağıdaki cümlelerden hangisinde "de" bağlacı yanlış yazılmıştır?',
        options: [
          'A) O da buraya gelecek.',
          'B) Sen de mi gideceksin?',
          'C) Bende bir şeyler var.',
          'D) O da benim gibi düşünüyor.',
        ],
        correctAnswerIndex: 2,
        explanation: '"de" bağlacı ayrı yazılır. Cümlede "Bende" yerine "Bende de" yazılmalıydı.',
        lessonId: '1', // Türkçe dersi
        topicName: 'de/da Bağlacı',
        addedAt: DateTime.now(),
        isFromWrongAnswer: true,
      );

      await WeaknessesService.addWeakness(mockWeakness);
    }

    // Verileri yükle
    _loadWeaknesses();
  }

  Future<void> _loadWeaknesses() async {
    setState(() {
      _isLoading = true;
    });

    final grouped = await WeaknessesService.getWeaknessesGroupedByLesson();
    
    if (mounted) {
      setState(() {
        _groupedByLesson = grouped;
        _isLoading = false;
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

  // Bir dersteki eksik soru sayısını getir
  int _getWeaknessCountForLesson(String lessonId) {
    return _groupedByLesson[lessonId]?.length ?? 0;
  }

  // Bir dersteki eksik soru olan konu sayısını getir
  int _getTopicCountForLesson(String lessonId) {
    final weaknesses = _groupedByLesson[lessonId];
    if (weaknesses == null || weaknesses.isEmpty) return 0;
    
    final uniqueTopics = weaknesses.map((w) => w.topicName).toSet();
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
    switch (color) {
      case 'orange':
        return const Color(0xFFFF6B35);
      case 'blue':
        return const Color(0xFF4A90E2);
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
          'Eksiklerim',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (lessonsWithWeaknesses.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadWeaknesses,
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
          : lessonsWithWeaknesses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        size: 80,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz eksik soru yok',
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
                )
              : RefreshIndicator(
                  onRefresh: _loadWeaknesses,
                  color: AppColors.primaryBlue,
                  child: ListView(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    children: [
                      // İstatistik Kartı (Kompakt)
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
                              Icons.trending_down_rounded,
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
                ),
    );
  }
}
