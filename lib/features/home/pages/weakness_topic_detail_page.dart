import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        return const Color(0xFF4F46E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildPremiumHeader(context, isDark, statusBarHeight),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    final color = _getColor();
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D0221),
                    const Color(0xFF0F0F1A),
                    const Color(0xFF19102E),
                  ]
                : [const Color(0xFFF0F4FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -screenWidth * 0.4,
              left: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: isDark
                    ? color.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: _buildBlurCircle(
                size: screenWidth * 0.8,
                color: isDark
                    ? const Color(0xFF4C1D95).withValues(alpha: 0.08)
                    : const Color(0xFFC4B5FD).withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.1, 1.0],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildPremiumHeader(
    BuildContext context,
    bool isDark,
    double statusBarHeight,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, statusBarHeight + 8, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.topicName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_weaknesses.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _viewMode == _ViewMode.single
                          ? '${_singleViewIndex + 1}/${_weaknesses.length}'
                          : '${_weaknesses.length} Soru',
                      style: const TextStyle(
                        color: Color(0xFF0369A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!_isLoading && _weaknesses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildViewModeToggle(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleChip(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Liste',
            isSelected: _viewMode == _ViewMode.list,
            onTap: () => setState(() => _viewMode = _ViewMode.list),
          ),
          const SizedBox(width: 4),
          _buildToggleChip(
            icon: Icons.style_rounded,
            label: 'Tek Tek',
            isSelected: _viewMode == _ViewMode.single,
            onTap: () {
              setState(() {
                _viewMode = _ViewMode.single;
                _singleViewIndex = 0;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF1E293B) : Colors.black45,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1E293B) : Colors.black45,
              ),
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
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: isDark ? const Color(0xFF4F46E5) : const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              letterSpacing: 0.5,
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
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 60,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Zayıf Soru Kalmadı',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tebrikler! Bu konudaki tüm zayıf noktalarınızı giderdiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(bool isDark, bool isTablet, bool isSmallScreen) {
    return RefreshIndicator(
      onRefresh: _loadWeaknesses,
      color: _getColor(),
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        itemCount: _weaknesses.length,
        itemBuilder: (context, index) {
          return _buildPremiumQuestionItem(context, _weaknesses[index], isDark);
        },
      ),
    );
  }

  Widget _buildSingleQuestionView(bool isDark, bool isSmallScreen) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _weaknesses.length,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) => setState(() => _singleViewIndex = index),
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            children: [
              _buildPremiumQuestionItem(
                context,
                _weaknesses[index],
                isDark,
                isSingleView: true,
              ),
              const SizedBox(height: 8),
              _buildSingleViewNavigation(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSingleViewNavigation(bool isDark) {
    final canGoPrev = _singleViewIndex > 0;
    final canGoNext = _singleViewIndex < _weaknesses.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildTestStyleButton(
              label: 'ÖNCEKİ',
              icon: Icons.chevron_left_rounded,
              onPressed: canGoPrev
                  ? () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    )
                  : null,
              isDark: isDark,
              isPrimary: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTestStyleButton(
              label: 'SONRAKİ',
              icon: Icons.chevron_right_rounded,
              onPressed: canGoNext
                  ? () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    )
                  : null,
              isDark: isDark,
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestStyleButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
    required bool isPrimary,
  }) {
    final accentColor = const Color(0xFF2563EB);
    final isEnabled = onPressed != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
          boxShadow: [
            if (isEnabled)
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            foregroundColor: accentColor,
            side: BorderSide(
              color: accentColor.withOpacity(isEnabled ? 0.5 : 0.2),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isPrimary) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (isPrimary) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumQuestionItem(
    BuildContext context,
    WeaknessQuestion weakness,
    bool isDark, {
    bool isSingleView = false,
  }) {
    final color = _getColor();
    return Container(
      margin: isSingleView
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSingleView ? 32 : 24),
        boxShadow: isSingleView
            ? []
            : [
                BoxShadow(
                  color: (isDark ? Colors.black : color).withValues(
                    alpha: 0.05,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSingleView ? 32 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isSingleView
                  ? Colors.transparent
                  : (isDark ? const Color(0xFF1E1E2E) : Colors.white)
                        .withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(isSingleView ? 0 : 24),
              border: isSingleView
                  ? null
                  : Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.05 : 0.5,
                      ),
                      width: 1.5,
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSingleView ? 4 : 16,
                    vertical: isSingleView ? 8 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSingleView
                        ? Colors.transparent
                        : color.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: isSingleView
                            ? Colors.transparent
                            : color.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.priority_high_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'YANLIŞ YAPILAN SORU',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEF4444),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _removeWeakness(weakness),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: Color(0xFFEF4444),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Kaldır',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSingleView ? 0 : 20,
                    vertical: isSingleView ? 8 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (weakness.imageUrl != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              weakness.imageUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 150,
                                      width: double.infinity,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.black.withValues(
                                              alpha: 0.02,
                                            ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      FormattedText(
                        text: weakness.question,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...weakness.options.asMap().entries.map((entry) {
                        final isCorrect =
                            entry.key == weakness.correctAnswerIndex;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.08)
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.black.withValues(alpha: 0.02)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCorrect
                                  ? const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? const Color(0xFF10B981)
                                      : Colors.black.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: isCorrect
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          String.fromCharCode(65 + entry.key),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FormattedText(
                                  text: entry.value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? (isCorrect
                                              ? Colors.white
                                              : Colors.white70)
                                        : (isCorrect
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF1E293B)),
                                    fontWeight: isCorrect
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (weakness.explanation.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 18,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  weakness.explanation,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF1E293B),
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}
