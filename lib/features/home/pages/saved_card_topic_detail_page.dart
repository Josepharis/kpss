import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/saved_cards_service.dart';

class SavedCardTopicDetailPage extends StatefulWidget {
  final Lesson lesson;
  final String topicName;

  const SavedCardTopicDetailPage({
    super.key,
    required this.lesson,
    required this.topicName,
  });

  @override
  State<SavedCardTopicDetailPage> createState() =>
      _SavedCardTopicDetailPageState();
}

class _SavedCardTopicDetailPageState extends State<SavedCardTopicDetailPage>
    with SingleTickerProviderStateMixin {
  List<SavedCard> _savedCards = [];
  bool _isLoading = true;
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadSavedCards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCards() async {
    setState(() => _isLoading = true);
    try {
      final allCards = await SavedCardsService.getSavedCardsByTopic(
        widget.topicName,
      );
      final filteredCards = allCards
          .where((c) => c.lessonId == widget.lesson.id)
          .toList();

      if (mounted) {
        setState(() {
          _savedCards = filteredCards;
          _isLoading = false;
          _currentCardIndex = 0;
          _isFlipped = false;
          _flipController.reset();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _isFlipped = false;
        _flipController.reset();
      });
    }
  }

  void _nextCard() {
    if (_currentCardIndex < _savedCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFlipped = false;
        _flipController.reset();
      });
    }
  }

  Future<void> _removeCard() async {
    if (_savedCards.isEmpty || _currentCardIndex >= _savedCards.length) return;
    final currentCard = _savedCards[_currentCardIndex];
    final success = await SavedCardsService.removeSavedCard(
      currentCard.id,
      currentCard.topicId,
    );

    if (mounted && success) {
      setState(() {
        _savedCards.removeAt(_currentCardIndex);
        if (_currentCardIndex >= _savedCards.length && _savedCards.isNotEmpty) {
          _currentCardIndex = _savedCards.length - 1;
        } else if (_savedCards.isEmpty) {
          _currentCardIndex = 0;
        }
        _isFlipped = false;
        _flipController.reset();
      });
      PremiumSnackBar.show(
        context,
        message: 'Kart kaydedilenlerden kaldırıldı.',
        type: SnackBarType.success,
      );
      if (_savedCards.isEmpty) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
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

            if (_isLoading)
              _buildLoader(isDark)
            else if (_savedCards.isEmpty)
              _buildEmptyState(isDark)
            else
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    _buildPremiumHeader(context, isDark, statusBarHeight),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isVerySmall = constraints.maxWidth < 360;
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 20,
                              vertical: isSmallScreen ? 8 : 16,
                            ),
                            child: GestureDetector(
                              onTap: _flipCard,
                              child: AnimatedBuilder(
                                animation: _flipAnimation,
                                builder: (context, child) {
                                  final angle = _flipAnimation.value * 3.14159;
                                  final isFrontVisible =
                                      _flipAnimation.value < 0.5;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(angle),
                                    child: isFrontVisible
                                        ? _buildCardFront(
                                            _savedCards[_currentCardIndex],
                                            isSmallScreen,
                                            isVerySmall,
                                          )
                                        : Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..rotateY(3.14159),
                                            child: _buildCardBack(
                                              _savedCards[_currentCardIndex],
                                              isSmallScreen,
                                              isVerySmall,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildBottomControls(isDark, bottomPadding, isSmallScreen),
                  ],
                ),
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
                    ? const Color(0xFF4C1D95).withValues(alpha: 0.15)
                    : const Color(0xFFC4B5FD).withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -50,
              child: _buildBlurCircle(
                size: screenWidth * 0.8,
                color: isDark
                    ? const Color(0xFFBE185D).withValues(alpha: 0.1)
                    : const Color(0xFFFBCFE8).withValues(alpha: 0.2),
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
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.1, 1.0],
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildPremiumHeader(
    BuildContext context,
    bool isDark,
    double statusBarHeight,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, statusBarHeight + 8, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 1. Back Button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 2. Center Title
          Expanded(
            child: Text(
              widget.topicName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // 3. Counter Badge
          if (_savedCards.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${_currentCardIndex + 1}/${_savedCards.length}',
                style: const TextStyle(
                  color: Color(0xFF0369A1),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoader(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: isDark ? const Color(0xFF4F46E5) : const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.style_outlined,
                size: 60,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Kaydedilen Kart Yok',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu konuda henüz kaydedilmiş kartınız bulunmuyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFront(SavedCard card, bool isSmallScreen, bool isVerySmall) {
    final textLength = card.frontText.length;
    double baseFontSize = isVerySmall ? 18 : (isSmallScreen ? 24 : 30);
    if (textLength > 100) baseFontSize -= 4;
    if (textLength > 200) baseFontSize -= 4;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7E93), Color(0xFFF43F5E), Color(0xFFBE123C)],
          stops: [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBE123C).withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      card.frontText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cevabı Gör',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(SavedCard card, bool isSmallScreen, bool isVerySmall) {
    final textLength = card.backText.length;
    double baseFontSize = isVerySmall ? 18 : (isSmallScreen ? 22 : 28);
    if (textLength > 100) baseFontSize -= 4;
    if (textLength > 200) baseFontSize -= 4;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      card.backText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kartı çevir',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    bool isDark,
    double bottomPadding,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: _previousCard,
            isDark: isDark,
            enabled: _currentCardIndex > 0,
          ),
          const Spacer(),
          _buildActionChip(
            icon: Icons.delete_outline_rounded,
            label: 'Kaldır',
            onTap: _removeCard,
            color: const Color(0xFFEF4444),
            isDark: isDark,
          ),
          const Spacer(),
          _buildControlIconButton(
            icon: Icons.arrow_forward_rounded,
            onTap: _nextCard,
            isDark: isDark,
            enabled: _currentCardIndex < _savedCards.length - 1,
          ),
        ],
      ),
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
            boxShadow: [
              if (enabled) ...[
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 0,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
              ],
            ],
            border: Border.all(
              color: Colors.black.withOpacity(0.04),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(icon, color: const Color(0xFF1E293B), size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.9), color, color.withOpacity(1.0)],
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
