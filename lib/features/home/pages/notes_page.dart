
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/topic_note.dart';
import '../../../core/services/topic_notes_service.dart';
import '../../../core/widgets/premium_snackbar.dart';

class NotesPage extends StatefulWidget {
  final String topicId;
  final String topicTitle;

  const NotesPage({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TopicNotesService _notesService = TopicNotesService.instance;
  List<TopicNote> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    final notes = await _notesService.getNotesForTopic(widget.topicId);
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  void _showEditor([TopicNote? note]) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NoteEditorSheet(
        topicId: widget.topicId,
        note: note,
      ),
    );

    if (result == true) {
      _loadNotes();
    }
  }

  void _deleteNote(String noteId) async {
    await _notesService.deleteNote(noteId);
    _loadNotes();
    if (mounted) {
      PremiumSnackBar.show(
        context,
        message: 'Not silindi',
        type: SnackBarType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOTLARIM',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.gradientGreenStart,
                letterSpacing: 2,
              ),
            ),
            Text(
              widget.topicTitle,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, 
            color: isDark ? Colors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState()
              : _buildNotesGrid(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.gradientGreenStart.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_add_outlined,
              size: 80,
              color: AppColors.gradientGreenStart.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz not eklenmemiş',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Çalışırken aldığın notları burada saklayabilirsin.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _NoteCard(
          note: note,
          onTap: () => _showEditor(note),
          onDelete: () => _deleteNote(note.id),
        );
      },
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientGreenStart.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        backgroundColor: AppColors.gradientGreenStart,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Not Ekle',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
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
    final isWhite = note.colorValue == 0xFFFFFFFF;

    return Container(
      decoration: BoxDecoration(
        color: isWhite
            ? (isDark ? const Color(0xFF1E1E2D) : Colors.white)
            : Color(note.colorValue).withOpacity(isDark ? 0.3 : 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWhite
              ? (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02))
              : Color(note.colorValue).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isWhite ? Colors.black : Color(note.colorValue)).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: _PaperBackground(
          style: note.paperStyle,
          color: Colors.transparent,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: AppColors.gradientGreenStart,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Başlıksız Not' : note.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isWhite ? (isDark ? Colors.white : AppColors.textPrimary) : note.textColor,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        note.content,
                        style: GoogleFonts.outfit(
                          fontSize: (note.fontSize * 0.8).clamp(11.0, 14.0),
                          color: isWhite 
                            ? (isDark ? Colors.white.withOpacity(0.7) : AppColors.textSecondary)
                            : note.textColor.withOpacity(0.85),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            DateFormat('dd.MM.yyyy').format(note.createdAt),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: isWhite 
                                ? (isDark ? Colors.white38 : Colors.black45)
                                : note.textColor.withOpacity(0.5),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildActionCircle(
                          icon: Icons.delete_outline_rounded,
                          color: isWhite ? Colors.red : note.textColor,
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: color.withOpacity(0.8),
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
  late quill.QuillController _quillController;
  late int _selectedColor;
  late int _textColor;
  late double _fontSize;
  late String _paperStyle;
  late bool _isPinned;
  final TopicNotesService _notesService = TopicNotesService.instance;

  int _currentToolIndex = 0; // 0: Page Color, 1: Text Style, 2: Paper Style

  final List<int> _colors = [
    0xFFFFFFFF, // White
    0xFFF8F9FA, // Light Gray
    0xFFE3F2FD, // Soft Blue
    0xFFE8F5E9, // Soft Green
    0xFFFDEDEB, // Soft Red
    0xFFFFF9DB, // Soft Yellow
    0xFFF3E5F5, // Soft Purple
    0xFFE0F2F1, // Soft Teal
    0xFFECEFF1, // Blue Gray
  ];

  final List<int> _textColors = [
    0xFF212121, // Black
    0xFF424242, // Dark Gray
    0xFF757575, // Medium Gray
    0xFFFFFFFF, // White
    0xFFF44336, // Red
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFFC107, // Amber
    0xFF9C27B0, // Purple
  ];

  final List<Map<String, dynamic>> _paperStyles = [
    {'id': 'plain', 'icon': Icons.crop_free_rounded, 'label': 'Düz'},
    {'id': 'lined', 'icon': Icons.reorder_rounded, 'label': 'Çizgili'},
    {'id': 'grid', 'icon': Icons.grid_4x4_rounded, 'label': 'Kareli'},
    {'id': 'dots', 'icon': Icons.more_horiz_rounded, 'label': 'Noktalı'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    
    if (widget.note?.contentJson != null && widget.note!.contentJson!.isNotEmpty) {
      try {
        final json = jsonDecode(widget.note!.contentJson!);
        _quillController = quill.QuillController(
          document: quill.Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _quillController = quill.QuillController.basic();
      }
    } else {
      _quillController = quill.QuillController.basic();
      if (widget.note?.content != null && widget.note!.content.isNotEmpty) {
        _quillController.document.insert(0, widget.note!.content);
      }
    }

    _selectedColor = widget.note?.colorValue ?? 0xFFFFFFFF;
    _textColor = widget.note?.textColorValue ?? 0xFF000000;
    _fontSize = widget.note?.fontSize ?? 16.0;
    _paperStyle = widget.note?.paperStyle ?? 'plain';
    _isPinned = widget.note?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  void _save() async {
    final plainText = _quillController.document.toPlainText().trim();
    final jsonContent = jsonEncode(_quillController.document.toDelta().toJson());

    if (plainText.isEmpty && _titleController.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }

    final newNote = TopicNote(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      topicId: widget.topicId,
      title: _titleController.text.trim(),
      content: plainText,
      contentJson: jsonContent,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      colorValue: _selectedColor,
      textColorValue: _textColor,
      fontSize: _fontSize,
      paperStyle: _paperStyle,
      isPinned: _isPinned,
    );

    await _notesService.saveNote(newNote);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final backgroundColor = Color(_selectedColor);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161625) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          _buildEditorHeader(),

          const Divider(height: 1),

          _buildCustomizationToolbar(isDark),

          const Divider(height: 1),

          Expanded(
            child: _PaperBackground(
              style: _paperStyle,
              color: isDark ? Colors.transparent : backgroundColor,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPadding + 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(_textColor),
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Başlık',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Color(_textColor).withOpacity(0.25),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: quill.QuillEditor.basic(
                        configurations: quill.QuillEditorConfigurations(
                          controller: _quillController,
                          placeholder: 'Bir şeyler yazmaya başla...',
                          autoFocus: false,
                          expands: true,
                          padding: EdgeInsets.zero,
                          customStyles: quill.DefaultStyles(
                            paragraph: quill.DefaultTextBlockStyle(
                              GoogleFonts.outfit(
                                fontSize: _fontSize,
                                height: 1.6,
                                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                              const quill.VerticalSpacing(0, 0),
                              const quill.VerticalSpacing(0, 0),
                              null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 20, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.note == null ? 'YENİ NOT' : 'NOTU DÜZENLE',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gradientGreenStart,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Defterim',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderAction(
            icon: _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: _isPinned ? AppColors.gradientGreenStart : Colors.grey,
            onTap: () => setState(() => _isPinned = !_isPinned),
          ),
          const SizedBox(width: 12),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientGreenStart.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gradientGreenStart,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: Text('Bitti', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildCustomizationToolbar(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolCategory(0, Icons.color_lens_rounded, 'Sayfa'),
              _buildToolCategory(1, Icons.text_fields_rounded, 'Yazı'),
              _buildToolCategory(2, Icons.sticky_note_2_rounded, 'Defter'),
            ],
          ),
        ),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: SizedBox(
            key: ValueKey(_currentToolIndex),
            height: 70,
            child: _buildSelectedToolUI(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildToolCategory(int index, IconData icon, String label) {
    final isSelected = _currentToolIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentToolIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.gradientGreenStart : Colors.grey,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              color: isSelected ? AppColors.gradientGreenStart : Colors.grey,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 12,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.gradientGreenStart,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedToolUI(bool isDark) {
    switch (_currentToolIndex) {
      case 0: return _buildPageColorPicker();
      case 1: return _buildTextStyling(isDark);
      case 2: return _buildPaperStyleSelector();
      default: return const SizedBox();
    }
  }

  Widget _buildPageColorPicker() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      scrollDirection: Axis.horizontal,
      itemCount: _colors.length,
      itemBuilder: (context, index) {
        final color = _colors[index];
        final isSelected = _selectedColor == color;
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 14),
            width: isSelected ? 46 : 38,
            decoration: BoxDecoration(
              color: Color(color),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.gradientGreenStart : Colors.grey.withOpacity(0.2),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(color: Color(color).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
              ] : [],
            ),
            child: isSelected ? const Icon(Icons.check_rounded, size: 18, color: Colors.blueGrey) : null,
          ),
        );
      },
    );
  }

  Widget _buildTextStyling(bool isDark) {
    // Cache current style once per build for significant performance boost
    final selectionStyle = _quillController.getSelectionStyle();
    final attributes = selectionStyle.attributes;
    final currentColor = attributes[quill.Attribute.color.key]?.value;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildQuillAction(quill.Attribute.bold, Icons.format_bold_rounded, attributes),
          _buildQuillAction(quill.Attribute.italic, Icons.format_italic_rounded, attributes),
          _buildQuillAction(quill.Attribute.underline, Icons.format_underlined_rounded, attributes),
          
          const VerticalDivider(indent: 15, endIndent: 15),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                  onPressed: () {
                    setState(() {
                      _fontSize = (_fontSize - 2).clamp(10.0, 50.0);
                      _quillController.formatSelection(quill.Attribute.fromKeyValue('size', '${_fontSize.toInt()}'));
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_fontSize.toInt()}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                  onPressed: () {
                    setState(() {
                      _fontSize = (_fontSize + 2).clamp(10.0, 50.0);
                      _quillController.formatSelection(quill.Attribute.fromKeyValue('size', '${_fontSize.toInt()}'));
                    });
                  },
                ),
              ],
            ),
          ),
          
          const VerticalDivider(indent: 15, endIndent: 15),
          
          ..._textColors.map((color) {
            final hexColor = '#${color.toRadixString(16).padLeft(8, '0').substring(2)}';
            final isSelected = currentColor == hexColor;

            return GestureDetector(
              onTap: () {
                _quillController.formatSelection(quill.Attribute.fromKeyValue('color', hexColor));
                setState(() {}); // Refresh to show selection
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.gradientGreenStart : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: Color(color).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                  ] : [],
                ),
                child: isSelected ? Icon(
                  Icons.check_rounded, 
                  size: 14, 
                  color: (color == 0xFFFFFFFF || color == 0xFFFFF9DB) ? Colors.black : Colors.white
                ) : null,
              ),
            );
          }).toList(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildQuillAction(quill.Attribute attribute, IconData icon, Map<String, quill.Attribute> attributes) {
    final isSelected = attributes.containsKey(attribute.key);
    return IconButton(
      icon: Icon(icon, color: isSelected ? AppColors.gradientGreenStart : Colors.grey, size: 22),
      onPressed: () {
        _quillController.formatSelection(isSelected ? quill.Attribute.clone(attribute, null) : attribute);
        setState(() {});
      },
    );
  }

  Widget _buildPaperStyleSelector() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _paperStyles.length,
      itemBuilder: (context, index) {
        final style = _paperStyles[index];
        final isSelected = _paperStyle == style['id'];
        return GestureDetector(
          onTap: () => setState(() => _paperStyle = style['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.gradientGreenStart : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.gradientGreenStart : Colors.grey.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  style['icon'] as IconData,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  style['label'] as String,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaperBackground extends StatelessWidget {
  final String style;
  final Color color;
  final Widget? child;

  const _PaperBackground({
    required this.style,
    required this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Stack(
        children: [
          if (style != 'plain')
            Positioned.fill(
              child: CustomPaint(
                painter: _PaperPainter(
                  style: style,
                  lineColor: Colors.grey.withOpacity(0.15),
                ),
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  final String style;
  final Color lineColor;
  final double spacing;

  _PaperPainter({
    required this.style,
    required this.lineColor,
    this.spacing = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (style == 'plain') return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    if (style == 'lined') {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (style == 'grid') {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (style == 'dots') {
      for (double x = spacing; x < size.width; x += spacing) {
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), 1.2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.lineColor != lineColor;
}
