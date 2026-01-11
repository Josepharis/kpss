import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/flash_card.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/flash_card_cache_service.dart';

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
    print('🔍 Checking flash cards cache immediately for instant loading...');
    
    try {
      setState(() {
        _isLoading = true;
      });

      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: ${widget.lessonId}');
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
      
      // Topic name'i storage path'ine çevir
      final topicFolderName = widget.topicId.startsWith('${widget.lessonId}_')
          ? widget.topicId.substring('${widget.lessonId}_'.length)
          : widget.topicName;
      
      // Storage yolunu oluştur (cache kontrolü için)
      final storagePath = 'dersler/$lessonNameForPath/konular/$topicFolderName/bilgikarti';
      final altStoragePath = 'dersler/$lessonNameForPath/$topicFolderName/bilgikarti';
      
      // Cache dizinindeki tüm dosyaları oku (Firebase Storage çağrısı yok - çok hızlı)
      // Cache'deki dosyaları path'e göre filtrele
      final cachedFiles = <String>[];
      
      // Önce birinci path'i dene
      for (int i = 1; i <= 20; i++) { // Maksimum 20 dosya kontrol et
        final filePath = '$storagePath/$i.csv';
        if (await FlashCardCacheService.isCachedByPath(filePath)) {
          cachedFiles.add(filePath);
        }
      }
      
      // Eğer birinci path'te dosya bulunamadıysa, alternatif path'i dene
      if (cachedFiles.isEmpty) {
        for (int i = 1; i <= 20; i++) {
          final filePath = '$altStoragePath/$i.csv';
          if (await FlashCardCacheService.isCachedByPath(filePath)) {
            cachedFiles.add(filePath);
          }
        }
      }
      
      print('📊 Found ${cachedFiles.length} cached flash card files');
      
      // Cache'den olanları paralel yükle ve HEMEN GÖSTER (anında açılış için)
      if (cachedFiles.isNotEmpty) {
        print('📂 Loading ${cachedFiles.length} files from cache (parallel - instant)...');
        final cachedResults = await Future.wait(
          cachedFiles.map((fullPath) async {
            try {
              final cards = await FlashCardCacheService.getCachedCardsByPath(fullPath);
              return cards;
            } catch (e) {
              print('⚠️ Error loading from cache: $e');
              return <FlashCard>[];
            }
          }),
        );
        
        _cards = [];
        for (final cards in cachedResults) {
          _cards.addAll(cards);
        }
        print('✅ Loaded ${_cards.length} cards from cache total - INSTANT DISPLAY');
        
        // Cache'den yüklenenleri HEMEN göster (anında açılış - PDF gibi)
        if (mounted) {
          setState(() {
            _isLoading = false; // Hemen göster
            _cacheLoaded = true; // Cache'den yüklendi
          });
          // İlerlemeyi arka planda yükle (await etme - anında açılış için)
          _loadSavedProgress();
        }
        print('✅ Flash cards displayed instantly from cache');
      } else {
        print('❌ No cached flash cards found');
      }
    } catch (e) {
      print('⚠️ Error checking flash cards cache in initState: $e');
    }
  }

  Future<void> _loadFlashCards() async {
    // Eğer cache'den tüm dosyalar yüklendiyse, Firebase Storage'a hiç gitme (anında açılış için)
    if (_cacheLoaded && _cards.isNotEmpty) {
      print('📂 All files loaded from cache, skipping Firebase Storage operations for instant display');
      return; // Cache'den yüklendiyse, Storage'a hiç gitme
    }
    
    // Cache'de hiçbir şey yoksa, o zaman Storage'dan çek
    if (_cards.isEmpty) {
      print('📂 No cache found, loading from Firebase Storage...');
    } else {
      // Cache'de kısmen dosyalar varsa, eksikleri arka planda yükle (opsiyonel)
      print('📂 Cache partially loaded, skipping Firebase Storage to minimize network calls');
      return; // Cache'den kısmen yüklendiyse de Storage'a gitme, kullanıcı zaten cache'den yüklenenleri görebilir
    }
    
    try {
      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: ${widget.lessonId}');
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
      
      // Topic name'i storage path'ine çevir
      final topicFolderName = widget.topicId.startsWith('${widget.lessonId}_')
          ? widget.topicId.substring('${widget.lessonId}_'.length)
          : widget.topicName;
      
      // Storage yolunu oluştur
      String storagePath = 'dersler/$lessonNameForPath/konular/$topicFolderName/bilgikarti';
      try {
        final testResult = await _storageService.listFiles(storagePath);
        if (testResult.isEmpty) {
          storagePath = 'dersler/$lessonNameForPath/$topicFolderName/bilgikarti';
        }
      } catch (e) {
        storagePath = 'dersler/$lessonNameForPath/$topicFolderName/bilgikarti';
      }
      
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
        print('🌐 Downloading ${downloadFiles.length} files in background (will cache)...');
        // Arka planda indir (kullanıcıyı bekletme)
        Future(() async {
          for (final entry in downloadFiles.entries) {
            final file = entry.value;
            final url = file['url']!;
            final fullPath = file['fullPath']!;
            
            try {
              print('🌐 Downloading file ($fullPath)');
              final cards = await FlashCardCacheService.cacheFlashCardsByPath(url, fullPath);
              if (mounted && cards.isNotEmpty) {
                setState(() {
                  _cards.addAll(cards);
                });
                print('✅ Loaded ${cards.length} cards from download - added to list');
              }
            } catch (e) {
              print('⚠️ Error downloading flash card from $fullPath: $e');
            }
          }
          print('✅ Background download complete - total cards: ${_cards.length}');
        });
      }
      
      // Eğer hiç kart yüklenmediyse (ne cache'den ne de download'dan), mock data kullan
      if (_cards.isEmpty && downloadFiles.isEmpty) {
        print('⚠️ No flash cards found, using mock data');
        if (mounted) {
          setState(() {
            _cards = List.generate(
              widget.cardCount,
              (index) => FlashCard(
                id: '${index + 1}',
                frontText: 'Soru ${index + 1}: ${widget.topicName} konusunda önemli bir kavram nedir?',
                backText: 'Cevap ${index + 1}: Bu konuda önemli kavramlar şunlardır: Açıklama detayları burada yer alacak.',
              ),
            );
            _isLoading = false;
          });
        }
      }
      
      print('✅ Flash cards initialization complete: ${_cards.length} cards');
      
      // İlerlemeyi yükle (eğer daha önce yüklenmediyse)
      if (_cards.isNotEmpty) {
        _loadSavedProgress();
      }
    } catch (e) {
      print('❌ Error loading flash cards: $e');
      
      // Hata durumunda mock data kullan
      _cards = List.generate(
        widget.cardCount,
        (index) => FlashCard(
          id: '${index + 1}',
          frontText: 'Soru ${index + 1}: ${widget.topicName} konusunda önemli bir kavram nedir?',
          backText: 'Cevap ${index + 1}: Bu konuda önemli kavramlar şunlardır: Açıklama detayları burada yer alacak.',
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
      
      _loadSavedProgress();
    }
  }

  Future<void> _loadSavedProgress() async {
    final savedCardIndex = await _progressService.getFlashCardProgress(widget.topicId);
    if (savedCardIndex != null && savedCardIndex < _cards.length) {
      setState(() {
        _currentCardIndex = savedCardIndex;
      });
      print('✅ Resuming flash cards from card ${savedCardIndex + 1}');
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
            onPressed: () => Navigator.of(context).pop(true),
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
            onPressed: () => Navigator.of(context).pop(true),
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
                Navigator.of(context).pop(true); // Return true to indicate refresh needed
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
          return Column(
            children: [
              SizedBox(height: isSmallScreen ? 2 : 4),
              // Flash Card
              Flexible(
                flex: 1,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: isSmallScreen ? 2 : 4,
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
                              ? _buildCardFront(currentCard, isSmallScreen, isVerySmallScreen)
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(3.14159),
                                  child: _buildCardBack(currentCard, isSmallScreen, isVerySmallScreen),
                                ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 2 : 4),
              // Navigation buttons
              Padding(
                padding: EdgeInsets.only(
                  left: isTablet ? 20 : 12,
                  right: isTablet ? 20 : 12,
                  top: 0,
                  bottom: isSmallScreen ? 4 : 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: _previousCard,
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: isSmallScreen ? 16 : 18,
                        ),
                        label: Text(
                          'Önceki',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 14,
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          minimumSize: Size(0, isSmallScreen ? 40 : 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 6 : isSmallScreen ? 8 : 10),
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: _flipCard,
                        icon: Icon(
                          _isFlipped ? Icons.refresh_rounded : Icons.autorenew_rounded,
                          size: isSmallScreen ? 16 : 18,
                        ),
                        label: Text(
                          _isFlipped ? 'Çevir' : 'Göster',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gradientRedStart,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 10 : isSmallScreen ? 14 : 18,
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          minimumSize: Size(0, isSmallScreen ? 40 : 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 6 : isSmallScreen ? 8 : 10),
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: _nextCard,
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          size: isSmallScreen ? 16 : 18,
                        ),
                        label: Text(
                          'Sonraki',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 14,
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          minimumSize: Size(0, isSmallScreen ? 40 : 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildCardFront(FlashCard card, bool isSmallScreen, bool isVerySmallScreen) {
    return Container(
      margin: EdgeInsets.zero,
      constraints: BoxConstraints(
        maxHeight: isSmallScreen ? 480 : 520,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 20 : 26),
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
                size: isSmallScreen ? 40 : 48,
                color: Colors.white,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                card.frontText,
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmallScreen ? 10 : 12),
              Text(
                'Cevabı görmek için dokun',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
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

  Widget _buildCardBack(FlashCard card, bool isSmallScreen, bool isVerySmallScreen) {
    return Container(
      margin: EdgeInsets.zero,
      constraints: BoxConstraints(
        maxHeight: isSmallScreen ? 480 : 520,
      ),
      padding: EdgeInsets.all(isSmallScreen ? 20 : 26),
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
                size: isSmallScreen ? 40 : 48,
                color: Colors.white,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                card.backText,
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmallScreen ? 10 : 12),
              Text(
                'Soruya dönmek için dokun',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
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

