import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic_note.dart';
import '../../../core/services/topic_notes_service.dart';
import '../../../core/widgets/premium_snackbar.dart';
import 'package:intl/intl.dart';

class NotesPage extends StatefulWidget {
  final String topicName;
  final String topicId;
  final int noteCount;

  const NotesPage({
    super.key,
    required this.topicName,
    required this.topicId,
    required this.noteCount,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TopicNotesService _notesService = TopicNotesService.instance;
  List<TopicNote> _notes = [];
  List<TopicNote> _filteredNotes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _notesService.getNotesForTopic(widget.topicId);
    if (mounted) {
      setState(() {
        _notes = notes..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _filterNotes();
        _isLoading = false;
      });
    }
  }

  void _filterNotes() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _filteredNotes = List.from(_notes);
      } else {
        _filteredNotes = _notes
            .where(
              (note) =>
                  note.title.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  note.content.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
            )
            .toList();
      }
    });
  }

  void _addOrEditNote([TopicNote? note]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _NoteEditorSheet(topicId: widget.topicId, note: note),
    );

    if (result == true) {
      _loadNotes();
    }
  }

  void _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu Sil'),
        content: const Text('Bu notu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notesService.deleteNote(noteId);
      _loadNotes();
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Not silindi',
          type: SnackBarType.info,
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
          ? const Color(0xFF0F0F1A)
          : const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Background ornaments
          _buildBackgroundOrnaments(isDark, screenWidth),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isDark, isTablet),
                _buildSearchBar(isDark, isTablet),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredNotes.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildNotesGrid(isDark, isTablet),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditNote(),
        backgroundColor: AppColors.gradientGreenStart,
        label: const Text(
          'Yeni Not',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        elevation: 6,
      ),
    );
  }

  Widget _buildBackgroundOrnaments(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gradientGreenStart.withOpacity(
                  isDark ? 0.05 : 0.08,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(isDark ? 0.05 : 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textPrimary,
              size: 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: (isDark ? Colors.white : Colors.black)
                  .withOpacity(0.05),
              padding: const EdgeInsets.all(10),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTLARIM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gradientGreenStart,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  widget.topicName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1E1E2D) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
              _filterNotes();
            });
          },
          decoration: InputDecoration(
            hintText: 'Notlarda ara...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.gradientGreenStart,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _filterNotes();
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.gradientGreenStart.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_alt_outlined,
              size: 80,
              color: AppColors.gradientGreenStart,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz not yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu konuyla ilgili ilk notunu alarak\nçalışmanı pekiştir!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid(bool isDark, bool isTablet) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _filteredNotes.length,
      itemBuilder: (context, index) {
        final note = _filteredNotes[index];
        return _NoteCard(
          note: note,
          onTap: () => _addOrEditNote(note),
          onDelete: () => _deleteNote(note.id),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final TopicNote note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: note.colorValue == 0xFFFFFFFF
            ? (isDark ? const Color(0xFF1E1E2D) : Colors.white)
            : Color(note.colorValue).withOpacity(isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: note.colorValue == 0xFFFFFFFF
              ? (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.03))
              : Color(note.colorValue).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? 'Başlıksız Not' : note.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.isPinned)
                      Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: AppColors.gradientGreenStart,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    note.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd MMM').format(note.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 14,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteEditorSheet extends StatefulWidget {
  final String topicId;
  final TopicNote? note;

  const _NoteEditorSheet({required this.topicId, this.note});

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late int _selectedColor;
  late bool _isPinned;
  final TopicNotesService _notesService = TopicNotesService.instance;

  final List<int> _colors = [
    0xFFFFFFFF, // Default
    0xFFF44336, // Red
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFFC107, // Amber
    0xFF9C27B0, // Purple
    0xFFE91E63, // Pink
    0xFF00BCD4, // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _selectedColor = widget.note?.colorValue ?? 0xFFFFFFFF;
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_contentController.text.trim().isEmpty &&
        _titleController.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    final newNote = TopicNote(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      topicId: widget.topicId,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      colorValue: _selectedColor,
      isPinned: _isPinned,
    );

    await _notesService.saveNote(newNote);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161625) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Toolbar / Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Notu Düzenle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isPinned = !_isPinned;
                    });
                  },
                  icon: Icon(
                    _isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: _isPinned
                        ? AppColors.gradientGreenStart
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gradientGreenStart,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text(
                    'Bitti',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Color picker
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _colors.length,
              itemBuilder: (context, index) {
                final color = _colors[index];
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.gradientGreenStart
                            : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.blueGrey,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Inputs
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 20),
              child: ListView(
                children: [
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Başlık',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Notunuzu buraya yazın...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
