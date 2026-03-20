import 'package:flutter/material.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/global_admin_sync_service.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/topic.dart';

class AdminDetailedSyncPage extends StatefulWidget {
  const AdminDetailedSyncPage({super.key});

  @override
  State<AdminDetailedSyncPage> createState() => _AdminDetailedSyncPageState();
}

class _AdminDetailedSyncPageState extends State<AdminDetailedSyncPage> {
  final LessonsService _lessonsService = LessonsService();
  final GlobalAdminSyncService _syncService = GlobalAdminSyncService();

  List<Lesson> _lessons = [];
  List<Topic> _topics = [];
  
  Lesson? _selectedLesson;
  Topic? _selectedTopic;
  
  bool _isLoadingLessons = true;
  bool _isLoadingTopics = false;
  bool _isSyncing = false;

  // Premium Sync Options
  bool _syncTests = true;
  bool _syncPdfs = true;
  bool _syncPodcasts = true;
  bool _syncNotes = true;
  bool _syncFlashCards = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoadingLessons = true);
    final lessons = await _lessonsService.getAllLessons();
    setState(() {
      _lessons = lessons;
      _isLoadingLessons = false;
    });
  }

  Future<void> _loadTopics(String lessonId) async {
    setState(() {
      _topics = [];
      _selectedTopic = null;
      _isLoadingTopics = true;
    });
    
    final topics = await _lessonsService.getTopicsByLessonId(lessonId);
    setState(() {
      _topics = topics;
      _isLoadingTopics = false;
    });
  }

  Future<void> _handleSync() async {
    if (_selectedLesson == null) return;

    setState(() => _isSyncing = true);
    
    try {
      if (_selectedTopic != null) {
        await _syncService.syncTopic(
          _selectedLesson!.id, 
          _selectedTopic!.id,
          syncTests: _syncTests,
          syncPdfs: _syncPdfs,
          syncPodcasts: _syncPodcasts,
          syncNotes: _syncNotes,
          syncFlashCards: _syncFlashCards,
        );
      } else {
        // Full lesson sync
        await _syncService.syncLesson(
          _selectedLesson!.id,
          syncTests: _syncTests,
          syncPdfs: _syncPdfs,
          syncPodcasts: _syncPodcasts,
          syncNotes: _syncNotes,
          syncFlashCards: _syncFlashCards,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Senkronizasyon başarıyla tamamlandı!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Hata oluştu: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A12) : const Color(0xFFF0F2F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Kapsam Belirle', Icons.layers_outlined),
                  const SizedBox(height: 16),
                  _buildPremiumCard(
                    child: Column(
                      children: [
                        _buildDropdown<Lesson>(
                          label: 'Ders',
                          value: _selectedLesson,
                          hint: 'Bir ders seçin',
                          items: _lessons,
                          loading: _isLoadingLessons,
                          onChanged: (val) {
                            setState(() => _selectedLesson = val);
                            if (val != null) _loadTopics(val.id);
                          },
                          itemBuilder: (l) => l.name,
                        ),
                        const Divider(height: 32),
                        _buildDropdown<Topic>(
                          label: 'Ünite',
                          value: _selectedTopic,
                          hint: _selectedLesson == null ? 'Önce ders seçin' : 'Tüm Üniteler',
                          items: _topics,
                          loading: _isLoadingTopics,
                          enabled: _selectedLesson != null,
                          onChanged: (val) => setState(() => _selectedTopic = val),
                          itemBuilder: (t) => t.name,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('İçerik Türleri', Icons.tune_rounded),
                  const SizedBox(height: 16),
                  _buildPremiumCard(
                    child: Column(
                      children: [
                        _buildSyncToggle('Soru Bankası / Testler', Icons.quiz_outlined, _syncTests, (v) => setState(() => _syncTests = v)),
                        _buildSyncToggle('Konu Anlatımı (PDF)', Icons.picture_as_pdf_outlined, _syncPdfs, (v) => setState(() => _syncPdfs = v)),
                        _buildSyncToggle('Podcast / Sesler', Icons.mic_none_rounded, _syncPodcasts, (v) => setState(() => _syncPodcasts = v)),
                        _buildSyncToggle('Ders Notları', Icons.description_outlined, _syncNotes, (v) => setState(() => _syncNotes = v)),
                        _buildSyncToggle('Bilgi Kartları', Icons.style_outlined, _syncFlashCards, (v) => setState(() => _syncFlashCards = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Premium Sync',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required String hint,
    required List<T> items,
    required bool loading,
    bool enabled = true,
    required Function(T?) onChanged,
    required String Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
        const SizedBox(height: 8),
        loading 
          ? const LinearProgressIndicator(minHeight: 2)
          : DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                hint: Text(hint, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                disabledHint: Text(hint, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                items: items.map((i) => DropdownMenuItem<T>(
                  value: i,
                  child: Text(itemBuilder(i), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                )).toList(),
                onChanged: enabled ? onChanged : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6366F1)),
              ),
            ),
      ],
    );
  }

  Widget _buildSyncToggle(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Switch.adaptive(
            value: value,
            activeColor: const Color(0xFF6366F1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    bool canSync = _selectedLesson != null && !_isSyncing;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
              shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
            ),
            onPressed: canSync ? _handleSync : null,
            child: _isSyncing 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'SENKRONİZASYONU BAŞLAT',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
          ),
        ),
        if (_selectedLesson != null && _selectedTopic == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Bu işlem "${_selectedLesson!.name}" dersindeki tüm üniteleri kapsar.',
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
