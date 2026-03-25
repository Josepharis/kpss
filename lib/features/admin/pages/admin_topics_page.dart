import 'package:flutter/material.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/lessons_service.dart';
import 'admin_questions_page.dart';
import 'admin_edit_question_page.dart';
import 'admin_topic_content_visibility_page.dart';

class AdminTopicsPage extends StatefulWidget {
  final Lesson lesson;
  final String mode; // 'topics' or 'questions'

  const AdminTopicsPage({super.key, required this.lesson, this.mode = 'topics'});

  @override
  State<AdminTopicsPage> createState() => _AdminTopicsPageState();
}

class _AdminTopicsPageState extends State<AdminTopicsPage> {
  final LessonsService _lessonsService = LessonsService();
  bool _isLoading = true;
  List<Topic> _topics = [];
  List<String> _hiddenTopicIds = [];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _isLoading = true);
    try {
      final topics = await _lessonsService.getTopicsByLessonId(widget.lesson.id);
      
      List<String> hiddenIds = [];
      if (widget.mode == 'publish') {
        hiddenIds = await _lessonsService.getHiddenTopics();
      }

      setState(() {
        _topics = topics;
        _hiddenTopicIds = hiddenIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC),
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
          '${widget.lesson.name} - Konular',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _topics.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _topics.length,
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    return _buildTopicCard(topic, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Text(
        'Konu bulunamadı.',
        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }

  Widget _buildTopicCard(Topic topic, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.category_rounded, color: Color(0xFF7C3AED), size: 24),
        ),
        title: Text(
          topic.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          widget.mode == 'publish' 
            ? 'Kullanıcılara erişime aç/kapat'
            : (widget.mode == 'add_question' ? 'Bu konuya yeni soru ekle' : 'Bu konuya ait soruları gör'),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        trailing: widget.mode == 'publish'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: !_hiddenTopicIds.contains(topic.id), // True if visible (NOT hidden)
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (bool isVisible) async {
                      final willBeHidden = !isVisible;
                      setState(() {
                        if (willBeHidden) {
                          _hiddenTopicIds.add(topic.id);
                        } else {
                          _hiddenTopicIds.remove(topic.id);
                        }
                      });
                      await _lessonsService.toggleTopicHiddenStatus(topic.id, willBeHidden);
                    },
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          if (widget.mode == 'publish') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminTopicContentVisibilityPage(
                  topic: topic,
                  lessonName: widget.lesson.name,
                ),
              ),
            );
            return;
          }
          if (widget.mode == 'add_question') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminEditQuestionPage(
                  topicId: topic.id,
                  lessonId: topic.lessonId,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminQuestionsPage(topic: topic),
              ),
            );
          }
        },
      ),
    );
  }
}
