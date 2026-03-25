import 'package:flutter/material.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/questions_service.dart';

class AdminTopicContentVisibilityPage extends StatefulWidget {
  final Topic topic;
  final String lessonName;

  const AdminTopicContentVisibilityPage({
    super.key,
    required this.topic,
    required this.lessonName,
  });

  @override
  State<AdminTopicContentVisibilityPage> createState() => _AdminTopicContentVisibilityPageState();
}

class _AdminTopicContentVisibilityPageState extends State<AdminTopicContentVisibilityPage> {
  final LessonsService _lessonsService = LessonsService();
  final StorageService _storageService = StorageService();
  final QuestionsService _questionsService = QuestionsService();

  bool _isLoading = true;
  List<String> _hiddenContentTypes = [];
  List<String> _hiddenItemIds = [];
  
  // Lists of actual items on Storage
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, String>> _podcasts = [];
  List<Map<String, String>> _flashcards = [];
  List<String> _pdfs = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _lessonsService.getTopicHiddenContentTypes(),
        _lessonsService.getHiddenItems(),
        _loadStorageItems(),
      ]);

      final allHiddenContentTypes = results[0] as Map<String, List<String>>;
      
      setState(() {
        _hiddenContentTypes = allHiddenContentTypes[widget.topic.id] ?? [];
        _hiddenItemIds = results[1] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading topic visibility: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStorageItems() async {
    final lessonNameForPath = _lessonsService.normalizeForStoragePath(widget.lessonName);
    final topicBasePath = await _lessonsService.getTopicBasePath(
      lessonId: widget.topic.lessonId,
      topicId: widget.topic.id,
      lessonNameForPath: lessonNameForPath,
    );

    // 1. Tests
    _tests = await _questionsService.getAvailableTestsByTopic(
      widget.topic.id,
      widget.topic.lessonId,
    );

    // 2. Podcasts
    try {
      _podcasts = await _storageService.listFilesWithPaths('$topicBasePath/podcast');
    } catch (_) {}

    // 3. Flashcards
    try {
      _flashcards = await _storageService.listFilesWithPaths('$topicBasePath/bilgikarti');
    } catch (_) {}

    // 4. PDFs
    try {
      final pdfFolders = ['$topicBasePath/konu', '$topicBasePath/pdf'];
      for (final folder in pdfFolders) {
        final files = await _storageService.listFileNames(folder);
        _pdfs.addAll(files.where((f) => f.toLowerCase().endsWith('.pdf')));
      }
    } catch (_) {}
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
        title: Text(
          '${widget.topic.name} - İçerik Yönetimi',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('BÖLÜM GÖRÜNÜRLÜĞÜ', Icons.visibility_rounded),
                  _buildContentTypeToggle('Konu Anlatımı (PDF)', 'pdf'),
                  _buildContentTypeToggle('Çıkmış Sorular', 'questions'),
                  _buildContentTypeToggle('Konu Testleri', 'tests'),
                  _buildContentTypeToggle('Podcastler', 'podcasts'),
                  _buildContentTypeToggle('Bilgi Kartları', 'flashcards'),
                  
                  const SizedBox(height: 30),
                  _buildSectionHeader('ÖZEL İÇERİK YÖNETİMİ', Icons.list_alt_rounded),
                  
                  if (_tests.isNotEmpty) ...[
                    _buildSubHeader('Testler'),
                    ..._tests.map((test) => _buildItemToggle(
                      test['name'] ?? test['fileName'], 
                      'test_${widget.topic.id}_${test['fileName']}',
                    )),
                  ],

                  if (_podcasts.isNotEmpty) ...[
                    _buildSubHeader('Podcastler'),
                    ..._podcasts.map((p) => _buildItemToggle(
                      p['name'] ?? p['fullPath']!.split('/').last, 
                      'podcast_${widget.topic.id}_${p['fullPath']!.split('/').last}',
                    )),
                  ],

                  if (_flashcards.isNotEmpty) ...[
                    _buildSubHeader('Bilgi Kartları'),
                    ..._flashcards.map((f) => _buildItemToggle(
                      f['name'] ?? f['fullPath']!.split('/').last, 
                      'flashcard_${widget.topic.id}_${f['fullPath']!.split('/').last}',
                    )),
                  ],

                  if (_pdfs.isNotEmpty) ...[
                    _buildSubHeader('PDF Dosyaları'),
                    ..._pdfs.map((pdf) => _buildItemToggle(
                      pdf, 
                      'pdf_${widget.topic.id}_$pdf',
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildContentTypeToggle(String label, String type) {
    bool isVisible = !_hiddenContentTypes.contains(type);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(isVisible ? 'Yayında' : 'Gizli', style: TextStyle(fontSize: 11, color: isVisible ? Colors.green : Colors.red)),
        value: isVisible,
        onChanged: (value) async {
          await _lessonsService.toggleTopicContentTypeHiddenStatus(widget.topic.id, type, !value);
          _loadAll();
        },
      ),
    );
  }

  Widget _buildItemToggle(String label, String itemId) {
    bool isVisible = !_hiddenItemIds.contains(itemId);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        subtitle: Text(isVisible ? 'Yayında' : 'Gizli', style: TextStyle(fontSize: 10, color: isVisible ? Colors.green : Colors.red)),
        value: isVisible,
        onChanged: (value) async {
          await _lessonsService.toggleItemHiddenStatus(itemId, !value);
          _loadAll();
        },
      ),
    );
  }
}
