import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_test.dart';
import 'ongoing_test_card.dart';
import '../pages/ongoing_tests_list_page.dart';

class OngoingTestsSection extends StatelessWidget {
  final List<OngoingTest> tests;
  final bool isSmallScreen;
  final double availableHeight;

  const OngoingTestsSection({
    super.key,
    required this.tests,
    this.isSmallScreen = false,
    this.availableHeight = 130.0,
  });

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final cardHeight = isSmallScreen ? 105.0 : 115.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24.0 : 16.0,
            vertical: isSmallScreen ? 4.0 : 6.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OngoingTestsListPage(
                        tests: tests,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.quiz_outlined,
                        size: isSmallScreen ? 16.0 : 18.0,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        final textColor = isDark ? Colors.white : AppColors.textPrimary;
                        
                        return Text(
                          'Devam Eden Testler',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14.0 : 18.0,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OngoingTestsListPage(
                        tests: tests,
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8.0 : 12.0,
                    vertical: isSmallScreen ? 4.0 : 8.0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Hepsi',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11.0 : 13.0,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24.0 : 16.0,
            ),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < tests.length - 1 ? (isSmallScreen ? 10.0 : 12.0) : 0,
                ),
                child: OngoingTestCard(
                  test: tests[index],
                  isSmallScreen: isSmallScreen,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
