import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/weakness_question.dart';
import '../../../core/services/weaknesses_service.dart';
import '../../../core/widgets/premium_snackbar.dart';

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
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D0D0D)
          : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.lessonName ?? 'Tüm Sorular'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allQuestions.isEmpty
          ? _buildEmptyState(isDark)
          : _buildQuestionsView(isDark, isTablet),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz soru yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsView(bool isDark, bool isTablet) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allQuestions.length,
      itemBuilder: (context, index) {
        final weakness = _allQuestions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weakness.topicName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (weakness.imageUrl != null)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                weakness.imageUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        Text(
                          weakness.question,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeQuestion(weakness),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...weakness.options.asMap().entries.map((entry) {
                final isCorrect = entry.key == weakness.correctAnswerIndex;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCorrect
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isCorrect)
                        const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                      if (isCorrect) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: isCorrect
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (weakness.explanation.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          weakness.explanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white70
                                : AppColors.textPrimary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
