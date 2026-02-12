import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/lessons_service.dart';
import 'dart:ui';

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
  late Animation<double> _glowAnimation;
  final LessonsService _lessonsService = LessonsService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (widget.lesson.color) {
      case 'orange':
        return const Color(0xFFFF8C32);
      case 'blue':
        return const Color(0xFF00D2FF);
      case 'red':
        return const Color(0xFFFF4B2B);
      case 'green':
        return const Color(0xFF00F260);
      case 'purple':
        return const Color(0xFF8E2DE2);
      case 'teal':
        return const Color(0xFF00C9FF);
      case 'indigo':
        return const Color(0xFF396AFC);
      case 'pink':
        return const Color(0xFFFF00CC);
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
    final baseColor = _getColor();
    final progressPercentage = (widget.progress * 100).toInt();

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        Future.delayed(const Duration(milliseconds: 150), widget.onTap);
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(
                      0.3 + (0.2 * _glowAnimation.value),
                    ),
                    blurRadius: 15 + (8 * _glowAnimation.value),
                    offset: Offset(0, 8 + (4 * _glowAnimation.value)),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // 1. Deep Gradient Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            baseColor,
                            Color.lerp(baseColor, Colors.black, 0.15)!,
                            Color.lerp(baseColor, Colors.black, 0.45)!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),

                    // 2. Mesh/Organic background shapes
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. Frosted Glass Top Highlight
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.transparent,
                              Colors.black.withOpacity(0.08),
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // 4. Large Watermark Icon
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Opacity(
                        opacity: 0.1,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: Icon(
                            _getIcon(),
                            size: widget.isSmallScreen ? 70 : 100,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // 5. Main Content
                    Padding(
                      padding: EdgeInsets.all(widget.isSmallScreen ? 12 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Glass Icon & Topic
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  widget.isSmallScreen ? 6 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getIcon(),
                                  size: widget.isSmallScreen ? 14 : 18,
                                  color: Colors.white,
                                ),
                              ),
                              FutureBuilder<int>(
                                future: _lessonsService
                                    .getTopicsByLessonId(widget.lesson.id)
                                    .then((topics) => topics.length),
                                builder: (context, snapshot) {
                                  final count =
                                      snapshot.data ?? widget.lesson.topicCount;
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: widget.isSmallScreen ? 6 : 8,
                                      vertical: widget.isSmallScreen ? 3 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Text(
                                      '$count Konu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: widget.isSmallScreen
                                            ? 7.5
                                            : 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const Spacer(),

                          // Lesson Title
                          Text(
                            widget.lesson.name,
                            style: TextStyle(
                              fontSize: widget.isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.1,
                              shadows: const [
                                Shadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          SizedBox(height: widget.isSmallScreen ? 6 : 10),

                          // Progress Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '%$progressPercentage',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: widget.isSmallScreen ? 9.5 : 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  FutureBuilder<int>(
                                    future: _lessonsService
                                        .getTopicsByLessonId(widget.lesson.id)
                                        .then((topics) async {
                                          final prefs =
                                              await SharedPreferences.getInstance();
                                          int total = 0;
                                          for (var t in topics) {
                                            total +=
                                                (prefs.getInt(
                                                  'questions_count_${t.id}',
                                                ) ??
                                                t.averageQuestionCount);
                                          }
                                          return total > 0
                                              ? total
                                              : widget.lesson.questionCount;
                                        }),
                                    builder: (context, snapshot) {
                                      final total =
                                          snapshot.data ??
                                          widget.lesson.questionCount;
                                      final solved = (total * widget.progress)
                                          .round();
                                      return Text(
                                        '$solved/$total Soru',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: widget.isSmallScreen
                                              ? 7.5
                                              : 8.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: widget.isSmallScreen ? 4 : 6),
                              // Glassy Progress Bar
                              Container(
                                height: widget.isSmallScreen ? 3.5 : 5,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: widget.progress.clamp(
                                        0.02,
                                        1.0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.white,
                                              Colors.white70,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                              blurRadius: 6,
                                              spreadRadius: 1,
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
