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

  Widget _buildMiniBadge({
    required bool isDark,
    required IconData icon,
    required String text,
    Color? accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (accentColor ?? (isDark ? Colors.white12 : AppColors.backgroundBeige))
            .withValues(alpha: accentColor != null ? 0.2 : (isDark ? 0.5 : 1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: accentColor ?? (isDark ? Colors.white54 : AppColors.textSecondary)),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final topics = _groupedByTopic.keys.toList();
    final totalWeaknesses = _groupedByTopic.values.fold<int>(0, (sum, list) => sum + list.length);
    final color = _getColor();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Premium header - Kaydedilenler ekranıyla uyumlu
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.85),
                    color.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(isTablet ? 16 : 12, topPadding + 8, isTablet ? 16 : 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.arrow_back_ios_new_rounded, size: isSmallScreen ? 18 : 20, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lesson.name,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 20 : 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$totalWeaknesses eksik soru • ${topics.length} konu',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _loadWeaknesses,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(Icons.refresh_rounded, size: isSmallScreen ? 20 : 22, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Topics List - Kaydedilenler'deki ders kartları stili
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: isDark ? const Color(0xFF3B82F6) : AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Yükleniyor...',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : topics.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white10 : Colors.red.withValues(alpha: 0.08)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.quiz_outlined,
                                    size: 44,
                                    color: isDark ? Colors.white38 : Colors.red.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bu derste eksik soru yok',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Yanlış yaptığınız veya kaydettiğiniz sorular burada listelenir.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadWeaknesses,
                          color: AppColors.primaryBlue,
                          backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(isTablet ? 20 : 16, 12, isTablet ? 20 : 16, 16),
                            itemCount: topics.length,
                            itemBuilder: (context, index) {
                              final topicName = topics[index];
                              final weaknesses = _groupedByTopic[topicName]!;
                              final weaknessCount = weaknesses.length;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
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
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [color, color.withValues(alpha: 0.8)],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.35),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Icon(Icons.folder_rounded, color: Colors.white, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  topicName,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                _buildMiniBadge(
                                                  isDark: isDark,
                                                  icon: Icons.quiz_rounded,
                                                  text: '$weaknessCount soru',
                                                  accentColor: const Color(0xFFEF4444),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 12,
                                            color: isDark ? Colors.white38 : AppColors.textLight,
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
      ),
    );
  }
}

