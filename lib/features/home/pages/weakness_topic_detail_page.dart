import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/formatted_text.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/widgets/premium_snackbar.dart';

enum _ViewMode { list, single }

class WeaknessTopicDetailPage extends StatefulWidget {
  final Lesson lesson;
  final String topicName;

  const WeaknessTopicDetailPage({
    super.key,
    required this.lesson,
    required this.topicName,
  });

  @override
  State<WeaknessTopicDetailPage> createState() =>
      _WeaknessTopicDetailPageState();
}

class _WeaknessTopicDetailPageState extends State<WeaknessTopicDetailPage> {
  List<WeaknessQuestion> _weaknesses = [];
  bool _isLoading = true;
  _ViewMode _viewMode = _ViewMode.list;
  final PageController _pageController = PageController();
  int _singleViewIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadWeaknesses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadWeaknesses() async {
    setState(() {
      _isLoading = true;
    });

    final weaknesses = await WeaknessesService.getWeaknessesByLessonAndTopic(
      widget.lesson.id,
      widget.topicName,
    );

    if (mounted) {
      setState(() {
        _weaknesses = weaknesses;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeWeakness(WeaknessQuestion weakness) async {
    final success = await WeaknessesService.removeWeakness(
      weakness.id,
      weakness.topicName,
      lessonId: weakness.lessonId,
    );

    if (success && mounted) {
      PremiumSnackBar.show(
        context,
        message: 'Soru eksiklerden kaldırıldı.',
        type: SnackBarType.success,
      );
      _loadWeaknesses();
    } else if (mounted) {
      PremiumSnackBar.show(
        context,
        message: 'Soru kaldırılırken bir hata oluştu.',
        type: SnackBarType.error,
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final color = _getColor();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Premium header
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
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 16 : 12,
                  topPadding + 8,
                  isTablet ? 16 : 12,
                  12,
                ),
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
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: isSmallScreen ? 18 : 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.topicName,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_weaknesses.length} eksik soru',
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
                              child: Icon(
                                Icons.refresh_rounded,
                                size: isSmallScreen ? 20 : 22,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_isLoading && _weaknesses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildViewModeToggle(isDark),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoader(isDark)
                  : _weaknesses.isEmpty
                  ? _buildEmptyState(isDark)
                  : _viewMode == _ViewMode.list
                  ? _buildListView(isDark, isTablet, isSmallScreen)
                  : _buildSingleQuestionView(isDark, isSmallScreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader(bool isDark) {
    return Center(
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
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.white10
                    : const Color(0xFF10B981).withValues(alpha: 0.08)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 44,
                color: isDark
                    ? Colors.white38
                    : const Color(0xFF10B981).withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu konuda eksik soru yok',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tüm soruları çözdüğünüzde veya eksiklerden kaldırdığınızda burada listelenir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleChip(
            label: 'Liste',
            icon: Icons.format_list_bulleted_rounded,
            isSelected: _viewMode == _ViewMode.list,
            isDark: isDark,
            onTap: () => setState(() => _viewMode = _ViewMode.list),
          ),
          _buildToggleChip(
            label: 'Tek tek',
            icon: Icons.looks_one_rounded,
            isSelected: _viewMode == _ViewMode.single,
            isDark: isDark,
            onTap: () {
              setState(() {
                _viewMode = _ViewMode.single;
                _singleViewIndex = 0;
              });
              _pageController.jumpToPage(0);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? _getColor()
                    : Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _getColor() : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView(bool isDark, bool isTablet, bool isSmallScreen) {
    return RefreshIndicator(
      onRefresh: _loadWeaknesses,
      color: AppColors.primaryBlue,
      backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 20 : 16,
          12,
          isTablet ? 20 : 16,
          24,
        ),
        itemCount: _weaknesses.length,
        itemBuilder: (context, index) {
          final weakness = _weaknesses[index];
          final isLast = index == _weaknesses.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: _buildQuestionCard(
              weakness: weakness,
              isTablet: isTablet,
              isSmallScreen: isSmallScreen,
              isDark: isDark,
              showRemove: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSingleQuestionView(bool isDark, bool isSmallScreen) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tek soru görünümü',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white12
                      : AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_singleViewIndex + 1} / ${_weaknesses.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _weaknesses.length,
            onPageChanged: (index) => setState(() => _singleViewIndex = index),
            itemBuilder: (context, index) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _buildQuestionCard(
                  weakness: _weaknesses[index],
                  isTablet: false,
                  isSmallScreen: isSmallScreen,
                  isDark: isDark,
                  showRemove: true,
                ),
              );
            },
          ),
        ),
        _buildSingleViewNavigation(isDark),
      ],
    );
  }

  Widget _buildSingleViewNavigation(bool isDark) {
    final canGoPrev = _singleViewIndex > 0;
    final canGoNext = _singleViewIndex < _weaknesses.length - 1;
    final color = _getColor();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 6,
        bottom: 6 + bottomPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canGoPrev
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      )
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: canGoPrev
                          ? (isDark
                                ? Colors.white24
                                : AppColors.primaryBlue.withValues(alpha: 0.4))
                          : (isDark
                                ? Colors.white10
                                : Colors.grey.withValues(alpha: 0.2)),
                      width: 1,
                    ),
                    color: canGoPrev
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.primaryBlue.withValues(alpha: 0.06))
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: canGoPrev
                            ? (isDark ? Colors.white70 : AppColors.primaryBlue)
                            : (isDark ? Colors.white38 : AppColors.textLight),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Önceki',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: canGoPrev
                              ? (isDark
                                    ? Colors.white70
                                    : AppColors.primaryBlue)
                              : (isDark ? Colors.white38 : AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canGoNext
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      )
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: canGoNext
                          ? color.withValues(alpha: 0.7)
                          : (isDark
                                ? Colors.white10
                                : Colors.grey.withValues(alpha: 0.2)),
                      width: 1,
                    ),
                    color: canGoNext
                        ? color.withValues(alpha: 0.12)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sonraki',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: canGoNext
                              ? (isDark ? Colors.white : color)
                              : (isDark ? Colors.white38 : AppColors.textLight),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: canGoNext
                            ? (isDark ? Colors.white : color)
                            : (isDark ? Colors.white38 : AppColors.textLight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required WeaknessQuestion weakness,
    required bool isTablet,
    required bool isSmallScreen,
    required bool isDark,
    required bool showRemove,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (weakness.imageUrl != null)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.02),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  weakness.imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FormattedText(
                  text: weakness.question,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
              if (showRemove) ...[
                const SizedBox(width: 12),
                Material(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _removeWeakness(weakness),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: isSmallScreen ? 18 : 20,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ...weakness.options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value;
            final isCorrect = optionIndex == weakness.correctAnswerIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 14 : 16,
                vertical: isSmallScreen ? 12 : 14,
              ),
              decoration: BoxDecoration(
                color: isCorrect
                    ? const Color(
                        0xFF10B981,
                      ).withValues(alpha: isDark ? 0.2 : 0.08)
                    : (isDark
                          ? const Color(0xFF2C2C2C)
                          : const Color(0xFFF8F9FA)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                  width: isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (isCorrect)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  if (isCorrect) const SizedBox(width: 12),
                  Expanded(
                    child: FormattedText(
                      text: option,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        color: isCorrect
                            ? const Color(0xFF059669)
                            : (isDark ? Colors.white : AppColors.textPrimary),
                        fontWeight: isCorrect
                            ? FontWeight.w600
                            : FontWeight.normal,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
            decoration: BoxDecoration(
              color: const Color(
                0xFFF59E0B,
              ).withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormattedText(
                    text: weakness.explanation,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: weakness.isFromWrongAnswer
                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      weakness.isFromWrongAnswer
                          ? Icons.error_outline_rounded
                          : Icons.bookmark_rounded,
                      size: 14,
                      color: weakness.isFromWrongAnswer
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      weakness.isFromWrongAnswer
                          ? 'Yanlış cevaplanan'
                          : 'Kaydedilen soru',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: weakness.isFromWrongAnswer
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
