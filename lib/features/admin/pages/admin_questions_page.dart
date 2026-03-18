import 'package:flutter/material.dart';
import '../../../core/models/topic.dart';
import '../../../core/models/test_question.dart';
import '../../../core/services/questions_service.dart';
import 'admin_edit_question_page.dart';

class AdminQuestionsPage extends StatefulWidget {
  final Topic topic;

  const AdminQuestionsPage({super.key, required this.topic});

  @override
  State<AdminQuestionsPage> createState() => _AdminQuestionsPageState();
}

class _AdminQuestionsPageState extends State<AdminQuestionsPage> {
  final QuestionsService _questionsService = QuestionsService();
  bool _isLoading = true;
  List<TestQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      // Admin page works with Firestore questions primarily
      final questions = await _questionsService.getQuestionsByTopicId(
        widget.topic.id,
        lessonId: widget.topic.lessonId,
      );
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuestion(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soruyu Sil'),
        content: const Text('Bu soruyu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _questionsService.deleteQuestion(id);
      if (success) {
        setState(() => _questions.removeWhere((q) => q.id == id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Soru başarıyla silindi')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
          ),
        ),
        elevation: 0,
        title: Text(
          widget.topic.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    return _buildQuestionCard(question, isDark);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminEditQuestionPage(
                topicId: widget.topic.id,
                lessonId: widget.topic.lessonId,
              ),
            ),
          );
          if (result == true) _loadQuestions();
        },
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Henüz soru eklenmemiş', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(TestQuestion question, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          question.question,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Doğru Seçenek: ${String.fromCharCode(65 + question.correctAnswerIndex)} | ${question.options.length} Seçenek',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seçenekler:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...List.generate(question.options.length, (index) {
                  final optionText = question.options[index];
                  final isCorrect = index == question.correctAnswerIndex;
                  final optionChar = String.fromCharCode(65 + index); // A, B, C...

                  return Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$optionChar)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? Colors.green : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(optionText, style: const TextStyle(fontSize: 13))),
                        if (isCorrect) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text(
                  'Çözüm:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  question.explanation.isEmpty ? 'Çözüm belirtilmemiş' : question.explanation,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminEditQuestionPage(
                              topicId: widget.topic.id,
                              lessonId: widget.topic.lessonId,
                              question: question,
                            ),
                          ),
                        );
                        if (result == true) _loadQuestions();
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Düzenle'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteQuestion(question.id),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Sil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
