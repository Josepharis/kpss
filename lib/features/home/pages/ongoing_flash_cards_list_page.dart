import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_flash_card.dart';
import '../../../core/services/progress_service.dart';
import '../../../../main.dart';
import 'flash_cards_page.dart';

class OngoingFlashCardsListPage extends StatefulWidget {
  final List<OngoingFlashCard> flashCards;

  const OngoingFlashCardsListPage({super.key, required this.flashCards});

  @override
  State<OngoingFlashCardsListPage> createState() =>
      _OngoingFlashCardsListPageState();
}

class _OngoingFlashCardsListPageState extends State<OngoingFlashCardsListPage> {
  final ProgressService _progressService = ProgressService();
  late List<OngoingFlashCard> _flashCards;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _flashCards = List<OngoingFlashCard>.from(widget.flashCards);
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_flashCards.map((f) => f.toMap()).toList());
      await prefs.setString('ongoing_flash_cards_cache', jsonStr);
    } catch (_) {
      // silent
    }
  }

  Future<bool> _confirmReset(OngoingFlashCard flashCard) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E2E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'İlerleme sıfırlansın mı?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${flashCard.topic}" için kaldığın yer silinecek.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Vazgeç',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sıfırla',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _resetFlashCard(OngoingFlashCard flashCard) async {
    final confirmed = await _confirmReset(flashCard);
    if (!confirmed) return;

    await _progressService.deleteFlashCardProgress(
      flashCard.topicId,
      flashCard.lessonId,
    );
    if (!mounted) return;

    setState(() {
      _flashCards.removeWhere((f) => f.topicId == flashCard.topicId);
      _didChange = true;
    });
    await _saveToCache();

    if (!mounted) return;
    MainScreen.of(context)?.refreshHomePage();
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
                SizedBox(height: statusBarHeight + 70),
                Expanded(
                  child: _flashCards.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          itemCount: _flashCards.length,
                          itemBuilder: (context, index) {
                            final flashCard = _flashCards[index];
                            return _buildUltraCompactCard(flashCard, isDark);
                          },
                        ),
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
                onTap: () => Navigator.of(context).pop(_didChange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Devam Eden Kartlar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
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
                  : Colors.green.withOpacity(0.05),
            ),
            child: Icon(
              Icons.style_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.green.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Devam eden çalışma yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltraCompactCard(OngoingFlashCard flashCard, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.white.withOpacity(0.8),
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
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashCardsPage(
                    topicName: flashCard.topic,
                    cardCount: flashCard.totalCards,
                    topicId: flashCard.topicId,
                    lessonId: flashCard.lessonId,
                  ),
                ),
              );
              if (!context.mounted) return;
              if (result == true) {
                MainScreen.of(context)?.refreshHomePage();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.gradientGreenStart,
                          AppColors.gradientGreenEnd,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gradientGreenStart.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_lesson_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flashCard.topic,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: flashCard.progress,
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.gradientGreenStart,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '%${(flashCard.progress * 100).toInt()} Tamamlandı',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gradientGreenStart,
                              ),
                            ),
                            Text(
                              '${flashCard.currentCard}/${flashCard.totalCards}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _resetFlashCard(flashCard),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: isDark ? Colors.white38 : Colors.black26,
                      size: 22,
                    ),
                    tooltip: 'Sıfırla',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
