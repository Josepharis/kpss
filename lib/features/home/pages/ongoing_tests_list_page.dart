import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_test.dart';
import '../../../core/services/progress_service.dart';
import '../../../../main.dart';
import 'tests_page.dart';

class OngoingTestsListPage extends StatefulWidget {
  final List<OngoingTest> tests;

  const OngoingTestsListPage({
    super.key,
    required this.tests,
  });

  @override
  State<OngoingTestsListPage> createState() => _OngoingTestsListPageState();
}

class _OngoingTestsListPageState extends State<OngoingTestsListPage> {
  final ProgressService _progressService = ProgressService();
  late List<OngoingTest> _tests;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _tests = List<OngoingTest>.from(widget.tests);
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_tests.map((t) => t.toMap()).toList());
      await prefs.setString('ongoing_tests_cache', jsonStr);
    } catch (_) {
      // silent
    }
  }

  Future<bool> _confirmReset(OngoingTest test) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test ilerlemesi sıfırlansın mı?'),
        content: Text('"${test.topic}" testindeki kaldığın yer silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _resetTest(OngoingTest test) async {
    final confirmed = await _confirmReset(test);
    if (!confirmed) return;

    await _progressService.deleteTestProgress(test.topicId);
    if (!mounted) return;

    setState(() {
      _tests.removeWhere((t) => t.topicId == test.topicId);
      _didChange = true;
    });
    await _saveToCache();

    if (!mounted) return;
    MainScreen.of(context)?.refreshHomePage();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test ilerlemesi sıfırlandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(_didChange),
        ),
        title: Text(
          'Devam Eden Testler',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _tests.isEmpty
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
                    'Devam eden test bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              itemCount: _tests.length,
              itemBuilder: (context, index) {
                final test = _tests[index];
                return Card(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TestsPage(
                            topicName: test.topic,
                            testCount: test.totalQuestions,
                            lessonId: test.lessonId,
                            topicId: test.topicId,
                          ),
                        ),
                      );
                      if (!context.mounted) return;
                      // If test page returned true, refresh home page
                      if (result == true) {
                        MainScreen.of(context)?.refreshHomePage();
                      }
                    },
                    contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    leading: Container(
                      width: isSmallScreen ? 50 : 60,
                      height: isSmallScreen ? 50 : 60,
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
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    title: Text(
                      test.topic,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${test.currentQuestion}/${test.totalQuestions} soru',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sıfırla',
                          onPressed: () => _resetTest(test),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: isSmallScreen ? 20 : 22,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

