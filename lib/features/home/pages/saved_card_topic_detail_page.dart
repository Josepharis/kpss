import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
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
        statusBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark, // Android
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // iOS
        systemNavigationBarColor: isDark
            ? const Color(0xFF141414)
            : Colors.white,
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
            _buildMeshBackground(isDark, screenWidth),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_savedCards.isEmpty)
              _buildEmptyState(isDark)
            else
              Column(
                children: [
                  SizedBox(height: statusBarHeight + 60),
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
              bottom: -screenWidth * 0.4,
              right: -screenWidth * 0.2,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: isDark
                    ? const Color(0xFFBE185D).withOpacity(0.15)
                    : const Color(0xFFFBCFE8).withOpacity(0.2),
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
                  widget.topicName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (!_isLoading && _savedCards.isNotEmpty)
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
                    '${_currentCardIndex + 1}/${_savedCards.length}',
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
          Icon(
            Icons.style_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Bu konuda kaydedilmiş kart yok',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF7E93),
            const Color(0xFFF43F5E),
            const Color(0xFFBE123C),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBE123C).withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Fully visible watermark - Top Right
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.2),
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
                            color: Colors.black.withOpacity(0.15),
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
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
                        color: Colors.white.withOpacity(0.2),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF34D399),
            const Color(0xFF10B981),
            const Color(0xFF059669),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Fully visible watermark - Top Right
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kartı çevir',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
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
          _buildGlassButton(
            icon: Icons.arrow_back_rounded,
            onTap: _previousCard,
            isDark: isDark,
            enabled: _currentCardIndex > 0,
          ),

          const Spacer(),

          GestureDetector(
            onTap: _removeCard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kaldır',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          _buildGlassButton(
            icon: Icons.arrow_forward_rounded,
            onTap: _nextCard,
            isDark: isDark,
            enabled: _currentCardIndex < _savedCards.length - 1,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    bool enabled = true,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.3,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: isPrimary
                ? Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? AppColors.primaryBlue
                : (isDark ? Colors.white : Colors.black87),
            size: 26,
          ),
        ),
      ),
    );
  }
}
