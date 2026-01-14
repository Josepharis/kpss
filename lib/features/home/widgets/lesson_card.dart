import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/questions_service.dart';

class LessonCard extends StatefulWidget {
  final Lesson lesson;
  final double progress;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const LessonCard({
    super.key,
    required this.lesson,
    required this.progress,
    this.isSmallScreen = false,
    required this.onTap,
  });

  @override
  State<LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<LessonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  final LessonsService _lessonsService = LessonsService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _elevationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  IconData _getIcon() {
    switch (widget.lesson.icon) {
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

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final progressPercentage = (widget.progress * 100).toInt();

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Future.delayed(const Duration(milliseconds: 100), widget.onTap);
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.25 + (0.15 * _elevationAnimation.value)),
                    blurRadius: 12 + (8 * _elevationAnimation.value),
                    offset: Offset(0, 4 + (4 * _elevationAnimation.value)),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                        color,
                        color.withOpacity(0.85),
                        color.withOpacity(0.75),
                            ],
                      stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                  child: Stack(
                    children: [
                      // Decorative Elements
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                          width: 70,
                          height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -15,
                      left: -15,
                      child: Container(
                          width: 50,
                          height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                      ),
                      // Shine Effect
                      Positioned.fill(
                        child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                                Colors.transparent,
                                Colors.black.withOpacity(0.05),
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Icon Section
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                    offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getIcon(),
                                size: 22,
                              color: Colors.white,
                                ),
                            ),
                            // Text and Info Section
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.lesson.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                    letterSpacing: -0.3,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black26,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                                const SizedBox(height: 8),
                                // Progress Bar
                              Container(
                                  height: 4,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: widget.progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Colors.white.withOpacity(0.9),
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                            color: Colors.white.withOpacity(0.5),
                                      blurRadius: 4,
                                            spreadRadius: 0.5,
                                    ),
                                  ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Progress Percentage
                                Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 10,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$progressPercentage%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                        ),
                                    ),
                                    const SizedBox(width: 6),
                                    FutureBuilder<int>(
                                      future: _lessonsService.getTopicsByLessonId(widget.lesson.id).then((topics) async {
                                        // Cache'den soru sayılarını çek (çok hızlı)
                                        final prefs = await SharedPreferences.getInstance();
                                        int totalQuestions = 0;
                                        
                                        // Önce cache'den tüm topic'lerin soru sayılarını kontrol et
                                        for (var topic in topics) {
                                          final cacheKey = 'questions_count_${topic.id}';
                                          final cachedCount = prefs.getInt(cacheKey);
                                          
                                          if (cachedCount != null && cachedCount > 0) {
                                            totalQuestions += cachedCount;
                                          } else if (topic.averageQuestionCount > 0) {
                                            // Cache'de yoksa topic'teki değeri kullan
                                            totalQuestions += topic.averageQuestionCount;
                                          }
                                        }
                                        
                                        // Eğer hala 0 ise, QuestionsService'den paralel olarak çek
                                        if (totalQuestions == 0 && topics.isNotEmpty) {
                                          try {
                                            final questionsService = QuestionsService();
                                            // Tüm topic'lerin soru sayılarını paralel olarak çek
                                            final questionCounts = await Future.wait(
                                              topics.map((topic) async {
                                                try {
                                                  final questions = await questionsService.getQuestionsByTopicId(
                                                    topic.id,
                                                    lessonId: widget.lesson.id,
                                                  );
                                                  // Cache'e kaydet
                                                  if (questions.isNotEmpty) {
                                                    await prefs.setInt('questions_count_${topic.id}', questions.length);
                                                  }
                                                  return questions.length;
                                                } catch (e) {
                                                  return 0;
                                                }
                                              }),
                                            );
                                            totalQuestions = questionCounts.fold(0, (sum, count) => sum + count);
                                          } catch (e) {
                                            // Silent error handling
                                          }
                                        }
                                        
                                        return totalQuestions;
                                      }),
                                      builder: (context, snapshot) {
                                        final questionCount = snapshot.hasData && snapshot.data! > 0
                                            ? snapshot.data!
                                            : widget.lesson.questionCount;
                                        final solved = (questionCount * widget.progress).round();
                                        return Text(
                                          '$solved/$questionCount',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Topic Count - Dinamik olarak çek
                                FutureBuilder<int>(
                                  future: _lessonsService.getTopicsByLessonId(widget.lesson.id).then((topics) => topics.length),
                                  builder: (context, snapshot) {
                                    final topicCount = snapshot.hasData ? snapshot.data! : widget.lesson.topicCount;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.4),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.library_books_rounded,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$topicCount Konu',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
        },
      ),
    );
  }
}
