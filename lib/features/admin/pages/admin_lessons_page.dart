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
  List<String> _hiddenLessonIds = [];
  List<String> _hiddenCategoryIds = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _lessonsService.getAllLessons(),
        _lessonsService.getHiddenLessons(),
        _lessonsService.getHiddenCategories(),
      ]);

      setState(() {
        _lessons = results[0] as List<Lesson>;
        _hiddenLessonIds = results[1] as List<String>;
        _hiddenCategoryIds = results[2] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group lessons by category
    final Map<String, List<Lesson>> groupedLessons = {};
    for (var lesson in _lessons) {
      groupedLessons.putIfAbsent(lesson.category, () => []).add(lesson);
    }

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
          widget.initialMode == 'publish' ? 'Görünürlük Yönetimi' : 'Dersleri Yönet',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lessons.isEmpty
              ? _buildEmptyState(isDark)
              : ListView(
                  padding: const EdgeInsets.all(15),
                  children: groupedLessons.entries.map((entry) {
                    return _buildCategorySection(entry.key, entry.value, isDark);
                  }).toList(),
                ),
    );
  }

  Widget _buildCategorySection(String categoryId, List<Lesson> lessons, bool isDark) {
    bool isCategoryVisible = !_hiddenCategoryIds.contains(categoryId);
    String categoryTitle = _getCategoryTitle(categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.initialMode == 'publish')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  categoryTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white38 : Colors.black38,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      isCategoryVisible ? 'Bölüm Açık' : 'Bölüm Kapalı',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isCategoryVisible ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isCategoryVisible,
                        activeColor: Colors.green,
                        onChanged: (value) async {
                          await _lessonsService.toggleCategoryHiddenStatus(categoryId, !value);
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(
              categoryTitle.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ...lessons.map((lesson) => _buildLessonCard(lesson, isDark)),
        const SizedBox(height: 15),
      ],
    );
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'genel_yetenek':
        return 'Genel Yetenek';
      case 'genel_kultur':
        return 'Genel Kültür';
      case 'alan_dersleri':
        return 'Alan Dersleri';
      default:
        return category;
    }
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
    bool isVisible = !_hiddenLessonIds.contains(lesson.id);

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
          widget.initialMode == 'publish' 
              ? (isVisible ? 'Yayında' : 'Gizli')
              : 'Bu derse ait konuları gör',
          style: TextStyle(
            fontSize: 12, 
            color: widget.initialMode == 'publish' 
                ? (isVisible ? Colors.green : Colors.red) 
                : Colors.grey.shade500,
            fontWeight: widget.initialMode == 'publish' ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: widget.initialMode == 'publish'
            ? Switch(
                value: isVisible,
                activeColor: Colors.green,
                onChanged: (value) async {
                  await _lessonsService.toggleLessonHiddenStatus(lesson.id, !value);
                  _loadData();
                },
              )
            : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
