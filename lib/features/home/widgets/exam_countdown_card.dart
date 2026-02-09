import 'package:flutter/material.dart';
import 'dart:async';

class ExamCountdownCard extends StatefulWidget {
  final DateTime examDate;
  final bool isSmallScreen;
  final bool isCompactLayout;

  const ExamCountdownCard({
    super.key,
    required this.examDate,
    this.isSmallScreen = false,
    this.isCompactLayout = false,
  });

  @override
  State<ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<ExamCountdownCard> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final difference = widget.examDate.difference(now);
    
    if (difference.isNegative) {
      setState(() {
        _remainingTime = Duration.zero;
      });
      _timer?.cancel();
    } else {
      setState(() {
        _remainingTime = difference;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallDevice = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours.remainder(24);
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    // Responsive sizing (tablet yatayda kompakt mod)
    final horizontalMargin = widget.isCompactLayout ? 0.0 : (isTablet ? 24.0 : 16.0);
    final cardPadding = widget.isCompactLayout ? 12.0 : (isSmallDevice ? 12.0 : 14.0);
    final iconSize = widget.isCompactLayout ? 22.0 : (isSmallDevice ? 24.0 : 28.0);
    final titleFontSize = widget.isCompactLayout ? 9.0 : (isSmallDevice ? 9.5 : 10.5);
    final subtitleFontSize = widget.isCompactLayout ? 8.0 : (isSmallDevice ? 8.5 : 9.5);
    final chipValueFontSize = widget.isCompactLayout ? 16.0 : (isSmallDevice ? 18.0 : 19.0);
    final chipLabelFontSize = widget.isCompactLayout ? 12.0 : (isSmallDevice ? 14.0 : 15.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: widget.isCompactLayout ? 4.0 : (isSmallDevice ? 4.0 : 6.0),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
            ? [
                const Color(0xFFE74C3C).withValues(alpha: 0.85),
                const Color(0xFFC0392B).withValues(alpha: 0.8),
              ]
            : [
                const Color(0xFFFF6B6B),
                const Color(0xFFEE5A6F),
              ],
        ),
        borderRadius: BorderRadius.circular(isSmallDevice ? 14.0 : 16.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE74C3C).withValues(alpha: 0.35),
            blurRadius: isSmallDevice ? 10 : 12,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated decorative circles
          Positioned(
            top: -14,
            right: -14,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                // Modern Calendar Icon
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(isSmallDevice ? 9 : 10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.25,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.event_note_rounded,
                      color: Colors.white,
                      size: isSmallDevice ? 16.0 : 18.0,
                    ),
                  ),
                ),
                SizedBox(width: isSmallDevice ? 10.0 : 12.0),
                // Title Section (daha az genişlik)
                Flexible(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SINAVA KALAN',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kadrox',
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Compact countdown (scales down on narrow screens)
                Flexible(
                  flex: 6,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCompactChip(
                          value: days.toString(),
                          label: 'gün',
                          valueSize: chipValueFontSize,
                          labelSize: chipLabelFontSize,
                        ),
                        _buildChipDivider(),
                        _buildCompactChip(
                          value: hours.toString().padLeft(2, '0'),
                          label: 'saat',
                          valueSize: chipValueFontSize,
                          labelSize: chipLabelFontSize,
                        ),
                        _buildChipDivider(),
                        _buildCompactChip(
                          value: minutes.toString().padLeft(2, '0'),
                          label: 'dk',
                          valueSize: chipValueFontSize,
                          labelSize: chipLabelFontSize,
                        ),
                        _buildChipDivider(),
                        _buildCompactChip(
                          value: seconds.toString().padLeft(2, '0'),
                          label: 'sn',
                          valueSize: chipValueFontSize,
                          labelSize: chipLabelFontSize,
                          isLive: true,
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
    );
  }

  Widget _buildCompactChip({
    required String value,
    required String label,
    required double valueSize,
    required double labelSize,
    bool isLive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.0,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.6),
          height: 1.0,
        ),
      ),
    );
  }
}
