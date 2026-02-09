import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ai_material.dart';
import '../../../core/models/ai_question.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/study_program.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/ai_content_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/study_program_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final LessonsService _lessonsService = LessonsService();
  List<Lesson> _lessons = [];
  List<Topic> _topics = [];
  bool _isLoadingLessons = true;
  Lesson? _selectedLesson;
  Topic? _selectedTopic;
  String _selectedFeature = ''; // 'question', 'material', 'program', 'gap'
  String? _generatedFeature; // Hangi özellik için örnek üretildi

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await _lessonsService.getAllLessons();
      if (mounted) {
        setState(() {
          _lessons = lessons;
          _isLoadingLessons = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLessons = false;
        });
      }
    }
  }

  Future<void> _loadTopics(String lessonId) async {
    try {
      final topics = await _lessonsService.getTopicsByLessonId(lessonId);
      if (mounted) {
        setState(() {
          _topics = topics;
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  void _handleFeatureTap(String feature) {
    setState(() {
      _selectedFeature = feature;
      _selectedLesson = null;
      _selectedTopic = null;
      _topics = [];
      _generatedFeature = null;
    });
  }

  void _handleLessonSelect(Lesson lesson) async {
    setState(() {
      _selectedLesson = lesson;
      _selectedTopic = null;
    });
    await _loadTopics(lesson.id);
  }

  void _handleTopicSelect(Topic topic) {
    setState(() {
      _selectedTopic = topic;
    });
  }

  void _startGeneration() {
    if (_selectedFeature.isEmpty) return;

    switch (_selectedFeature) {
      case 'question':
        if (_selectedTopic == null) {
          _showError('Lütfen bir konu seçin');
          return;
        }
        setState(() {
          _generatedFeature = 'question';
        });
        break;
      case 'material':
        if (_selectedTopic == null) {
          _showError('Lütfen bir konu seçin');
          return;
        }
        setState(() {
          _generatedFeature = 'material';
        });
        break;
      case 'program':
        _showProgramModal(context);
        break;
      case 'gap':
        if (_selectedLesson == null) {
          _showError('Lütfen bir ders seçin');
          return;
        }
        setState(() {
          _generatedFeature = 'gap';
        });
        break;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveExampleQuestionsToTopic() async {
    final topic = _selectedTopic;
    if (topic == null) {
      _showError('Lütfen bir konu seçin');
      return;
    }

    // Demo içerik: örnek 5 soru kaydet
    final questions = <AiQuestion>[
      AiQuestion(
        question:
            'Aşağıdakilerden hangisi "${topic.name}" konusu kapsamında temel bir kavram değildir?',
        options: const [
          'Devredilemezlik',
          'Vazgeçilemezlik',
          'Dokunulamazlık',
          'Sadece olağanüstü hâllerde sınırlanabilirlik',
          'Anayasal güvence',
        ],
        correctIndex: 3,
        explanation:
            'Hak ve özgürlükler olağan dönemlerde de kanunla sınırlandırılabilir. Bu nedenle “sadece OHAL’de” ifadesi yanlıştır.',
      ),
      AiQuestion(
        question: '"${topic.name}" ile ilgili aşağıdaki ifadelerden hangisi doğrudur?',
        options: const [
          'Sadece idari düzenlemelerle sınırlandırılabilir.',
          'Sınırlama ancak kanunla yapılabilir.',
          'Hiçbir koşulda sınırlandırılamaz.',
          'Sınırlama için gerekçe gösterilmesine gerek yoktur.',
          'Sınırlama ölçülülük ilkesine tabi değildir.',
        ],
        correctIndex: 1,
        explanation:
            'Temel hak ve özgürlükler Anayasa’da belirtilen sebeplerle ve yalnızca kanunla sınırlandırılabilir; ölçülülük gözetilir.',
      ),
      AiQuestion(
        question: '"${topic.name}" konusu için en uygun çalışma sırası aşağıdakilerden hangisidir?',
        options: const [
          'Sadece test çözmek',
          'Özet → örnek soru → yanlış analizi',
          'Sadece video izlemek',
          'Sadece not ezberlemek',
          'Hiç tekrar yapmamak',
        ],
        correctIndex: 1,
        explanation:
            'Kısa özet + uygulama (soru) + yanlış analizi kombinasyonu kalıcılığı artırır.',
      ),
      AiQuestion(
        question: 'Aşağıdakilerden hangisi ölçülülük ilkesinin unsurlarındandır?',
        options: const [
          'Eşitlik',
          'Gerekli olma',
          'Yetki genişliği',
          'Hukuki güvenlik',
          'Hakkaniyet',
        ],
        correctIndex: 1,
        explanation:
            'Ölçülülük; elverişlilik, gereklilik ve orantılılık unsurlarını kapsar.',
      ),
      AiQuestion(
        question: '"${topic.name}" çalışırken en sık yapılan hata aşağıdakilerden hangisidir?',
        options: const [
          'Kavramları karıştırmak',
          'Kısa tekrarlar yapmak',
          'Yanlışları not almak',
          'Örnek soru çözmek',
          'Konu özetlemek',
        ],
        correctIndex: 0,
        explanation:
            'Kavramların birbirine yakın olması nedeniyle tanım/istisna farklarını karıştırmak sık görülür.',
      ),
    ];

    await AiContentService.instance.saveQuestions(topic.id, questions);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI soruları konuya kaydedildi.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveExampleMaterialToTopic() async {
    final topic = _selectedTopic;
    final lesson = _selectedLesson;
    if (topic == null) {
      _showError('Lütfen bir konu seçin');
      return;
    }

    final title = 'AI Çalışma Metni';
    final content = StringBuffer()
      ..writeln('Konu: ${topic.name}')
      ..writeln('Ders: ${lesson?.name ?? ''}')
      ..writeln('')
      ..writeln('1) Temel Kavramlar')
      ..writeln('- Tanım, kapsam ve temel amaçlar.')
      ..writeln('- KPSS’de sık çıkan anahtar kelimeler.')
      ..writeln('')
      ..writeln('2) Ortak Özellikler / İlkeler')
      ..writeln('- Devredilemezlik, vazgeçilemezlik, dokunulamazlık.')
      ..writeln('- Ölçülülük ve demokratik toplum düzeni.')
      ..writeln('')
      ..writeln('3) Hızlı Tekrar')
      ..writeln('- 5 dakikalık mini özet + 10 soru + yanlış analizi.')
      ..writeln('')
      ..writeln('Not: Bu metin demo olarak kaydedilmiştir; gerçek AI üretimi bağlandığında otomatik olarak güncellenebilir.');

    final material = AiMaterial(
      title: title,
      content: content.toString(),
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await AiContentService.instance.saveMaterial(topic.id, material);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI konu metni kaydedildi.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveExampleProgram() async {
    final program = StudyProgram(
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      title: 'Haftalık Çalışma Programı',
      subtitle: '7 Günlük Plan',
      days: const [
        StudyProgramDay(
          weekday: 1,
          tasks: [
            StudyProgramTask(
              start: '09:00',
              end: '10:00',
              title: 'Konu çalış',
              kind: 'konu',
              lesson: 'Vatandaşlık',
              topic: 'Temel Haklar',
              detail: '60 dk',
            ),
            StudyProgramTask(
              start: '10:15',
              end: '10:35',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Vatandaşlık',
              topic: 'Karma',
              detail: '20 soru',
            ),
            StudyProgramTask(
              start: '14:00',
              end: '14:30',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Türkçe',
              topic: 'Paragraf',
              detail: '30 dk',
            ),
          ],
        ),
        StudyProgramDay(
          weekday: 2,
          tasks: [
            StudyProgramTask(
              start: '09:00',
              end: '09:45',
              title: 'Konu çalış',
              kind: 'konu',
              lesson: 'Tarih',
              topic: 'İÖ Türk Tarihi',
              detail: '45 dk',
            ),
            StudyProgramTask(
              start: '10:00',
              end: '10:20',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Tarih',
              topic: 'Karma',
              detail: '15 soru',
            ),
            StudyProgramTask(
              start: '14:00',
              end: '14:30',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Matematik',
              topic: 'Problemler',
              detail: '30 dk',
            ),
          ],
        ),
        StudyProgramDay(
          weekday: 3,
          tasks: [
            StudyProgramTask(
              start: '09:00',
              end: '09:40',
              title: 'Konu çalış',
              kind: 'konu',
              lesson: 'Coğrafya',
              topic: 'Türkiye’nin Konumu',
              detail: '40 dk',
            ),
            StudyProgramTask(
              start: '10:00',
              end: '10:25',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Coğrafya',
              topic: 'Karma',
              detail: '20 soru',
            ),
            StudyProgramTask(
              start: '14:00',
              end: '14:20',
              title: 'Tekrar',
              kind: 'tekrar',
              lesson: 'Genel',
              topic: '',
              detail: '20 dk',
            ),
          ],
        ),
        StudyProgramDay(
          weekday: 4,
          tasks: [
            StudyProgramTask(
              start: '09:00',
              end: '09:45',
              title: 'Konu çalış',
              kind: 'konu',
              lesson: 'Güncel Bilgiler',
              topic: 'Özet',
              detail: '45 dk',
            ),
            StudyProgramTask(
              start: '10:00',
              end: '10:20',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Karma',
              topic: '',
              detail: '15 soru',
            ),
            StudyProgramTask(
              start: '14:00',
              end: '14:30',
              title: 'Yanlış analizi',
              kind: 'tekrar',
              lesson: 'Genel',
              topic: '',
              detail: '30 dk',
            ),
          ],
        ),
        StudyProgramDay(
          weekday: 5,
          tasks: [
            StudyProgramTask(
              start: '09:00',
              end: '09:50',
              title: 'Konu çalış',
              kind: 'konu',
              lesson: 'Vatandaşlık',
              topic: 'Yürütme',
              detail: '50 dk',
            ),
            StudyProgramTask(
              start: '10:05',
              end: '10:30',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Vatandaşlık',
              topic: 'Karma',
              detail: '20 soru',
            ),
          ],
        ),
        StudyProgramDay(
          weekday: 6,
          tasks: [
            StudyProgramTask(
              start: '10:00',
              end: '10:40',
              title: 'Konu çalış',
              kind: 'konu',
              lesson: 'Türkçe',
              topic: 'Dil Bilgisi',
              detail: '40 dk',
            ),
            StudyProgramTask(
              start: '11:00',
              end: '11:25',
              title: 'Test çöz',
              kind: 'test',
              lesson: 'Türkçe',
              topic: 'Karma',
              detail: '20 soru',
            ),
          ],
        ),
        StudyProgramDay(
          weekday: 7,
          tasks: [
            StudyProgramTask(
              start: '11:00',
              end: '11:30',
              title: 'Tekrar',
              kind: 'tekrar',
              lesson: 'Genel',
              topic: 'Haftalık',
              detail: '30 dk',
            ),
            StudyProgramTask(
              start: '11:40',
              end: '12:10',
              title: 'Deneme',
              kind: 'test',
              lesson: 'Karma',
              topic: '',
              detail: '30 dk',
            ),
          ],
        ),
      ],
    );

    await StudyProgramService.instance.saveProgram(program);
  }

  void _showProgramModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: screenHeight * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.only(
                top: isSmallScreen ? 16 : 20,
                left: isSmallScreen ? 18 : 24,
                right: isSmallScreen ? 18 : 24,
                bottom: isSmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gradientTealStart,
                    AppColors.gradientTealEnd,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haftalık Çalışma Programı',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Genel Kültür • 7 Günlük Plan',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue.withValues(alpha: 0.1),
                            AppColors.gradientTealStart.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              isSmallScreen,
                              isDark,
                              Icons.access_time_rounded,
                              'Toplam Süre',
                              '~18 saat',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              isSmallScreen,
                              isDark,
                              Icons.school_rounded,
                              'Ders Sayısı',
                              '5 ders',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              isSmallScreen,
                              isDark,
                              Icons.quiz_rounded,
                              'Test Sayısı',
                              '7+ test',
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    // Weekly Calendar
                    Text(
                      'Haftalık Plan',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    _buildWeeklyCalendar(isSmallScreen, isDark),
                  ],
                ),
              ),
            ),
            // Footer Actions
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : AppColors.backgroundBeige,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Kapat',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _saveExampleProgram();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Program kaydedildi! (Programım sekmesine eklendi)'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gradientTealStart,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 14 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Programı Kaydet',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSummaryItem(
    bool isSmallScreen,
    bool isDark,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 20 : 22,
          color: AppColors.primaryBlue,
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyCalendar(bool isSmallScreen, bool isDark) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    final weekDays = [
      {
        'name': 'Pazartesi',
        'short': 'Pzt',
        'dayNumber': weekStart.day,
        'month': weekStart.month,
        'tasks': [
          {'time': '09:00 - 10:00', 'subject': 'Vatandaşlık – Temel Haklar', 'type': 'konu', 'duration': '60 dk'},
          {'time': '10:15 - 10:35', 'subject': 'Vatandaşlık Test', 'type': 'test', 'duration': '20 soru'},
          {'time': '14:00 - 14:30', 'subject': 'Türkçe – Paragraf', 'type': 'test', 'duration': '30 dk'},
        ],
      },
      {
        'name': 'Salı',
        'short': 'Sal',
        'dayNumber': weekStart.add(const Duration(days: 1)).day,
        'month': weekStart.add(const Duration(days: 1)).month,
        'tasks': [
          {'time': '09:00 - 09:45', 'subject': 'Tarih – İÖ Türk Tarihi', 'type': 'konu', 'duration': '45 dk'},
          {'time': '10:00 - 10:20', 'subject': 'Tarih Test', 'type': 'test', 'duration': '15 soru'},
          {'time': '14:00 - 14:30', 'subject': 'Matematik – Problemler', 'type': 'test', 'duration': '30 dk'},
        ],
      },
      {
        'name': 'Çarşamba',
        'short': 'Çar',
        'dayNumber': weekStart.add(const Duration(days: 2)).day,
        'month': weekStart.add(const Duration(days: 2)).month,
        'tasks': [
          {'time': '09:00 - 09:45', 'subject': 'Coğrafya – Yer Şekilleri', 'type': 'video', 'duration': '45 dk'},
          {'time': '10:00 - 10:20', 'subject': 'Coğrafya Test', 'type': 'test', 'duration': '15 soru'},
          {'time': '14:00 - 14:15', 'subject': 'Vatandaşlık Tekrar', 'type': 'test', 'duration': '10 soru'},
        ],
      },
      {
        'name': 'Perşembe',
        'short': 'Per',
        'dayNumber': weekStart.add(const Duration(days: 3)).day,
        'month': weekStart.add(const Duration(days: 3)).month,
        'tasks': [
          {'time': '09:00 - 09:30', 'subject': 'Genel Tekrar', 'type': 'konu', 'duration': '30 dk'},
          {'time': '10:00 - 10:30', 'subject': 'Türkçe – Dil Bilgisi', 'type': 'test', 'duration': '30 dk'},
          {'time': '14:00 - 14:20', 'subject': 'Vatandaşlık – Haklar', 'type': 'konu', 'duration': '20 dk'},
        ],
      },
      {
        'name': 'Cuma',
        'short': 'Cum',
        'dayNumber': weekStart.add(const Duration(days: 4)).day,
        'month': weekStart.add(const Duration(days: 4)).month,
        'tasks': [
          {'time': '09:00 - 09:40', 'subject': 'Matematik – Problemler', 'type': 'konu', 'duration': '40 dk'},
          {'time': '10:00 - 10:30', 'subject': 'Tarih Karışık Test', 'type': 'test', 'duration': '25 soru'},
          {'time': '14:00 - 14:20', 'subject': 'Paragraf – Hız', 'type': 'test', 'duration': '20 dk'},
        ],
      },
      {
        'name': 'Cumartesi',
        'short': 'Cmt',
        'dayNumber': weekStart.add(const Duration(days: 5)).day,
        'month': weekStart.add(const Duration(days: 5)).month,
        'tasks': [
          {'time': '09:00 - 10:30', 'subject': 'Deneme – Genel Kültür', 'type': 'deneme', 'duration': '1 adet'},
          {'time': '11:00 - 11:40', 'subject': 'Deneme Analizi', 'type': 'analiz', 'duration': '40 dk'},
          {'time': '14:00 - 14:20', 'subject': 'Zayıf Konular', 'type': 'konu', 'duration': '20 dk'},
        ],
      },
      {
        'name': 'Pazar',
        'short': 'Paz',
        'dayNumber': weekStart.add(const Duration(days: 6)).day,
        'month': weekStart.add(const Duration(days: 6)).month,
        'tasks': [
          {'time': '09:00 - 09:45', 'subject': 'Hafif Tekrar', 'type': 'konu', 'duration': '45 dk'},
          {'time': '10:00 - 10:20', 'subject': 'Karışık Test', 'type': 'test', 'duration': '10-15 soru'},
          {'time': '14:00 - 14:10', 'subject': 'Hedef Belirleme', 'type': 'planlama', 'duration': '10 dk'},
        ],
      },
    ];

    final monthNames = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: weekDays.map((day) {
        final dayNumber = day['dayNumber'] as int;
        final month = day['month'] as int;
        final dayName = day['name'] as String;
        final dayShort = day['short'] as String;
        final tasks = day['tasks'] as List<Map<String, String>>;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.25),
              width: 1.5,
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
            children: [
              // Day Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 14 : 16,
                  vertical: isSmallScreen ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlue.withValues(alpha: 0.12),
                      AppColors.gradientTealStart.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 38 : 42,
                      height: isSmallScreen ? 38 : 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.gradientTealStart,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayShort,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9 : 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dayNumber ${monthNames[month]} 2026',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 10,
                        vertical: isSmallScreen ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gradientTealStart.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.gradientTealStart.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: isSmallScreen ? 12 : 14,
                            color: AppColors.gradientTealStart,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${tasks.length} görev',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gradientTealStart,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tasks Timeline
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                child: Column(
                  children: tasks.map((task) {
                    final time = task['time'] as String;
                    final subject = task['subject'] as String;
                    final type = task['type'] as String;
                    final duration = task['duration'] as String;
                    
                    return _buildTaskTimelineItem(
                      isSmallScreen,
                      isDark,
                      time,
                      subject,
                      type,
                      duration,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskTimelineItem(
    bool isSmallScreen,
    bool isDark,
    String time,
    String subject,
    String type,
    String duration,
  ) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'konu':
        icon = Icons.menu_book_rounded;
        color = AppColors.gradientOrangeStart;
        break;
      case 'test':
        icon = Icons.quiz_rounded;
        color = AppColors.gradientPurpleStart;
        break;
      case 'video':
        icon = Icons.play_circle_rounded;
        color = const Color(0xFFE74C3C);
        break;
      case 'deneme':
        icon = Icons.assignment_rounded;
        color = AppColors.primaryBlue;
        break;
      case 'analiz':
        icon = Icons.analytics_rounded;
        color = AppColors.gradientGreenStart;
        break;
      case 'planlama':
        icon = Icons.flag_rounded;
        color = AppColors.gradientTealStart;
        break;
      default:
        icon = Icons.circle;
        color = AppColors.primaryBlue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          Container(
            width: isSmallScreen ? 68 : 75,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 6 : 8,
              vertical: isSmallScreen ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              time.split(' - ')[0],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Icon
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: isSmallScreen ? 16 : 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: isSmallScreen ? 12 : 13,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: isDark ? Colors.white60 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        body: Column(
          children: [
            // Gradient Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: statusBarHeight + (isSmallScreen ? 12 : 16),
                left: isTablet ? 24 : 18,
                right: isTablet ? 24 : 18,
                bottom: isSmallScreen ? 20 : 24,
              ),
              decoration: BoxDecoration(
                gradient: isDark
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gradientPurpleStart,
                          AppColors.primaryBlue,
                        ],
                      ),
                color: isDark ? const Color(0xFF1E1E1E) : null,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : AppColors.gradientPurpleStart.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Watermark
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.1),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button and Title
                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: isSmallScreen ? 18 : 20,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 14 : 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: isSmallScreen ? 24 : 28,
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 10),
                                    Text(
                                      'AI ASİSTANI',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 22 : 26,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                Text(
                                  'Yapay zeka ile çalışma deneyiminizi geliştirin',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14.5,
                                    color: Colors.white.withValues(alpha: 0.95),
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 20 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    // Feature Cards
                    _buildFeatureCards(isSmallScreen, isDark),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    // Selection UI (if feature selected)
                    if (_selectedFeature.isNotEmpty) ...[
                      _buildSelectionUI(isSmallScreen, isDark, isTablet),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      // Generate Button
                      _buildGenerateButton(isSmallScreen, isDark),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      if (_generatedFeature != null && _generatedFeature != 'program')
                        _buildExampleOutput(isSmallScreen, isDark, isTablet),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCards(bool isSmallScreen, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final orientation = MediaQuery.of(context).orientation;

        // Tablet yatayda kartlar çok büyümesin: yüksekliği sabitle.
        final double mainAxisExtent = (orientation == Orientation.landscape && width >= 600)
            ? (isSmallScreen ? 145 : 155)
            : (isSmallScreen ? 150 : 165);
        // Kartların yatayda aşırı genişlemesini engelle: maxCrossAxisExtent ile otomatik kolon sayısı.
        // Böylece telefon landscape'de de kartlar "çok büyük" görünmez.
        final double maxCrossAxisExtent =
            (orientation == Orientation.landscape ? 230.0 : 280.0);

        final items = <Widget>[
          _buildFeatureCard(
            title: 'Soru Üret',
            subtitle: 'Eksik konular için soru oluştur',
            icon: Icons.quiz_rounded,
            gradient: [
              AppColors.gradientPurpleStart,
              AppColors.gradientPurpleEnd,
            ],
            isSmallScreen: isSmallScreen,
            isSelected: _selectedFeature == 'question',
            onTap: () => _handleFeatureTap('question'),
          ),
          _buildFeatureCard(
            title: 'Çalışma Metni',
            subtitle: 'PDF ve çalışma notu oluştur',
            icon: Icons.picture_as_pdf_rounded,
            gradient: [
              AppColors.gradientOrangeStart,
              AppColors.gradientOrangeEnd,
            ],
            isSmallScreen: isSmallScreen,
            isSelected: _selectedFeature == 'material',
            onTap: () => _handleFeatureTap('material'),
          ),
          _buildFeatureCard(
            title: 'Program Oluştur',
            subtitle: 'Kişiselleştirilmiş çalışma planı',
            icon: Icons.calendar_today_rounded,
            gradient: [
              AppColors.gradientTealStart,
              AppColors.gradientTealEnd,
            ],
            isSmallScreen: isSmallScreen,
            isSelected: _selectedFeature == 'program',
            onTap: () => _handleFeatureTap('program'),
          ),
          _buildFeatureCard(
            title: 'Eksiklik Analizi',
            subtitle: 'Eksik konuları tespit et',
            icon: Icons.analytics_rounded,
            gradient: [
              AppColors.primaryBlue,
              AppColors.primaryDarkBlue,
            ],
            isSmallScreen: isSmallScreen,
            isSelected: _selectedFeature == 'gap',
            onTap: () => _handleFeatureTap('gap'),
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            crossAxisSpacing: isSmallScreen ? 10 : 12,
            mainAxisSpacing: isSmallScreen ? 10 : 12,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) => items[index],
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required bool isSmallScreen,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.4),
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
              // Content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
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
                    // Title and subtitle
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildSelectionUI(bool isSmallScreen, bool isDark, bool isTablet) {
    // Program oluşturma için seçim gerekmez
    if (_selectedFeature == 'program') {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Program Oluşturma',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'AI, çalışma geçmişinize ve eksikliklerinize göre size özel bir çalışma programı oluşturacak.',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Soru üretimi ve çalışma metni için konu seçimi gerekli
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lesson Selection
        Text(
          'Ders Seçin',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        _isLoadingLessons
            ? const Center(child: CircularProgressIndicator())
            : _lessons.isEmpty
                ? Center(
                    child: Text(
                      'Henüz ders eklenmemiş',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  )
                : SizedBox(
                    height: isSmallScreen ? 50 : 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = _lessons[index];
                        final isSelected = _selectedLesson?.id == lesson.id;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < _lessons.length - 1 ? 8 : 0,
                          ),
                          child: GestureDetector(
                            onTap: () => _handleLessonSelect(lesson),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 20,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primaryBlue,
                                          AppColors.primaryDarkBlue,
                                        ],
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.3)),
                                  width: isSelected ? 0 : 1.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  lesson.name,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 15,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : AppColors.textPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        // Topic Selection (if lesson selected)
        if (_selectedLesson != null) ...[
          SizedBox(height: isSmallScreen ? 16 : 20),
          Text(
            'Konu Seçin',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          _topics.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Konu yükleniyor...',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _topics.map((topic) {
                    final isSelected = _selectedTopic?.id == topic.id;
                    return GestureDetector(
                      onTap: () => _handleTopicSelect(topic),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 14 : 16,
                          vertical: isSmallScreen ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    AppColors.gradientPurpleStart,
                                    AppColors.gradientPurpleEnd,
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.3)),
                            width: isSelected ? 0 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.gradientPurpleStart.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          topic.name,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : AppColors.textPrimary),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ],
    );
  }

  Widget _buildGenerateButton(bool isSmallScreen, bool isDark) {
    final canGenerate = _selectedFeature == 'program' ||
        (_selectedFeature == 'question' && _selectedTopic != null) ||
        (_selectedFeature == 'material' && _selectedTopic != null) ||
        (_selectedFeature == 'gap' && _selectedLesson != null);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canGenerate ? _startGeneration : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canGenerate ? AppColors.primaryBlue : Colors.grey,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 16 : 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canGenerate ? 8 : 0,
          shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Text(
              _selectedFeature == 'question'
                  ? 'Örnek Soruları Göster'
                  : _selectedFeature == 'material'
                      ? 'Örnek Çalışma Metnini Göster'
                      : _selectedFeature == 'program'
                          ? 'Örnek Programı Göster'
                          : 'Örnek Eksiklik Analizini Göster',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleOutput(bool isSmallScreen, bool isDark, bool isTablet) {
    final lessonName = _selectedLesson?.name ?? 'Vatandaşlık';
    final topicName = _selectedTopic?.name ?? 'Temel Hak ve Hürriyetler';

    Widget content;
    String title;
    String description;
    IconData icon;
    Color accent;

    switch (_generatedFeature) {
      case 'question':
        title = 'Örnek Soru Üretimi Çıktısı';
        description =
            'Gemini bu bölümde seçtiğiniz konuya uygun, KPSS formatında çoktan seçmeli sorular üretir.';
        icon = Icons.quiz_rounded;
        accent = AppColors.gradientPurpleStart;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTagRow(
              isSmallScreen,
              isDark,
              lessonName,
              topicName,
              'KPSS Tarzı Test',
              accent,
            ),
            const SizedBox(height: 14),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              'Örnek Soru',
            ),
            const SizedBox(height: 4),
            Text(
              'Aşağıdakilerden hangisi temel hak ve hürriyetlerin ortak özelliklerinden biri değildir?',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildOptionRow(isSmallScreen, isDark, 'A', 'Devredilemez olmaları'),
            _buildOptionRow(isSmallScreen, isDark, 'B', 'Dokunulamaz olmaları'),
            _buildOptionRow(isSmallScreen, isDark, 'C', 'Vazgeçilemez olmaları'),
            _buildOptionRow(
              isSmallScreen,
              isDark,
              'D',
              'Sadece olağanüstü hâllerde kısıtlanabilmeleri',
              isCorrect: true,
            ),
            _buildOptionRow(isSmallScreen, isDark, 'E', 'Anayasa ile güvence altına alınmış olmaları'),
            const SizedBox(height: 10),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              'Çözüm ve Açıklama',
            ),
            const SizedBox(height: 4),
            Text(
              'Temel hak ve hürriyetler olağan dönemlerde de kanunla sınırlandırılabilir. '
              'Bu nedenle sadece olağanüstü hâllerde kısıtlanabilmeleri ifadesi yanlıştır. '
              'Diğer şıklar temel hakların ortak özelliklerini doğru biçimde yansıtır.',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.5,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        );
        break;
      case 'material':
        title = 'Örnek Çalışma Metni Çıktısı';
        description =
            'Gemini, eksik olduğunuz başlıklar için odaklı, özet ve KPSS tarzına uygun konu anlatımı üretir.';
        icon = Icons.picture_as_pdf_rounded;
        accent = AppColors.gradientOrangeStart;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPdfHeader(isSmallScreen, isDark, topicName, lessonName),
            const SizedBox(height: 12),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              '1. Temel Hak ve Hürriyet Kavramı',
            ),
            const SizedBox(height: 4),
            Text(
              'Temel hak ve hürriyetler, bireyin sadece insan olması sebebiyle doğuştan sahip olduğu, '
              'devlet tarafından tanınan ve güvence altına alınan hak ve özgürlüklerdir.',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.5,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              '2. Temel Hakların Ortak Özellikleri',
            ),
            const SizedBox(height: 4),
            _buildBullet(
              isSmallScreen,
              isDark,
              'Devredilemez: Başkasına bırakılmaz, satılamaz.',
            ),
            _buildBullet(
              isSmallScreen,
              isDark,
              'Vazgeçilemez: Kişi kendi isteğiyle bile bu haklardan tamamen vazgeçemez.',
            ),
            _buildBullet(
              isSmallScreen,
              isDark,
              'Dokunulamaz: Devlet keyfi şekilde bu haklara müdahale edemez.',
            ),
            const SizedBox(height: 10),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              '3. Sınırlandırma İlkesi',
            ),
            const SizedBox(height: 4),
            Text(
              'Temel hak ve hürriyetler, Anayasa\'nın ilgili maddelerinde belirtilen sebeplerle ve '
              'yalnızca kanunla sınırlanabilir. Ölçülülük ve demokratik toplum düzeninin gerekleri, '
              'yapılan sınırlamanın meşru ve orantılı olmasını zorunlu kılar.',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.5,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        );
        break;
      case 'program':
        // Program için modal açılıyor, burada örnek göstermiyoruz
        title = '';
        description = '';
        icon = Icons.calendar_today_rounded;
        accent = AppColors.gradientTealStart;
        content = const SizedBox.shrink();
        break;
      case 'gap':
        title = 'Örnek Eksiklik Analizi Çıktısı';
        description =
            'Gemini, test sonuçlarınız ve ilerlemenize göre hangi konularda zorlandığınızı özetler.';
        icon = Icons.analytics_rounded;
        accent = AppColors.primaryBlue;
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTagRow(
              isSmallScreen,
              isDark,
              lessonName,
              topicName,
              'Zayıf Alanlar',
              accent,
            ),
            const SizedBox(height: 14),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              '1) Derin Eksik Alan',
            ),
            const SizedBox(height: 4),
            Text(
              '$topicName\n'
              '• Son 3 testte ortalama başarı: %42\n'
              '• Yanlışlar çoğunlukla: hakların sınırlandırılması, OHAL rejimi\n'
              '• Öneri: 20 dk konu özeti + 15 dk karışık test + 10 dk yanlış soru analizi',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.5,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _buildSectionHeader(
              isSmallScreen,
              isDark,
              '2) Diğer Zayıf Başlıklar',
            ),
            const SizedBox(height: 4),
            Text(
              '• İdare Hukuku – İdari İşlemler (%48)\n'
              '• Uluslararası Kuruluşlar (%51)',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.5,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        );
        break;
      default:
        title = 'Örnek Çıktı';
        description = '';
        icon = Icons.auto_awesome_rounded;
        accent = AppColors.primaryBlue;
        content = const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : accent.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: accent,
                  size: isSmallScreen ? 18 : 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          content,
          if ((_generatedFeature == 'question' || _generatedFeature == 'material') && _selectedTopic != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generatedFeature == 'question'
                    ? _saveExampleQuestionsToTopic
                    : _saveExampleMaterialToTopic,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _generatedFeature == 'question'
                      ? AppColors.gradientPurpleStart
                      : AppColors.gradientOrangeStart,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  _generatedFeature == 'question' ? 'Soruları Konuya Kaydet' : 'Metni Konuya Kaydet',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Not: Kaydedilen içerikler ilgili konu ekranında (Konu Detay) görünecek.',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagRow(
    bool isSmallScreen,
    bool isDark,
    String primary,
    String secondary,
    String badge,
    Color accent,
  ) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTagChip(isSmallScreen, isDark, primary),
              _buildTagChip(isSmallScreen, isDark, secondary),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10 : 12,
            vertical: isSmallScreen ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(bool isSmallScreen, bool isDark, String text) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 10,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : AppColors.backgroundBeige,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isSmallScreen ? 11 : 12,
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(bool isSmallScreen, bool isDark, String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: isSmallScreen ? 14 : 16,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow(
    bool isSmallScreen,
    bool isDark,
    String key,
    String text, {
    bool isCorrect = false,
  }) {
    final baseColor = isCorrect ? AppColors.gradientGreenStart : (isDark ? Colors.white70 : AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isCorrect ? AppColors.gradientGreenStart : baseColor.withValues(alpha: 0.7),
                width: 1.5,
              ),
              color: isCorrect ? AppColors.gradientGreenStart.withValues(alpha: 0.12) : Colors.transparent,
            ),
            child: Center(
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: baseColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.4,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(bool isSmallScreen, bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                height: 1.4,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfHeader(
    bool isSmallScreen,
    bool isDark,
    String topicName,
    String lessonName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'KPSS KONU ÖZETİ',
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.textLight,
              ),
            ),
            const Spacer(),
            Text(
              'Örnek PDF Görünümü',
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          topicName,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          lessonName,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryBlue.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

}
