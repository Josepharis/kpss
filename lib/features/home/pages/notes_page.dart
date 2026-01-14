import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class NoteData {
  final String id;
  final String text;
  final List<TextSpan> formattedText;
  final DateTime createdAt;
  final Color? backgroundColor;
  final List<String> tags;

  NoteData({
    required this.id,
    required this.text,
    required this.formattedText,
    required this.createdAt,
    this.backgroundColor,
    this.tags = const [],
  });
}

class NotesPage extends StatefulWidget {
  final String topicName;
  final int noteCount;

  const NotesPage({
    super.key,
    required this.topicName,
    required this.noteCount,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _noteController = TextEditingController();
  final List<NoteData> _notes = [];
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderline = false;
  Color _textColor = AppColors.textPrimary;
  Color _highlightColor = Colors.yellow;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _toggleBold() {
    setState(() {
      _isBold = !_isBold;
    });
  }

  void _toggleItalic() {
    setState(() {
      _isItalic = !_isItalic;
    });
  }

  void _toggleUnderline() {
    setState(() {
      _isUnderline = !_isUnderline;
    });
  }

  void _showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renk Seç'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Metin Rengi'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.orange,
                  Colors.purple,
                  Colors.pink,
                  Colors.teal,
                ].map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _textColor = color;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _textColor == color
                              ? Colors.black
                              : Colors.grey.withValues(alpha: 0.3),
                          width: _textColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Vurgulama Rengi'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Colors.yellow,
                  Colors.orange,
                  Colors.pink,
                  Colors.lightBlue,
                  Colors.lightGreen,
                  Colors.purpleAccent,
                ].map((color) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _highlightColor = color;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _highlightColor == color
                              ? Colors.black
                              : Colors.grey.withValues(alpha: 0.3),
                          width: _highlightColor == color ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showEmojiPickerDialog() {
    final emojis = [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
      '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍', '🤩',
      '😘', '😗', '😚', '😙', '😋', '😛', '😜', '🤪',
      '📝', '📌', '📍', '✅', '❌', '⭐', '🔥', '💡',
      '📚', '📖', '📋', '📄', '📊', '📈', '📉', '🎯',
      '💪', '🎓', '🏆', '🎖️', '⭐', '🌟', '✨', '💫',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emoji Seç'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: emojis.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  final text = _noteController.text;
                  final selection = _noteController.selection;
                  final newText = text.replaceRange(
                    selection.start,
                    selection.end,
                    emojis[index],
                  );
                  _noteController.text = newText;
                  _noteController.selection = TextSelection.collapsed(
                    offset: selection.start + emojis[index].length,
                  );
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      emojis[index],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _insertIcon(String icon) {
    final text = _noteController.text;
    final selection = _noteController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      icon,
    );
    _noteController.text = newText;
    _noteController.selection = TextSelection.collapsed(
      offset: selection.start + icon.length,
    );
  }

  void _saveNote() {
    if (_noteController.text.trim().isNotEmpty) {
      final formattedText = _buildFormattedText(_noteController.text);
      final note = NoteData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: _noteController.text,
        formattedText: formattedText,
        createdAt: DateTime.now(),
      );

      setState(() {
        _notes.insert(0, note);
        _noteController.clear();
        _isBold = false;
        _isItalic = false;
        _isUnderline = false;
        _textColor = AppColors.textPrimary;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Not kaydedildi'),
            ],
          ),
          backgroundColor: AppColors.gradientGreenStart,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  List<TextSpan> _buildFormattedText(String text) {
    // Basit formatting - gerçek uygulamada daha gelişmiş parsing gerekir
    final spans = <TextSpan>[];
    final parts = text.split(RegExp(r'(\*\*.*?\*\*|_.*?_|~~.*?~~)'));
    
    for (var part in parts) {
      TextStyle style = TextStyle(
        color: _textColor,
        fontSize: 16,
      );

      if (part.startsWith('**') && part.endsWith('**')) {
        part = part.substring(2, part.length - 2);
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (part.startsWith('_') && part.endsWith('_')) {
        part = part.substring(1, part.length - 1);
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (part.startsWith('~~') && part.endsWith('~~')) {
        part = part.substring(2, part.length - 2);
        style = style.copyWith(
          decoration: TextDecoration.lineThrough,
        );
      }

      spans.add(TextSpan(text: part, style: style));
    }

    return spans.isEmpty ? [TextSpan(text: text)] : spans;
  }

  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu Sil'),
        content: const Text('Bu notu silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _notes.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen ? 80 : 90),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gradientGreenStart,
                      AppColors.gradientGreenEnd,
                    ],
                  ),
            color: isDark ? const Color(0xFF1E1E1E) : null,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : AppColors.gradientGreenStart.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -10,
                  right: -10,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'NOTLAR',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.08),
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Notlar',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              widget.topicName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Formatting Toolbar
          Container(
            margin: EdgeInsets.fromLTRB(
              isTablet ? 20 : 16,
              isSmallScreen ? 12 : 16,
              isTablet ? 20 : 16,
              0,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.format_bold_rounded,
                    isActive: _isBold,
                    onTap: _toggleBold,
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.format_italic_rounded,
                    isActive: _isItalic,
                    onTap: _toggleItalic,
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.format_underlined_rounded,
                    isActive: _isUnderline,
                    onTap: _toggleUnderline,
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.palette_rounded,
                    isActive: false,
                    onTap: _showColorPickerDialog,
                    isSmallScreen: isSmallScreen,
                    color: _textColor,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.highlight_rounded,
                    isActive: false,
                    onTap: () {
                      // Highlight functionality
                    },
                    isSmallScreen: isSmallScreen,
                    color: _highlightColor,
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.mood_rounded,
                    isActive: false,
                    onTap: _showEmojiPickerDialog,
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.tag_rounded,
                    isActive: false,
                    onTap: () {
                      _insertIcon('🏷️ ');
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.star_rounded,
                    isActive: false,
                    onTap: () {
                      _insertIcon('⭐ ');
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  _buildToolbarButton(
                    context: context,
                    icon: Icons.check_circle_rounded,
                    isActive: false,
                    onTap: () {
                      _insertIcon('✅ ');
                    },
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            ),
          ),
          // Note Input Section
          Container(
            margin: EdgeInsets.fromLTRB(
              isTablet ? 20 : 16,
              isSmallScreen ? 12 : 16,
              isTablet ? 20 : 16,
              isSmallScreen ? 12 : 16,
            ),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gradientGreenStart.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientGreenStart.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.gradientGreenStart,
                            AppColors.gradientGreenEnd,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: isSmallScreen ? 20 : 22,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Text(
                        'Yeni Not Ekle',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                TextField(
                  controller: _noteController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Notunuzu buraya yazın...\n\nİpuçları:\n• **kalın** için **metin**\n• _italik_ için _metin_\n• ~~üstü çizili~~ için ~~metin~~',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade500 : AppColors.textSecondary,
                      fontSize: isSmallScreen ? 13 : 14,
                      height: 1.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2C2C) : AppColors.backgroundLight,
                    contentPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  ),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 15 : 17,
                    color: _textColor,
                    fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                    decoration: _isUnderline
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gradientGreenStart,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 14 : 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.save_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Notes List
          Expanded(
            child: _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.gradientGreenStart.withValues(alpha: 0.1),
                                AppColors.gradientGreenEnd.withValues(alpha: 0.05),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.note_add_outlined,
                            size: isSmallScreen ? 64 : 80,
                            color: AppColors.gradientGreenStart,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Text(
                          'Henüz not eklenmedi',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 10),
                        Text(
                          'İlk notunuzu ekleyerek başlayın',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: isDark ? Colors.grey.shade500 : AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(
                      left: isTablet ? 20 : 16,
                      right: isTablet ? 20 : 16,
                      bottom: isSmallScreen ? 16 : 20,
                    ),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return Container(
                        margin: EdgeInsets.only(
                          bottom: isSmallScreen ? 12 : 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              isDark ? const Color(0xFF1A1A1A) : Colors.grey.withValues(alpha: 0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.gradientGreenStart.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gradientGreenStart.withValues(alpha: 0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.gradientGreenStart,
                                          AppColors.gradientGreenEnd,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  SizedBox(width: isSmallScreen ? 12 : 16),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: note.formattedText,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 15 : 17,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton(
                                    icon: Icon(
                                      Icons.more_vert_rounded,
                                      color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                                      size: isSmallScreen ? 20 : 22,
                                    ),
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            const Text('Sil'),
                                          ],
                                        ),
                                        onTap: () {
                                          Future.delayed(
                                            Duration.zero,
                                            () => _deleteNote(index),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                isSmallScreen ? 16 : 20,
                                0,
                                isSmallScreen ? 16 : 20,
                                isSmallScreen ? 12 : 16,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: isSmallScreen ? 12 : 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 12,
                                      color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required BuildContext context,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isSmallScreen,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.gradientGreenStart.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(
                    color: AppColors.gradientGreenStart.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 20 : 22,
            color: color ?? (isActive
                ? AppColors.gradientGreenStart
                : (isDark ? Colors.white : AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}
