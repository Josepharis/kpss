import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class ExamInfo {
  final String id;
  final String name;
  final DateTime date;

  ExamInfo({required this.id, required this.name, required this.date});
}

final List<ExamInfo> exams2026 = [
  ExamInfo(
    id: 'ags_oabt',
    name: 'AGS & ÖABT',
    date: DateTime(2026, 7, 12, 10, 15),
  ),
  ExamInfo(
    id: 'kpss_lisans',
    name: 'KPSS Lisans (GY-GK)',
    date: DateTime(2026, 9, 6, 10, 15),
  ),
  ExamInfo(
    id: 'kpss_alan',
    name: 'KPSS Alan Bilgisi',
    date: DateTime(2026, 9, 12, 10, 15),
  ),
  ExamInfo(
    id: 'kpss_onlisans',
    name: 'KPSS Ön Lisans',
    date: DateTime(2026, 10, 4, 10, 15),
  ),
  ExamInfo(
    id: 'kpss_ortaogretim',
    name: 'KPSS Ortaöğretim',
    date: DateTime(2026, 10, 25, 10, 15),
  ),
];

class ExamCountdownCard extends StatefulWidget {
  final bool isSmallScreen;
  final bool isCompactLayout;

  const ExamCountdownCard({
    super.key,
    this.isSmallScreen = false,
    this.isCompactLayout = false,
  });

  @override
  State<ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<ExamCountdownCard> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  ExamInfo _selectedExam = exams2026[0];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedExam();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  Future<void> _loadSelectedExam() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_exam_id');
    if (savedId != null) {
      final exam = exams2026.firstWhere(
        (e) => e.id == savedId,
        orElse: () => exams2026[0],
      );
      if (mounted) {
        setState(() {
          _selectedExam = exam;
          _isLoading = false;
        });
        _updateCountdown();
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        _updateCountdown();
      }
    }
  }

  Future<void> _saveSelectedExam(ExamInfo exam) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_exam_id', exam.id);
    if (mounted) {
      setState(() {
        _selectedExam = exam;
      });
      _updateCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final difference = _selectedExam.date.difference(now);
    if (mounted) {
      setState(() {
        _remainingTime = difference.isNegative ? Duration.zero : difference;
      });
    }
  }

  void _showExamPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ExamPickerSheet(
        selectedId: _selectedExam.id,
        onSelected: (exam) {
          _saveSelectedExam(exam);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 64);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final days = _remainingTime.inDays;
    final hours = _remainingTime.inHours.remainder(24);
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    return GestureDetector(
      onTap: _showExamPicker,
      child: Container(
        width: double.infinity,
        height: 64,
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
                        Row(
                          children: [
                            Text(
                              _selectedExam.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFFDC2626),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 10,
                              color: isDark
                                  ? const Color(0xFFF87171).withOpacity(0.5)
                                  : const Color(0xFFDC2626).withOpacity(0.5),
                            ),
                          ],
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

class _ExamPickerSheet extends StatelessWidget {
  final String selectedId;
  final Function(ExamInfo) onSelected;

  const _ExamPickerSheet({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sınav Seçimi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.05),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...exams2026.map((exam) {
            final isSelected = exam.id == selectedId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onSelected(exam),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSelected
                        ? (isDark
                              ? const Color(0xFFEF4444).withOpacity(0.1)
                              : const Color(0xFFEF4444).withOpacity(0.05))
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFEF4444).withOpacity(0.5)
                          : (isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05)),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEF4444)
                              : (isDark
                                    ? Colors.white10
                                    : Colors.black.withOpacity(0.03)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.event_note_rounded,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white54 : Colors.black54),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                color: isSelected
                                    ? (isDark
                                          ? Colors.white
                                          : const Color(0xFFEF4444))
                                    : (isDark
                                          ? Colors.white70
                                          : Colors.black87),
                              ),
                            ),
                            Text(
                              '${exam.date.day} ${_getMonthName(exam.date.month)} ${exam.date.year}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return months[month - 1];
  }
}
