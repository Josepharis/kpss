import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/flash_card.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/flash_card_cache_service.dart';
import '../../../core/services/saved_cards_service.dart';
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
  bool _cacheLoaded = false; // Cache'den yüklendi mi?
  Set<String> _savedCardIds = {}; // Kaydedilmiş kart ID'leri

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
    // Cache kontrolünü önce yap ve TAMAMLANMASINI BEKLE (anında açılış için - PDF gibi)
    _initializeFlashCards();
  }

  /// Initialize flash cards - cache kontrolü tamamlanana kadar bekle (PDF gibi)
  Future<void> _initializeFlashCards() async {
    // Önce cache kontrolü yap (await et - tamamlanmasını bekle)
    await _checkCacheImmediately();
    
    // Sonra diğer dosyaları yükle
    _loadFlashCards();
  }
  
  /// Check cache immediately (synchronous check for instant loading - PDF gibi)
  /// Cache dizinindeki dosyaları direkt okuyarak Firebase Storage çağrısını atla
  Future<void> _checkCacheImmediately() async {
    debugPrint('🔍 Checking flash cards cache immediately for instant loading...');
    
    try {
      setState(() {
        _isLoading = true;
      });

      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        debugPrint('⚠️ Lesson not found: ${widget.lessonId}');
        return;
      }
      
      // Lesson name'i storage path'ine çevir
      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
      
      // Topic base path'i bul (önce konular/ altına bakar, yoksa direkt ders altına bakar)
      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: widget.lessonId,
        topicId: widget.topicId,
        lessonNameForPath: lessonNameForPath,
      );
      
      // Storage yolunu oluştur
      final storagePath = '$basePath/bilgikarti';
      
      // Storage'dan gerçek dosya isimlerini al (cache kontrolü için doğru isimleri kullanmak için)
      List<Map<String, String>> files = [];
      try {
        files = await _storageService.listFilesWithPaths(storagePath);
        debugPrint('📊 Found ${files.length} files in Storage');
      } catch (e) {
        debugPrint('⚠️ Error getting files from Storage: $e');
        // Hata durumunda eski yöntemi kullan (fallback)
        for (int i = 1; i <= 20; i++) {
          final filePath = '$storagePath/$i.csv';
          if (await FlashCardCacheService.isCachedByPath(filePath)) {
            files.add({
              'name': '$i.csv',
              'fullPath': filePath,
              'url': '',
            });
          }
        }
      }
      
      // Cache'deki dosyaları kontrol et (gerçek dosya isimleriyle)
      final cachedFiles = <String>[];
      for (final file in files) {
        final fullPath = file['fullPath']!;
        if (await FlashCardCacheService.isCachedByPath(fullPath)) {
          cachedFiles.add(fullPath);
          debugPrint('✅ Cache hit for: $fullPath');
        } else {
          debugPrint('❌ Cache miss for: $fullPath');
        }
      }
      
      debugPrint('📊 Found ${cachedFiles.length} cached flash card files out of ${files.length} total');
      
      // Cache'den olanları paralel yükle ve HEMEN GÖSTER (anında açılış için)
      if (cachedFiles.isNotEmpty) {
        debugPrint('📂 Loading ${cachedFiles.length} files from cache (parallel - instant)...');
        final cachedResults = await Future.wait(
          cachedFiles.map((fullPath) async {
            try {
              final cards = await FlashCardCacheService.getCachedCardsByPath(fullPath);
              debugPrint('  📊 Loaded ${cards.length} cards from cache file: $fullPath');
              return cards;
            } catch (e) {
              debugPrint('⚠️ Error loading from cache: $e');
              return <FlashCard>[];
            }
          }),
        );
        
        _cards = [];
        for (int i = 0; i < cachedResults.length; i++) {
          final cards = cachedResults[i];
          _cards.addAll(cards);
          debugPrint('  ✅ Added ${cards.length} cards from file ${i + 1}/${cachedFiles.length}');
        }
        debugPrint('✅ Loaded ${_cards.length} cards from cache total - INSTANT DISPLAY');
        
        // Cache'den yüklenenleri HEMEN göster (anında açılış - PDF gibi)
        if (mounted) {
          setState(() {
            _isLoading = false; // Hemen göster
            _cacheLoaded = true; // Cache'den yüklendi
          });
          // İlerlemeyi arka planda yükle (await etme - anında açılış için)
          _loadSavedProgress();
          _checkSavedCards();
        }
        debugPrint('✅ Flash cards displayed instantly from cache');
      } else {
        debugPrint('❌ No cached flash cards found');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking flash cards cache in initState: $e');
    }
  }

  Future<void> _loadFlashCards() async {
    // Eğer cache'den tüm dosyalar yüklendiyse, Firebase Storage'a hiç gitme (anında açılış için)
    if (_cacheLoaded && _cards.isNotEmpty) {
      debugPrint('📂 All files loaded from cache, skipping Firebase Storage operations for instant display');
      return; // Cache'den yüklendiyse, Storage'a hiç gitme
    }
    
    // Cache'de hiçbir şey yoksa, o zaman Storage'dan çek
    if (_cards.isEmpty) {
      debugPrint('📂 No cache found, loading from Firebase Storage...');
    } else {
      // Cache'de kısmen dosyalar varsa, eksikleri arka planda yükle (opsiyonel)
      debugPrint('📂 Cache partially loaded, skipping Firebase Storage to minimize network calls');
      return; // Cache'den kısmen yüklendiyse de Storage'a gitme, kullanıcı zaten cache'den yüklenenleri görebilir
    }
    
    try {
      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        debugPrint('⚠️ Lesson not found: ${widget.lessonId}');
        if (_cards.isEmpty && mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      // Lesson name'i storage path'ine çevir
      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
      
      // Topic base path'i bul (önce konular/ altına bakar, yoksa direkt ders altına bakar)
      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: widget.lessonId,
        topicId: widget.topicId,
        lessonNameForPath: lessonNameForPath,
      );
      
      // Storage yolunu oluştur
      final storagePath = '$basePath/bilgikarti';
      
      // Storage'dan dosyaları listele
      final files = await _storageService.listFilesWithPaths(storagePath);
      
      // Cache kontrolü yap
      final cacheChecks = await Future.wait(
        files.map((file) => FlashCardCacheService.isCachedByPath(file['fullPath']!)),
      );
      
      // İndirilecekleri bul (cache'de olmayanlar)
      final downloadFiles = <int, Map<String, String>>{};
      for (int i = 0; i < files.length; i++) {
        if (!cacheChecks[i]) {
          downloadFiles[i] = files[i];
        }
      }
      
      // Eğer cache'den yüklenmediyse, loading göster
      if (_cards.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      // İndirilecekleri arka planda yükle (cache'le) - non-blocking
      if (downloadFiles.isNotEmpty) {
        debugPrint('🌐 Downloading ${downloadFiles.length} files in background (will cache)...');
        // Arka planda indir (kullanıcıyı bekletme)
        Future(() async {
          for (final entry in downloadFiles.entries) {
            final file = entry.value;
            final url = file['url']!;
            final fullPath = file['fullPath']!;
            
            try {
              debugPrint('🌐 Downloading file ($fullPath)');
              final cards = await FlashCardCacheService.cacheFlashCardsByPath(url, fullPath);
              if (mounted && cards.isNotEmpty) {
                setState(() {
                  _cards.addAll(cards);
                  _isLoading = false; // Loading'i kapat
                });
                debugPrint('✅ Loaded ${cards.length} cards from download - added to list');
              }
            } catch (e) {
              debugPrint('⚠️ Error downloading flash card from $fullPath: $e');
            }
          }
          
          // Tüm indirmeler tamamlandığında loading'i kapat
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          debugPrint('✅ Background download complete - total cards: ${_cards.length}');
        });
      } else {
        // Eğer indirilecek dosya yoksa, loading'i kapat
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      
      // Eğer hiç kart yüklenmediyse (ne cache'den ne de download'dan), hata mesajı göster
      if (_cards.isEmpty && downloadFiles.isEmpty) {
        debugPrint('⚠️ No flash cards found in cache or Storage');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        // Mock data kullanma - boş liste bırak, kullanıcıya hata mesajı gösterilecek
      }
      
      debugPrint('✅ Flash cards initialization complete: ${_cards.length} cards');
      
      // İlerlemeyi yükle (eğer daha önce yüklenmediyse)
      if (_cards.isNotEmpty) {
        _loadSavedProgress();
        _checkSavedCards();
      }
    } catch (e) {
      debugPrint('❌ Error loading flash cards: $e');
      
      // Hata durumunda mock data kullanma - boş liste bırak
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Eğer cache'den yüklenen kartlar varsa, onları kullan
      if (_cards.isNotEmpty) {
        _loadSavedProgress();
        _checkSavedCards();
      }
    }
  }

  Future<void> _loadSavedProgress() async {
    final savedCardIndex = await _progressService.getFlashCardProgress(widget.topicId);
    if (savedCardIndex != null && savedCardIndex < _cards.length) {
      setState(() {
        _currentCardIndex = savedCardIndex;
      });
      debugPrint('✅ Resuming flash cards from card ${savedCardIndex + 1}');
    }
    _saveProgress(); // Save initial progress
  }

  @override
  void dispose() {
    // Save final progress before disposing
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
    setState(() {
      _isFlipped = !_isFlipped;
    });
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
      // All cards completed
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

  // Kaydedilmiş kartları kontrol et
  Future<void> _checkSavedCards() async {
    if (_cards.isEmpty) return;
    
    final savedIds = <String>{};
    for (var card in _cards) {
      final isSaved = await SavedCardsService.isCardSaved(card.id, widget.topicId);
      if (isSaved) {
        savedIds.add(card.id);
      }
    }
    
    if (mounted) {
      setState(() {
        _savedCardIds = savedIds;
      });
    }
  }

  // Mevcut kartın kaydedilip kaydedilmediğini kontrol et
  Future<void> _checkCurrentCardSaved() async {
    if (_cards.isEmpty || _currentCardIndex >= _cards.length) return;
    
    final currentCard = _cards[_currentCardIndex];
    final isSaved = await SavedCardsService.isCardSaved(currentCard.id, widget.topicId);
    
    if (mounted) {
      setState(() {
        if (isSaved) {
          _savedCardIds.add(currentCard.id);
        } else {
          _savedCardIds.remove(currentCard.id);
        }
      });
    }
  }

  // Kartı kaydet/kaldır
  Future<void> _toggleSaveCard() async {
    if (_cards.isEmpty || _currentCardIndex >= _cards.length) return;
    
    final currentCard = _cards[_currentCardIndex];
    final isSaved = await SavedCardsService.isCardSaved(currentCard.id, widget.topicId);

    if (isSaved) {
      // Kaldır
      final success = await SavedCardsService.removeSavedCard(currentCard.id, widget.topicId);
      if (mounted && success) {
        setState(() {
          _savedCardIds.remove(currentCard.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kart kaydedilenlerden kaldırıldı.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Kaydet
      final savedCard = SavedCard.fromFlashCard(
        currentCard,
        widget.topicId,
        widget.topicName,
        widget.lessonId,
      );
      final success = await SavedCardsService.addSavedCard(savedCard);
      if (mounted && success) {
        setState(() {
          _savedCardIds.add(currentCard.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kart kaydedilenlere eklendi.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.gradientRedStart,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
              // MainScreen'e refresh sinyali gönder
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) {
                mainScreen.refreshHomePage();
              }
            },
          ),
          title: Text(
            widget.topicName,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.gradientRedStart,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
              // MainScreen'e refresh sinyali gönder
              final mainScreen = MainScreen.of(context);
              if (mainScreen != null) {
                mainScreen.refreshHomePage();
              }
            },
          ),
          title: Text(
            widget.topicName,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.style_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Bu konu için henüz bilgi kartı eklenmemiş',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final currentCard = _cards[_currentCardIndex];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.gradientRedStart,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () async {
            // Save progress before leaving
            await _saveProgress();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('İlerlemeniz kaydediliyor...'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Colors.green,
                ),
              );
              // Wait for message to be visible
              await Future.delayed(const Duration(milliseconds: 2000));
              if (mounted) {
                Navigator.of(context).pop(true);
                // MainScreen'e refresh sinyali gönder
                final mainScreen = MainScreen.of(context);
                if (mainScreen != null) {
                  mainScreen.refreshHomePage();
                }
              }
            }
          },
        ),
        title: Text(
          widget.topicName,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: isTablet ? 20 : 16),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 10 : 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentCardIndex + 1}/${_cards.length}',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isVerySmallScreen = constraints.maxWidth < 360;
          final screenHeight = constraints.maxHeight;
          return Column(
            children: [
              // Flash Card - maksimum alan kullan
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 8 : 12,
                  ),
                  child: GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * 3.14159; // π
                        final isFrontVisible = _flipAnimation.value < 0.5;

                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          child: isFrontVisible
                              ? _buildCardFront(currentCard, isSmallScreen, isVerySmallScreen, screenHeight)
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(3.14159),
                                  child: _buildCardBack(currentCard, isSmallScreen, isVerySmallScreen, screenHeight),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Navigation buttons - ekran altında ama tam görünsün
              Container(
                padding: EdgeInsets.only(
                  left: isTablet ? 20 : 12,
                  right: isTablet ? 20 : 12,
                  top: isSmallScreen ? 16 : 20,
                  bottom: isSmallScreen ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kaydet butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleSaveCard,
                        icon: Icon(
                          _savedCardIds.contains(currentCard.id)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: isSmallScreen ? 18 : 20,
                        ),
                        label: Text(
                          _savedCardIds.contains(currentCard.id)
                              ? 'Kaydedildi'
                              : 'Kaydet',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _savedCardIds.contains(currentCard.id)
                              ? Colors.green
                              : AppColors.gradientRedStart,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 14,
                          ),
                          minimumSize: Size(0, isSmallScreen ? 48 : 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 10),
                    // Navigation buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _previousCard,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              size: isSmallScreen ? 18 : 20,
                            ),
                            label: Text(
                              'Önceki',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              padding: EdgeInsets.symmetric(
                                horizontal: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              minimumSize: Size(0, isSmallScreen ? 44 : 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        SizedBox(width: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _flipCard,
                            icon: Icon(
                              _isFlipped ? Icons.refresh_rounded : Icons.autorenew_rounded,
                              size: isSmallScreen ? 18 : 20,
                            ),
                            label: Text(
                              _isFlipped ? 'Çevir' : 'Göster',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gradientRedStart,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isVerySmallScreen ? 12 : isSmallScreen ? 16 : 20,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              minimumSize: Size(0, isSmallScreen ? 44 : 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        SizedBox(width: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _nextCard,
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              size: isSmallScreen ? 18 : 20,
                            ),
                            label: Text(
                              'Sonraki',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              padding: EdgeInsets.symmetric(
                                horizontal: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              minimumSize: Size(0, isSmallScreen ? 44 : 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCardFront(FlashCard card, bool isSmallScreen, bool isVerySmallScreen, double screenHeight) {
    // Dinamik font boyutu hesapla - metin uzunluğuna göre
    // Kısa sorular için çok daha büyük font kullan
    final textLength = card.frontText.length;
    double baseFontSize;
    
    // Metin uzunluğuna göre font boyutunu dinamik olarak ayarla - makul seviye
    if (textLength <= 30) {
      // Çok kısa sorular için en büyük font
      baseFontSize = isVerySmallScreen ? 24 : isSmallScreen ? 30 : 36;
    } else if (textLength <= 50) {
      // Kısa sorular için büyük font
      baseFontSize = isVerySmallScreen ? 22 : isSmallScreen ? 28 : 34;
    } else if (textLength <= 100) {
      // Orta sorular için orta font
      baseFontSize = isVerySmallScreen ? 20 : isSmallScreen ? 26 : 32;
    } else if (textLength <= 200) {
      // Uzun sorular için küçük font
      baseFontSize = isVerySmallScreen ? 18 : isSmallScreen ? 24 : 30;
    } else {
      // Çok uzun sorular için en küçük font
      baseFontSize = isVerySmallScreen ? 16 : isSmallScreen ? 22 : 28;
    }
    
    return Container(
      margin: EdgeInsets.zero,
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientRedStart,
            AppColors.gradientRedEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientRedStart.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: isSmallScreen ? 44 : 52,
                color: Colors.white,
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              // Metin tamamen görünsün - üç nokta yok, FittedBox kaldırıldı
              Text(
                card.frontText,
                style: TextStyle(
                  fontSize: baseFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Cevabı görmek için dokun',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack(FlashCard card, bool isSmallScreen, bool isVerySmallScreen, double screenHeight) {
    // Dinamik font boyutu hesapla - metin uzunluğuna göre
    // Kısa cevaplar için çok daha büyük font kullan
    final textLength = card.backText.length;
    double baseFontSize;
    
    // Metin uzunluğuna göre font boyutunu dinamik olarak ayarla - makul seviye
    if (textLength <= 30) {
      // Çok kısa cevaplar için en büyük font
      baseFontSize = isVerySmallScreen ? 24 : isSmallScreen ? 30 : 36;
    } else if (textLength <= 50) {
      // Kısa cevaplar için büyük font
      baseFontSize = isVerySmallScreen ? 22 : isSmallScreen ? 28 : 34;
    } else if (textLength <= 100) {
      // Orta cevaplar için orta font
      baseFontSize = isVerySmallScreen ? 20 : isSmallScreen ? 26 : 32;
    } else if (textLength <= 200) {
      // Uzun cevaplar için küçük font
      baseFontSize = isVerySmallScreen ? 18 : isSmallScreen ? 24 : 30;
    } else {
      // Çok uzun cevaplar için en küçük font
      baseFontSize = isVerySmallScreen ? 16 : isSmallScreen ? 22 : 28;
    }
    
    return Container(
      margin: EdgeInsets.zero,
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientGreenStart,
            AppColors.gradientGreenEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.gradientGreenStart.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: isSmallScreen ? 44 : 52,
                color: Colors.white,
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              // Metin tamamen görünsün - üç nokta yok, FittedBox kaldırıldı
              Text(
                card.backText,
                style: TextStyle(
                  fontSize: baseFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Soruya dönmek için dokun',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

