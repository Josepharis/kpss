import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/flash_card.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/flash_card_cache_service.dart';
import '../../../core/services/saved_cards_service.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../../main.dart';

class FlashCardsPage extends StatefulWidget {
  final String topicName;
  final int cardCount;
  final String topicId;
  final String lessonId;

  const FlashCardsPage({
    super.key,
    required this.topicName,
    required this.cardCount,
    required this.topicId,
    required this.lessonId,
  });

  @override
  State<FlashCardsPage> createState() => _FlashCardsPageState();
}

class _FlashCardsPageState extends State<FlashCardsPage>
    with SingleTickerProviderStateMixin {
  final ProgressService _progressService = ProgressService();
  final StorageService _storageService = StorageService();
  final LessonsService _lessonsService = LessonsService();
  List<FlashCard> _cards = [];
  bool _isLoading = true;
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _cacheLoaded = false;
  Set<String> _savedCardIds = {};

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
    _initializeFlashCards();
  }

  Future<void> _initializeFlashCards() async {
    await _checkCacheImmediately();
    _loadFlashCards();
  }

  Future<void> _checkCacheImmediately() async {
    try {
      setState(() => _isLoading = true);

      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) return;

      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');

      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: widget.lessonId,
        topicId: widget.topicId,
        lessonNameForPath: lessonNameForPath,
      );
      final storagePath = '$basePath/bilgikarti';

      List<Map<String, String>> files = [];
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'flash_cards_files_${widget.topicId}';
      final cacheTimeKey = 'flash_cards_files_time_${widget.topicId}';
      final cachedJson = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(cacheTimeKey);

      const cacheValidDuration = Duration(days: 7);
      final now = DateTime.now().millisecondsSinceEpoch;
      final isCacheValid =
          cacheTime != null &&
          (now - cacheTime) < cacheValidDuration.inMilliseconds;

      if (cachedJson != null && cachedJson.isNotEmpty && isCacheValid) {
        try {
          final List<dynamic> cachedList = jsonDecode(cachedJson);
          files = cachedList
              .map(
                (json) => {
                  'name': (json['name'] ?? '') as String,
                  'fullPath': (json['fullPath'] ?? '') as String,
                  'url': (json['url'] ?? '') as String,
                },
              )
              .cast<Map<String, String>>()
              .toList();
        } catch (_) {}
      }

      if (files.isEmpty) {
        files = await _storageService.listFilesWithPaths(storagePath);
        try {
          await prefs.setString(cacheKey, jsonEncode(files));
          await prefs.setInt(
            cacheTimeKey,
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {}
      }

      final cachedFiles = <String>[];
      for (final file in files) {
        if (await FlashCardCacheService.isCachedByPath(file['fullPath']!)) {
          cachedFiles.add(file['fullPath']!);
        }
      }

      if (cachedFiles.isNotEmpty) {
        final cachedResults = await Future.wait(
          cachedFiles.map((p) => FlashCardCacheService.getCachedCardsByPath(p)),
        );
        _cards = [];
        for (var cards in cachedResults) {
          _cards.addAll(cards);
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _cacheLoaded = true;
          });
          _loadSavedProgress();
          _checkSavedCards();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadFlashCards() async {
    if (_cacheLoaded && _cards.isNotEmpty) return;

    try {
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        if (_cards.isEmpty && mounted) setState(() => _isLoading = false);
        return;
      }

      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');

      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: widget.lessonId,
        topicId: widget.topicId,
        lessonNameForPath: lessonNameForPath,
      );
      final storagePath = '$basePath/bilgikarti';
      final files = await _storageService.listFilesWithPaths(storagePath);

      final cacheChecks = await Future.wait(
        files.map(
          (file) => FlashCardCacheService.isCachedByPath(file['fullPath']!),
        ),
      );

      final downloadFiles = <int, Map<String, String>>{};
      for (int i = 0; i < files.length; i++) {
        if (!cacheChecks[i]) {
          downloadFiles[i] = files[i];
        }
      }

      if (_cards.isEmpty && mounted) setState(() => _isLoading = true);

      if (downloadFiles.isNotEmpty) {
        Future(() async {
          for (final entry in downloadFiles.entries) {
            final file = entry.value;
            try {
              final cards = await FlashCardCacheService.cacheFlashCardsByPath(
                file['url']!,
                file['fullPath']!,
              );
              if (mounted && cards.isNotEmpty) {
                setState(() {
                  _cards.addAll(cards);
                  _isLoading = false;
                });
              }
            } catch (_) {}
          }
          if (mounted) setState(() => _isLoading = false);
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }

      if (_cards.isNotEmpty) {
        _loadSavedProgress();
        _checkSavedCards();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
      if (_cards.isNotEmpty) {
        _loadSavedProgress();
        _checkSavedCards();
      }
    }
  }

  Future<void> _loadSavedProgress() async {
    final idx = await _progressService.getFlashCardProgress(widget.topicId);
    if (idx != null && idx < _cards.length) {
      if (mounted) setState(() => _currentCardIndex = idx);
    }
    _saveProgress();
  }

  @override
  void dispose() {
    _saveProgress();
    _flipController.dispose();
    super.dispose();
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

  void _nextCard() {
    if (_currentCardIndex < _cards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFlipped = false;
        _flipController.reset();
      });
      _saveProgress();
      _checkCurrentCardSaved();
    } else {
      _progressService.deleteFlashCardProgress(widget.topicId);
    }
  }

  void _previousCard() {
    if (_currentCardIndex > 0) {
      setState(() {
        _currentCardIndex--;
        _isFlipped = false;
        _flipController.reset();
      });
      _saveProgress();
      _checkCurrentCardSaved();
    }
  }

  Future<void> _saveProgress() async {
    await _progressService.saveFlashCardProgress(
      topicId: widget.topicId,
      topicName: widget.topicName,
      lessonId: widget.lessonId,
      currentCardIndex: _currentCardIndex,
      totalCards: _cards.length,
    );
  }

  Future<void> _checkSavedCards() async {
    if (_cards.isEmpty) return;
    final savedIds = <String>{};
    for (var card in _cards) {
      if (await SavedCardsService.isCardSaved(card.id, widget.topicId)) {
        savedIds.add(card.id);
      }
    }
    if (mounted) setState(() => _savedCardIds = savedIds);
  }

  Future<void> _checkCurrentCardSaved() async {
    if (_cards.isEmpty || _currentCardIndex >= _cards.length) return;
    final card = _cards[_currentCardIndex];
    final isSaved = await SavedCardsService.isCardSaved(
      card.id,
      widget.topicId,
    );
    if (mounted) {
      setState(() {
        if (isSaved)
          _savedCardIds.add(card.id);
        else
          _savedCardIds.remove(card.id);
      });
    }
  }

  Future<void> _toggleSaveCard() async {
    if (_cards.isEmpty || _currentCardIndex >= _cards.length) return;
    final card = _cards[_currentCardIndex];
    final isSaved = _savedCardIds.contains(card.id);

    setState(() {
      if (isSaved)
        _savedCardIds.remove(card.id);
      else
        _savedCardIds.add(card.id);
    });

    try {
      if (isSaved) {
        await SavedCardsService.removeSavedCard(card.id, widget.topicId);
      } else {
        await SavedCardsService.addSavedCard(
          SavedCard.fromFlashCard(
            card,
            widget.topicId,
            widget.topicName,
            widget.lessonId,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isSaved)
            _savedCardIds.add(card.id);
          else
            _savedCardIds.remove(card.id);
        });
        PremiumSnackBar.show(
          context,
          message: 'İşlem başarısız oldu.',
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = screenHeight < 700;

    // Loading State
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    // Empty State
    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            _buildMeshBackground(isDark, screenWidth),
            _buildCustomHeader(context, isDark, statusBarHeight),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu konu için kart bulunamadı',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final currentCard = _cards[_currentCardIndex];

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
            // 1. Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // 2. Main Content
            Column(
              children: [
                SizedBox(height: statusBarHeight + 60), // Header space
                // Card Area
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
                              final isFrontVisible = _flipAnimation.value < 0.5;
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(angle),
                                child: isFrontVisible
                                    ? _buildCardFront(
                                        currentCard,
                                        isSmallScreen,
                                        isVerySmall,
                                      )
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..rotateY(3.14159),
                                        child: _buildCardBack(
                                          currentCard,
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

                // 3. Bottom Controls
                _buildBottomControls(
                  isDark,
                  currentCard,
                  bottomPadding,
                  isSmallScreen,
                ),
              ],
            ),

            // 4. Custom Header
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
          color: isDark ? const Color(0xFF010101) : const Color(0xFFF8FAFF),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D0221),
                    const Color(0xFF010101),
                    const Color(0xFF050505),
                  ]
                // Make light mode background slightly more vibrant/clean
                : [const Color(0xFFEFF6FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -screenWidth * 0.3,
              right: -screenWidth * 0.3,
              child: _buildBlurCircle(
                size: screenWidth * 1.5,
                color: isDark
                    ? const Color(0xFF7C3AED).withOpacity(0.15)
                    : const Color(0xFF8B5CF6).withOpacity(0.1),
              ),
            ),
            Positioned(
              bottom: -screenWidth * 0.4,
              left: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.6,
                color: isDark
                    ? const Color(0xFFDB2777).withOpacity(0.12)
                    : const Color(0xFFEC4899).withOpacity(0.1),
              ),
            ),
            Positioned(
              top: 150,
              left: -100,
              child: _buildBlurCircle(
                size: screenWidth * 1.0,
                color: isDark
                    ? const Color(0xFF0D9488).withOpacity(0.1)
                    : const Color(0xFF14B8A6).withOpacity(0.08),
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
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
          color: (isDark ? Colors.black : Colors.white).withOpacity(0.05),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white : Colors.black87,
                    size: 20,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    await _saveProgress();
                    if (mounted) {
                      Navigator.of(context).pop(true);
                      MainScreen.of(context)?.refreshHomePage();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BİLGİ KARTI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: isDark
                            ? Colors.white54
                            : AppColors.primaryBlue.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.topicName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
                  '${_currentCardIndex + 1} / ${_cards.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(FlashCard card, bool isSmallScreen, bool isVerySmall) {
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

  Widget _buildCardBack(FlashCard card, bool isSmallScreen, bool isVerySmall) {
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
            const Color(0xFF047857),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withOpacity(0.4),
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
                Icons.check_rounded,
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
                      card.backText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.4,
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
              const SizedBox(height: 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(
    bool isDark,
    FlashCard currentCard,
    double bottomPadding,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 20),
      color: Colors.transparent,
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
            onTap: _toggleSaveCard,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: _savedCardIds.contains(currentCard.id)
                    ? LinearGradient(
                        colors: [
                          AppColors.gradientBlueStart,
                          AppColors.gradientBlueEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _savedCardIds.contains(currentCard.id)
                    ? null
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.white),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _savedCardIds.contains(currentCard.id)
                        ? AppColors.gradientBlueStart.withOpacity(0.3)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: _savedCardIds.contains(currentCard.id)
                    ? null
                    : Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _savedCardIds.contains(currentCard.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _savedCardIds.contains(currentCard.id)
                        ? Colors.white
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _savedCardIds.contains(currentCard.id)
                        ? 'Kaydedildi'
                        : 'Kaydet',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: _savedCardIds.contains(currentCard.id)
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
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
            enabled: _currentCardIndex < _cards.length - 1,
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: isPrimary
                ? Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    width: 1.5,
                  )
                : Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          ),
          child: Icon(
            icon,
            color: isPrimary
                ? AppColors.primaryBlue
                : (isDark ? Colors.white : const Color(0xFF1E293B)),
            size: 24,
          ),
        ),
      ),
    );
  }
}
