import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/topic.dart';
import 'topic_detail_page.dart';

class LessonDetailPage extends StatelessWidget {
  final Lesson lesson;

  const LessonDetailPage({
    super.key,
    required this.lesson,
  });

  IconData _getIcon() {
    switch (lesson.icon) {
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

  List<Topic> _getTopicsForLesson() {
    // Mock data - will be replaced with real data later
    switch (lesson.id) {
      case '1': // Türkçe
        return [
          Topic(
            id: '1',
            lessonId: lesson.id,
            name: 'Sözcükte Anlam',
            subtitle: 'Sözcüklerin farklı anlamları ve kullanımları',
            duration: '2h 30min',
            averageQuestionCount: 8,
            testCount: 12,
            podcastCount: 5,
            videoCount: 8,
            noteCount: 15,
            progress: 0.3,
          ),
          Topic(
            id: '2',
            lessonId: lesson.id,
            name: 'Cümlede Anlam',
            subtitle: 'Cümle yapısı ve anlam ilişkileri',
            duration: '3h 15min',
            averageQuestionCount: 10,
            testCount: 15,
            podcastCount: 6,
            videoCount: 10,
            noteCount: 18,
            progress: 0.5,
          ),
          Topic(
            id: '3',
            lessonId: lesson.id,
            name: 'Paragraf',
            subtitle: 'Paragraf yapısı ve anlam bütünlüğü',
            duration: '2h 45min',
            averageQuestionCount: 12,
            testCount: 18,
            podcastCount: 8,
            videoCount: 12,
            noteCount: 20,
            progress: 0.2,
          ),
          Topic(
            id: '4',
            lessonId: lesson.id,
            name: 'Dil Bilgisi',
            subtitle: 'Temel dil bilgisi kuralları',
            duration: '4h 20min',
            averageQuestionCount: 15,
            testCount: 20,
            podcastCount: 10,
            videoCount: 15,
            noteCount: 25,
            progress: 0.7,
          ),
        ];
      case '2': // Matematik
        return [
          Topic(
            id: '5',
            lessonId: lesson.id,
            name: 'Rasyonel Sayılar',
            subtitle: 'Rasyonel sayılar ve işlemler',
            duration: '3h 10min',
            averageQuestionCount: 10,
            testCount: 15,
            podcastCount: 6,
            videoCount: 10,
            noteCount: 18,
            progress: 0.4,
          ),
          Topic(
            id: '6',
            lessonId: lesson.id,
            name: 'Üslü Sayılar',
            subtitle: 'Üslü sayılar ve özellikleri',
            duration: '2h 50min',
            averageQuestionCount: 8,
            testCount: 12,
            podcastCount: 5,
            videoCount: 8,
            noteCount: 15,
            progress: 0.6,
          ),
          Topic(
            id: '7',
            lessonId: lesson.id,
            name: 'Köklü Sayılar',
            subtitle: 'Köklü sayılar ve işlemler',
            duration: '3h 30min',
            averageQuestionCount: 9,
            testCount: 14,
            podcastCount: 6,
            videoCount: 9,
            noteCount: 16,
            progress: 0.3,
          ),
        ];
      default:
        return [
          Topic(
            id: '1',
            lessonId: lesson.id,
            name: 'Örnek Konu 1',
            subtitle: 'Örnek konu açıklaması',
            duration: '2h 30min',
            averageQuestionCount: 8,
            testCount: 10,
            podcastCount: 5,
            videoCount: 8,
            noteCount: 12,
            progress: 0.0,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final topics = _getTopicsForLesson();
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Column(
        children: [
          // Blue Header Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + (isSmallScreen ? 12 : 16),
              left: isTablet ? 24 : 18,
              right: isTablet ? 24 : 18,
              bottom: isSmallScreen ? 20 : 24,
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
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
                      'KPSS',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.1),
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: MediaQuery.of(context).padding.top + (isSmallScreen ? 8 : 12),
                  left: 0,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                // Content
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: isSmallScreen ? 60 : 70,
                      height: isSmallScreen ? 60 : 70,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLightBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getIcon(),
                        size: isSmallScreen ? 32 : 36,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 16 : 20),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            lesson.description,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          Text(
                            '${topics.length} KONU',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
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
          // Topics List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 18,
                vertical: isSmallScreen ? 12 : 16,
              ),
              itemCount: topics.length,
              itemBuilder: (context, index) {
                final topic = topics[index];
                final topicNumber = (index + 1).toString().padLeft(2, '0');
                
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TopicDetailPage(
                          topic: topic,
                          lessonName: lesson.name,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14 : 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Number
                        Container(
                          width: isSmallScreen ? 40 : 44,
                          alignment: Alignment.topLeft,
                          child: Text(
                            topicNumber,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 16),
                        // Title and subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topic.name,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 4 : 6),
                              Text(
                                topic.subtitle,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
