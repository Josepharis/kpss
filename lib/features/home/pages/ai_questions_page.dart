import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ai_question.dart';
import '../../../core/services/ai_content_service.dart';

class AiQuestionsPage extends StatefulWidget {
  final String topicId;
  final String topicName;

  const AiQuestionsPage({
    super.key,
    required this.topicId,
    required this.topicName,
  });

  @override
  State<AiQuestionsPage> createState() => _AiQuestionsPageState();
}

class _AiQuestionsPageState extends State<AiQuestionsPage> {
  bool _loading = true;
  List<AiQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final questions = await AiContentService.instance.getQuestions(widget.topicId);
    if (!mounted) return;
    setState(() {
      _questions = questions;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await AiContentService.instance.clearQuestions(widget.topicId);
    await _load();
  }

  String _optionLetter(int index) => String.fromCharCode('A'.codeUnitAt(0) + index);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.gradientPurpleStart,
        elevation: 0,
        title: Text(
          'AI Sorular • ${widget.topicName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_questions.isNotEmpty)
            IconButton(
              tooltip: 'Temizle',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('AI Soruları Sil'),
                    content: const Text('Bu konuya ait kaydedilmiş AI soruları silinsin mi?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await _clear();
              },
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Bu konu için AI sorusu yok',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
                        title: Text(
                          'Soru ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          q.question,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary),
                        ),
                        children: [
                          const SizedBox(height: 6),
                          ...List.generate(q.options.length, (i) {
                            final isCorrect = i == q.correctIndex;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? Colors.green.withValues(alpha: isDark ? 0.18 : 0.12)
                                      : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCorrect
                                        ? Colors.green.withValues(alpha: 0.45)
                                        : Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isCorrect
                                            ? Colors.green.withValues(alpha: 0.9)
                                            : Colors.grey.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _optionLetter(i),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCorrect ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        q.options[i],
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppColors.textPrimary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (q.explanation.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Açıklama',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              q.explanation,
                              style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

