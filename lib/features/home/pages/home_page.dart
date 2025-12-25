import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/daily_summary.dart';
import '../../../core/models/ongoing_test.dart';
import '../../../core/models/ongoing_podcast.dart';
import '../widgets/motivational_quote.dart';
import '../widgets/daily_summary_card.dart';
import '../widgets/ongoing_tests_section.dart';
import '../widgets/ongoing_podcasts_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Mock data - will be replaced with real data later
  final List<String> motivationalQuotes = [
    'Başarı, hazırlık ve fırsatın buluştuğu noktadır.',
    'Bugün yaptığın çalışma, yarının başarısını belirler.',
    'Her soru, seni hedefine bir adım daha yaklaştırır.',
    'Azim ve sabır, başarının anahtarıdır.',
    'Çalışmak, hayallerini gerçeğe dönüştüren tek yoldur.',
  ];

  String get currentQuote {
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    return motivationalQuotes[dayOfYear % motivationalQuotes.length];
  }

  DailySummary get dailySummary {
    return DailySummary(
      solvedQuestions: 45,
      studyTimeMinutes: 180,
      lessonCount: 3,
      successRate: 78.5,
    );
  }

  List<OngoingTest> get ongoingTests {
    return [
      OngoingTest(
        id: '1',
        title: 'Matematik Testi',
        topic: 'Rasyonel Sayılar',
        currentQuestion: 2,
        totalQuestions: 5,
        progressColor: 'blue',
        icon: 'atom',
      ),
      OngoingTest(
        id: '2',
        title: 'Türkçe Testi',
        topic: 'Sözcükte Anlam',
        currentQuestion: 1,
        totalQuestions: 6,
        progressColor: 'yellow',
        icon: 'chart',
      ),
      OngoingTest(
        id: '3',
        title: 'Tarih Testi',
        topic: 'Osmanlı Tarihi',
        currentQuestion: 5,
        totalQuestions: 6,
        progressColor: 'red',
        icon: 'globe',
      ),
      OngoingTest(
        id: '4',
        title: 'Coğrafya Testi',
        topic: 'Türkiye Fiziki Coğrafyası',
        currentQuestion: 2,
        totalQuestions: 8,
        progressColor: 'purple',
        icon: 'megaphone',
      ),
    ];
  }

  List<OngoingPodcast> get ongoingPodcasts {
    return [
      OngoingPodcast(
        id: '1',
        title: 'KPSS Hazırlık',
        currentMinute: 15,
        totalMinutes: 45,
        progressColor: 'blue',
        icon: 'atom',
      ),
      OngoingPodcast(
        id: '2',
        title: 'AGS Stratejileri',
        currentMinute: 8,
        totalMinutes: 30,
        progressColor: 'yellow',
        icon: 'chart',
      ),
      OngoingPodcast(
        id: '3',
        title: 'Motivasyon',
        currentMinute: 20,
        totalMinutes: 25,
        progressColor: 'red',
        icon: 'megaphone',
      ),
    ];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Günaydın';
    } else if (hour < 18) {
      return 'İyi günler';
    } else {
      return 'İyi akşamlar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    
    // Responsive font sizes
    final greetingFontSize = isSmallScreen ? 12.0 : 14.0;
    final titleFontSize = isSmallScreen ? 16.0 : 20.0;
    final iconSize = isSmallScreen ? 18.0 : 22.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.primaryBlue,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            // Custom AppBar with Status Bar
            Container(
              padding: EdgeInsets.only(
                top: statusBarHeight,
                bottom: isSmallScreen ? 8.0 : 12.0,
                left: isTablet ? 24.0 : 16.0,
                right: isTablet ? 24.0 : 16.0,
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
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: greetingFontSize,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'KPSS & AGS 2026',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ],
              ),
            ),
            // Content - Fits in single screen
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Motivational Quote
                            MotivationalQuote(
                              quote: currentQuote,
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 4.0 : 6.0),
                            // Daily Summary Card
                            DailySummaryCard(
                              summary: dailySummary,
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Ongoing Tests Section
                            Flexible(
                              child: OngoingTestsSection(
                                tests: ongoingTests,
                                isSmallScreen: isSmallScreen,
                                availableHeight: constraints.maxHeight * 0.35,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                            // Ongoing Podcasts Section
                            Flexible(
                              child: OngoingPodcastsSection(
                                podcasts: ongoingPodcasts,
                                isSmallScreen: isSmallScreen,
                                availableHeight: constraints.maxHeight * 0.35,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
