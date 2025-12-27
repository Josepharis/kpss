import 'package:flutter/material.dart';
import '../../../../main.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic.dart';
import 'tests_page.dart';
import 'podcasts_page.dart';
import 'flash_cards_page.dart';
import 'notes_page.dart';
import 'past_questions_page.dart';
import 'topic_pdf_viewer_page.dart';
import 'videos_page.dart';
import 'topic_explanations_list_page.dart';
import 'tests_list_page.dart';

class TopicDetailPage extends StatelessWidget {
  final Topic topic;
  final String lessonName;

  const TopicDetailPage({
    super.key,
    required this.topic,
    required this.lessonName,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 70 : 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryDarkBlue,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.3),
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
                              topic.name,
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
      body: Column(
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
                      // Konu Anlatımı
                      _buildPremiumCard(
                        context: context,
                        title: 'Konu Anlatımı',
                        count: topic.pdfUrl != null && topic.pdfUrl!.isNotEmpty ? 1 : 0,
                        icon: Icons.picture_as_pdf_rounded,
                        color: const Color(0xFFFF9800),
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          // Şimdilik tek PDF varsa direkt aç, birden fazla olursa liste göster
                          // Gelecekte birden fazla PDF olabilir, o zaman liste ekranına yönlendir
                          final explanations = <Map<String, String>>[];
                          if (topic.pdfUrl != null && topic.pdfUrl!.isNotEmpty) {
                            explanations.add({
                              'name': 'Konu Anlatımı',
                              'pdfUrl': topic.pdfUrl!,
                            });
                          }
                          
                          if (explanations.length > 1) {
                            // Birden fazla içerik varsa liste ekranına git
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TopicExplanationsListPage(
                                  topic: topic,
                                  lessonName: lessonName,
                                  explanations: explanations,
                                ),
                              ),
                            );
                          } else if (explanations.isNotEmpty) {
                            // Tek içerik varsa direkt aç
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TopicPdfViewerPage(
                                  topic: topic,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Bu konu için PDF dosyası bulunamadı.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                      // Çıkmış Sorular / Soru Dağılımı
                      _buildPremiumCard(
                        context: context,
                        title: 'Çıkmış Sorular',
                        subtitle: 'Soru Dağılımı',
                        count: topic.averageQuestionCount,
                        icon: Icons.analytics_rounded,
                        color: const Color(0xFFFF6B35),
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PastQuestionsPage(
                                topicName: topic.name,
                                averageQuestionCount: topic.averageQuestionCount,
                              ),
                            ),
                          );
                        },
                      ),
                      // Testler
                      _buildPremiumCard(
                        context: context,
                        title: 'Testler',
                        count: topic.testCount,
                        icon: Icons.quiz_rounded,
                        color: AppColors.primaryBlue,
                        isSmallScreen: isSmallScreen,
                        onTap: () async {
                          // Eğer birden fazla test varsa liste ekranına git
                          if (topic.testCount > 1) {
                            // Testleri oluştur (şimdilik testCount kadar test oluştur)
                            final tests = <Map<String, dynamic>>[];
                            for (int i = 1; i <= topic.testCount; i++) {
                              tests.add({
                                'name': 'Test $i',
                                'questionCount': 10, // Varsayılan soru sayısı, gerçekte servisten alınabilir
                              });
                            }
                            
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TestsListPage(
                                  topicName: topic.name,
                                  lessonId: topic.lessonId,
                                  topicId: topic.id,
                                  testCount: topic.testCount,
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
                                topicName: topic.name,
                                testCount: topic.testCount,
                                lessonId: topic.lessonId,
                                topicId: topic.id,
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
                      // Podcastler
                      _buildPremiumCard(
                        context: context,
                        title: 'Podcastler',
                        count: topic.podcastCount,
                        icon: Icons.podcasts_rounded,
                        color: AppColors.gradientPurpleStart,
                        isSmallScreen: isSmallScreen,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PodcastsPage(
                                topicName: topic.name,
                                podcastCount: topic.podcastCount,
                                topicId: topic.id,
                                lessonId: topic.lessonId,
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
                      // Videolar
                      _buildPremiumCard(
                        context: context,
                        title: 'Videolar',
                        count: topic.videoCount,
                        icon: Icons.video_library_rounded,
                        color: const Color(0xFFE74C3C),
                        isSmallScreen: isSmallScreen,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideosPage(
                                topicName: topic.name,
                                videoCount: topic.videoCount,
                                topicId: topic.id,
                                lessonId: topic.lessonId,
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
                      // Bilgi Kartları
                      _buildPremiumCard(
                        context: context,
                        title: 'Bilgi Kartları',
                        count: topic.videoCount,
                        icon: Icons.style_rounded,
                        color: AppColors.gradientRedStart,
                        isSmallScreen: isSmallScreen,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashCardsPage(
                                topicName: topic.name,
                                cardCount: topic.videoCount,
                                topicId: topic.id,
                                lessonId: topic.lessonId,
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
                        count: topic.noteCount,
                        icon: Icons.note_rounded,
                        color: AppColors.gradientGreenStart,
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotesPage(
                                topicName: topic.name,
                                noteCount: topic.noteCount,
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

}
