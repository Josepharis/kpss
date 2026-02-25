import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'tests_page.dart';

class TestsListPage extends StatelessWidget {
  final String topicName;
  final String lessonId;
  final String topicId;
  final int testCount;
  final List<Map<String, dynamic>>
  tests; // [{name: "Test 1", questionCount: 10}, ...]

  const TestsListPage({
    super.key,
    required this.topicName,
    required this.lessonId,
    required this.topicId,
    required this.testCount,
    required this.tests,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 70 : 80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, AppColors.primaryDarkBlue],
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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isSmallScreen ? 6 : 8,
              ),
              child: Row(
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Testler',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          topicName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
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
          ),
        ),
      ),
      body: tests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz test eklenmemiş',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 14),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final test = tests[index];
                final testName = test['name'] as String? ?? 'Test ${index + 1}';
                final questionCount = test['questionCount'] as int? ?? 0;

                return Container(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TestsPage(
                              topicName: '$topicName - $testName',
                              testCount: questionCount,
                              lessonId: lessonId,
                              topicId: topicId,
                              testFileName: test['fileName'] as String?,
                            ),
                          ),
                        );
                        // If test page returned true, refresh home page
                        if (result == true && context.mounted) {
                          Navigator.of(context).pop(result);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                        child: Row(
                          children: [
                            Container(
                              width: isSmallScreen ? 48 : 52,
                              height: isSmallScreen ? 48 : 52,
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
                              ),
                              child: Icon(
                                Icons.quiz_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 24 : 26,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 12 : 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    testName,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 15 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '$questionCount soru',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey.shade400,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
