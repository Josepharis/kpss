import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/widgets/formatted_text.dart';

class AllSavedQuestionsPage extends StatefulWidget {
  final String? lessonId;
  final String? lessonName;

  const AllSavedQuestionsPage({super.key, this.lessonId, this.lessonName});

  @override
  State<AllSavedQuestionsPage> createState() => _AllSavedQuestionsPageState();
}

class _AllSavedQuestionsPageState extends State<AllSavedQuestionsPage> {
  List<WeaknessQuestion> _allQuestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      var questions = await WeaknessesService.getAllWeaknesses();
      if (widget.lessonId != null) {
        questions = questions
            .where((q) => q.lessonId == widget.lessonId)
            .toList();
      }

      // Sort by newest first
      questions.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      if (mounted) {
        setState(() {
          _allQuestions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeQuestion(WeaknessQuestion weakness) async {
    final originalQuestions = List<WeaknessQuestion>.from(_allQuestions);

    // Optimistic UI Update
    setState(() {
      _allQuestions.removeWhere((q) => q.id == weakness.id);
    });

    // Perform actual operation in background
    try {
      final success = await WeaknessesService.removeWeakness(
        weakness.id,
        weakness.topicName,
        lessonId: weakness.lessonId,
      );
      if (!success) throw Exception('Failed to remove question');
    } catch (e) {
      // Revert state if it failed
      if (mounted) {
        setState(() {
          _allQuestions = originalQuestions;
        });
        PremiumSnackBar.show(
          context,
          message: 'Soru kaldırılırken bir hata oluştu.',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
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
            // Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // Main Content
            SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildPremiumHeader(context, isDark, statusBarHeight),
                  Expanded(
                    child: _isLoading
                        ? _buildLoader(isDark)
                        : _allQuestions.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildQuestionsList(isDark),
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
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                    : const Color(0xFFFCD34D).withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: _buildBlurCircle(
                size: screenWidth * 0.8,
                color: isDark
                    ? const Color(0xFFD97706).withValues(alpha: 0.08)
                    : const Color(0xFFFDE68A).withValues(alpha: 0.15),
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
    const accentColor = Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, statusBarHeight + 10, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        accentColor.withValues(alpha: 0.8),
                        const Color(0xFF16213E).withValues(alpha: 0.6),
                      ]
                    : [
                        accentColor.withValues(alpha: 0.8),
                        accentColor.withValues(alpha: 0.6),
                      ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soru Koleksiyonu'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.lessonName ?? 'Tüm Sorular',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildHeaderStatChip(
                      icon: Icons.quiz_rounded,
                      count: _allQuestions.length,
                      label: 'Soru',
                      color: const Color(0xFFF59E0B),
                    ),
                    const Spacer(),
                    _buildSelectionIndicator(isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatChip({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'En Yeni',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
              color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sorular yükleniyor...',
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
                Icons.quiz_outlined,
                size: 60,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Soru Bulunamadı',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Burada henüz bir soru bulunmuyor. Yanlış yaptığınız veya kaydettiğiniz sorular burada listelenir.',
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

  Widget _buildQuestionsList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadQuestions,
      color: const Color(0xFFF59E0B),
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        itemCount: _allQuestions.length,
        itemBuilder: (context, index) {
          final weakness = _allQuestions[index];
          return _buildPremiumQuestionItem(context, weakness, isDark);
        },
      ),
    );
  }

  Widget _buildPremiumQuestionItem(
    BuildContext context,
    WeaknessQuestion weakness,
    bool isDark,
  ) {
    const accentColor = Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : accentColor).withValues(
              alpha: 0.05,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF1E1E2E) : Colors.white)
                  .withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.05),
                    border: Border(
                      bottom: BorderSide(
                        color: accentColor.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.bookmark_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'KAYDEDİLEN SORU',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _removeQuestion(weakness),
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

                // Question Body
                Padding(
                  padding: const EdgeInsets.all(20),
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
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Options
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
                                child: Text(
                                  entry.value,
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
                      // Explanation
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
                                child: FormattedText(
                                  text: weakness.explanation,
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
