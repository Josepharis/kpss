import 'package:flutter/material.dart';
import 'dart:async';

class ExamCountdownCard extends StatefulWidget {
  final DateTime examDate;
  final bool isSmallScreen;

  const ExamCountdownCard({
    super.key,
    required this.examDate,
    this.isSmallScreen = false,
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
    final isTablet = screenWidth > 600;
    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours.remainder(24);
    final minutes = _remainingTime.inMinutes.remainder(60);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : 16.0,
        vertical: widget.isSmallScreen ? 4.0 : 6.0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE74C3C),
            const Color(0xFFC0392B),
          ],
        ),
        borderRadius: BorderRadius.circular(widget.isSmallScreen ? 12.0 : 14.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE74C3C).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isSmallScreen ? 12.0 : 14.0,
          vertical: widget.isSmallScreen ? 10.0 : 12.0,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(widget.isSmallScreen ? 6.0 : 7.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.event_available_rounded,
                color: Colors.white,
                size: widget.isSmallScreen ? 16.0 : 18.0,
              ),
            ),
            SizedBox(width: widget.isSmallScreen ? 10.0 : 12.0),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sınava Kalan Süre',
                    style: TextStyle(
                      fontSize: widget.isSmallScreen ? 11.0 : 12.0,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'KPSS & AGS 2026',
                    style: TextStyle(
                      fontSize: widget.isSmallScreen ? 9.0 : 10.0,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: widget.isSmallScreen ? 8.0 : 10.0),
            // Compact countdown - horizontal
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactTimeUnit(
                  value: days.toString(),
                  label: 'g',
                  isSmallScreen: widget.isSmallScreen,
                ),
                _buildCompactDivider(),
                _buildCompactTimeUnit(
                  value: hours.toString().padLeft(2, '0'),
                  label: 's',
                  isSmallScreen: widget.isSmallScreen,
                ),
                _buildCompactDivider(),
                _buildCompactTimeUnit(
                  value: minutes.toString().padLeft(2, '0'),
                  label: 'dk',
                  isSmallScreen: widget.isSmallScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTimeUnit({
    required String value,
    required String label,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 4.0 : 5.0,
        vertical: isSmallScreen ? 3.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 13.0 : 14.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 9.0 : 10.0,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDivider() {
    return Container(
      width: 1,
      height: widget.isSmallScreen ? 16.0 : 18.0,
      margin: EdgeInsets.symmetric(horizontal: widget.isSmallScreen ? 4.0 : 5.0),
      color: Colors.white.withValues(alpha: 0.3),
    );
  }
}
