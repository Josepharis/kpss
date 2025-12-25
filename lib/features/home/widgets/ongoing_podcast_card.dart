import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_podcast.dart';

class OngoingPodcastCard extends StatelessWidget {
  final OngoingPodcast podcast;
  final bool isSmallScreen;

  const OngoingPodcastCard({
    super.key,
    required this.podcast,
    this.isSmallScreen = false,
  });

  Color _getGradientStartColor() {
    switch (podcast.progressColor) {
      case 'blue':
        return const Color(0xFF6C5CE7);
      case 'yellow':
        return const Color(0xFFFDCB6E);
      case 'red':
        return const Color(0xFFE17055);
      case 'purple':
        return const Color(0xFFA29BFE);
      default:
        return AppColors.gradientBlueStart;
    }
  }

  Color _getGradientEndColor() {
    switch (podcast.progressColor) {
      case 'blue':
        return const Color(0xFF5A4FCF);
      case 'yellow':
        return const Color(0xFFE17055);
      case 'red':
        return const Color(0xFFD63031);
      case 'purple':
        return const Color(0xFF6C5CE7);
      default:
        return AppColors.gradientBlueEnd;
    }
  }

  IconData _getIcon() {
    if (podcast.title.toLowerCase().contains('kpss')) {
      return Icons.school_rounded;
    } else if (podcast.title.toLowerCase().contains('ags')) {
      return Icons.trending_up_rounded;
    } else if (podcast.title.toLowerCase().contains('motivasyon')) {
      return Icons.self_improvement_rounded;
    }
    
    switch (podcast.icon) {
      case 'atom':
        return Icons.science_rounded;
      case 'chart':
        return Icons.bar_chart_rounded;
      case 'globe':
        return Icons.public_rounded;
      case 'megaphone':
        return Icons.campaign_rounded;
      default:
        return Icons.podcasts_rounded;
    }
  }

  String _getSubjectName() {
    if (podcast.title.toLowerCase().contains('kpss')) {
      return 'KPSS';
    } else if (podcast.title.toLowerCase().contains('ags')) {
      return 'AGS';
    } else if (podcast.title.toLowerCase().contains('motivasyon')) {
      return 'Motivasyon';
    }
    return 'Podcast';
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = isSmallScreen ? 16.0 : 18.0;
    
    return GestureDetector(
      onTap: () {
        // Navigate to podcast detail
      },
      child: Container(
        width: isSmallScreen ? 115 : 130,
        height: isSmallScreen ? 110 : 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getGradientStartColor(),
              _getGradientEndColor(),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: _getGradientStartColor().withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: _getGradientStartColor().withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Soft gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.5,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Wave pattern
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.03),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Softer decorative elements - clipped
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  width: isSmallScreen ? 40 : 50,
                  height: isSmallScreen ? 40 : 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -12,
                left: -12,
                child: Container(
                  width: isSmallScreen ? 50 : 60,
                  height: isSmallScreen ? 50 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top section - Konu badge and Subject
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Konu badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 5 : 6,
                            vertical: isSmallScreen ? 2 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.headphones_rounded,
                                size: isSmallScreen ? 9 : 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: isSmallScreen ? 2 : 3),
                              Text(
                                'Konu',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7 : 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 5),
                        // Subject name
                        Text(
                          _getSubjectName(),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 9 : 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    
                    // Center - Icon with more space
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.32),
                                Colors.white.withValues(alpha: 0.15),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.48),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(-1, -1),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getIcon(),
                            size: isSmallScreen ? 20 : 24,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom - Progress section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${podcast.currentMinute}/${podcast.totalMinutes} dk',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 8 : 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
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
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 4 : 5,
                                vertical: isSmallScreen ? 1 : 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${(podcast.progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 7 : 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 4 : 5),
                        // Progress bar
                        Container(
                          height: isSmallScreen ? 4 : 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: podcast.progress,
                              backgroundColor: Colors.white.withValues(alpha: 0.22),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: isSmallScreen ? 4 : 5,
                            ),
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
  }
}
