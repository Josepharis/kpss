import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

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
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final difference = widget.examDate.difference(now);
    if (mounted) {
      setState(() {
        _remainingTime = difference.isNegative ? Duration.zero : difference;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours.remainder(24);
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    return Container(
      width: double.infinity,
      height: 64, // Sleek height matching QuoteCard
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFEF4444))
                .withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.65)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : const Color(0xFFEF4444).withOpacity(0.12),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                // Minimalist Timer Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.timer_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KPSS GERİ SAYIM',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFFF87171)
                              : const Color(0xFFDC2626),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          _buildStylishTimeDisplay(
                            days.toString(),
                            'GÜN',
                            isDark,
                            isBold: true,
                          ),
                          const SizedBox(width: 8),
                          _buildStylishTimeDisplay(
                            hours.toString().padLeft(2, '0'),
                            'SAAT',
                            isDark,
                          ),
                          _buildSeparator(isDark),
                          _buildStylishTimeDisplay(
                            minutes.toString().padLeft(2, '0'),
                            'DK',
                            isDark,
                          ),
                          _buildSeparator(isDark),
                          _buildStylishTimeDisplay(
                            seconds.toString().padLeft(2, '0'),
                            'SN',
                            isDark,
                            isLive: true,
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
  }

  Widget _buildStylishTimeDisplay(
    String value,
    String unit,
    bool isDark, {
    bool isLive = false,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: FontWeight.w900,
            color: isLive
                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                : (isDark ? Colors.white : const Color(0xFF1E293B)),
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 1),
        Text(
          unit,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
    );
  }
}
