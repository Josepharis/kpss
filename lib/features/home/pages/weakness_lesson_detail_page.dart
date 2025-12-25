import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import 'weakness_topic_detail_page.dart';

class WeaknessLessonDetailPage extends StatefulWidget {
  final Lesson lesson;

  const WeaknessLessonDetailPage({
    super.key,
    required this.lesson,
  });

  @override
  State<WeaknessLessonDetailPage> createState() => _WeaknessLessonDetailPageState();
}

class _WeaknessLessonDetailPageState extends State<WeaknessLessonDetailPage> {
  Map<String, List<WeaknessQuestion>> _groupedByTopic = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeaknesses();
  }

  Future<void> _loadWeaknesses() async {
    setState(() {
      _isLoading = true;
    });

    final weaknesses = await WeaknessesService.getWeaknessesByLesson(widget.lesson.id);
    final Map<String, List<WeaknessQuestion>> grouped = {};

    for (var weakness in weaknesses) {
      if (!grouped.containsKey(weakness.topicName)) {
        grouped[weakness.topicName] = [];
      }
      grouped[weakness.topicName]!.add(weakness);
    }

    if (mounted) {
      setState(() {
        _groupedByTopic = grouped;
        _isLoading = false;
      });
    }
  }

  Color _getColor() {
    switch (widget.lesson.color) {
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final topics = _groupedByTopic.keys.toList();
    final totalWeaknesses = _groupedByTopic.values.fold<int>(0, (sum, list) => sum + list.length);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header (Kompakt)
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + (isSmallScreen ? 4 : 6),
              bottom: isSmallScreen ? 8 : 10,
              left: isTablet ? 16 : 12,
              right: isTablet ? 16 : 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getColor(),
                  _getColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: isSmallScreen ? 18 : 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.lesson.name,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalWeaknesses eksik soru • ${topics.length} konu',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loadWeaknesses,
                  tooltip: 'Yenile',
                ),
              ],
            ),
          ),
          // Topics List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  )
                : topics.isEmpty
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
                              'Bu derste eksik soru yok',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadWeaknesses,
                        color: AppColors.primaryBlue,
                        child: ListView.builder(
                          padding: EdgeInsets.all(isTablet ? 20 : 16),
                          itemCount: topics.length,
                          itemBuilder: (context, index) {
                            final topicName = topics[index];
                            final weaknesses = _groupedByTopic[topicName]!;
                            final weaknessCount = weaknesses.length;

                            return Container(
                              margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WeaknessTopicDetailPage(
                                          lesson: widget.lesson,
                                          topicName: topicName,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                topicName,
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 16 : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.error_outline_rounded,
                                                          size: isSmallScreen ? 14 : 16,
                                                          color: Colors.red,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$weaknessCount soru',
                                                          style: TextStyle(
                                                            fontSize: isSmallScreen ? 12 : 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.red,
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
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: isSmallScreen ? 18 : 20,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

