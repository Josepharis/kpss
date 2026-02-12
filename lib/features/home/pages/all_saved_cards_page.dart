import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/saved_cards_service.dart';
import '../../../core/widgets/premium_snackbar.dart';

class AllSavedCardsPage extends StatefulWidget {
  final String? lessonId;
  final String? lessonName;

  const AllSavedCardsPage({super.key, this.lessonId, this.lessonName});

  @override
  State<AllSavedCardsPage> createState() => _AllSavedCardsPageState();
}

class _AllSavedCardsPageState extends State<AllSavedCardsPage> {
  List<SavedCard> _savedCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    setState(() => _isLoading = true);
    try {
      final cards = widget.lessonId != null
          ? await SavedCardsService.getSavedCardsByLesson(widget.lessonId!)
          : await SavedCardsService.getAllSavedCards();

      if (mounted) {
        setState(() {
          _savedCards = cards;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSavedCard(SavedCard card) async {
    try {
      await SavedCardsService.removeSavedCard(card.id, card.topicId);
      setState(() {
        _savedCards.removeWhere(
          (c) => c.id == card.id && c.topicId == card.topicId,
        );
      });
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Kart kaydedilenlerden kaldırıldı',
          type: SnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Kart silinirken bir hata oluştu',
          type: SnackBarType.error,
        );
      }
    }
  }

  void _showDeleteConfirmation(SavedCard card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Kartı Sil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bu kartı kaydedilenlerden kaldırmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSavedCard(card);
            },
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark, // Android
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
        systemNavigationBarColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            // Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // Content
            Column(
              children: [
                SizedBox(height: statusBarHeight + 70), // Header space
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _savedCards.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildCardsList(isDark),
                ),
              ],
            ),

            // Custom Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildCustomHeader(context, isDark, statusBarHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D0221),
                    const Color(0xFF0F0F1A),
                    const Color(0xFF19102E),
                  ]
                : [const Color(0xFFF0F4FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -screenWidth * 0.4,
              left: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: isDark
                    ? const Color(0xFF4C1D95).withOpacity(0.15)
                    : const Color(0xFFC4B5FD).withOpacity(0.2),
              ),
            ),
            Positioned(
              top: 200,
              right: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.0,
                color: isDark
                    ? const Color(0xFFBE185D).withOpacity(0.1)
                    : const Color(0xFFFBCFE8).withOpacity(0.2),
              ),
            ),
            Positioned(
              bottom: -100,
              left: 50,
              child: _buildBlurCircle(
                size: screenWidth * 0.8,
                color: isDark
                    ? const Color(0xFF0F766E).withOpacity(0.1)
                    : const Color(0xFFCCFBF1).withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.5,
          colors: [color, color.withOpacity(0)],
          stops: const [0.1, 1.0],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildCustomHeader(
    BuildContext context,
    bool isDark,
    double statusBarHeight,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            top: statusBarHeight + 10,
            bottom: 12,
            left: 20,
            right: 20,
          ),
          color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
          child: Row(
            children: [
              _buildGlassIconButton(
                context,
                icon: Icons.arrow_back_ios_new_rounded,
                isDark: isDark,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.lessonName ?? 'Kaydedilen Kartlar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_savedCards.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
    BuildContext context, {
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
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
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.blue.withOpacity(0.05),
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.blue.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz kaydedilmiş kart yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Beğendiğiniz kartları kaydettiğinizde\nburada görünecekler.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _savedCards.length,
      itemBuilder: (context, index) {
        final card = _savedCards[index];
        return _buildCardItem(context, card, isDark);
      },
    );
  }

  Widget _buildCardItem(BuildContext context, SavedCard card, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header of the card (Topic Name)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.library_books_rounded,
                        size: 14,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        card.topicName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _showDeleteConfirmation(card),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content (Question & Answer)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.gradientRedStart,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            card.frontText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'C:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            card.backText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
