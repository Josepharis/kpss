import 'package:flutter/material.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/lessons_service.dart';
import 'admin_topics_page.dart';

class AdminLessonsPage extends StatefulWidget {
  final String initialMode; // 'topics' or 'questions'
  
  const AdminLessonsPage({super.key, this.initialMode = 'topics'});

  @override
  State<AdminLessonsPage> createState() => _AdminLessonsPageState();
}

class _AdminLessonsPageState extends State<AdminLessonsPage> {
  final LessonsService _lessonsService = LessonsService();
  bool _isLoading = true;
  List<Lesson> _lessons = [];

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    try {
      final lessons = await _lessonsService.getAllLessons();
      setState(() {
        _lessons = lessons;
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
        title: const Text(
          'Dersleri Yönet',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lessons.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    return _buildLessonCard(lesson, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Text(
        'Ders bulunamadı.',
        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson, bool isDark) {
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
            color: const Color(0xFF4F46E5).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.book_rounded, color: Color(0xFF4F46E5), size: 24),
        ),
        title: Text(
          lesson.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Bu derse ait konuları gör',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminTopicsPage(
                lesson: lesson,
                mode: widget.initialMode,
              ),
            ),
          );
        },
      ),
    );
  }
}
