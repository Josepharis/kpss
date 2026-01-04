import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/flash_card.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/lessons_service.dart';

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
    _loadFlashCards();
  }

  Future<void> _loadFlashCards() async {
    try {
      setState(() {
        _isLoading = true;
      });

      print('🔍 Loading flash cards from Storage for topicId: ${widget.topicId}');
      
      // Lesson name'i al
      final lesson = await _lessonsService.getLessonById(widget.lessonId);
      if (lesson == null) {
        print('⚠️ Lesson not found: ${widget.lessonId}');
        setState(() {
          _isLoading = false;
        });
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
      
      // Topic name'i storage path'ine çevir (topicId'den topic folder name'i çıkar)
      // TopicId formatı: {lessonId}_{topicFolderName}
      // lessonId'yi tam olarak çıkar (çünkü lessonId'de de alt çizgi olabilir)
      // topicFolderName zaten storage'daki gerçek klasör adı, direkt kullan (Firebase Storage path'leri direkt string)
      final topicFolderName = widget.topicId.startsWith('${widget.lessonId}_')
          ? widget.topicId.substring('${widget.lessonId}_'.length)
          : widget.topicName; // Fallback: topic name'i direkt kullan
      
      // Storage yolunu oluştur: önce konular/ altından dene, yoksa direkt ders altından
      // Firebase Storage path'leri direkt string olarak kullanılır, encode etmeye gerek yok
      String storagePath = 'dersler/$lessonNameForPath/konular/$topicFolderName/bilgikarti';
      try {
        print('📂 Trying storage path: $storagePath');
        final testResult = await _storageService.listFiles(storagePath);
        if (testResult.isEmpty) {
          // Konular altında yoksa, direkt ders altından dene
          storagePath = 'dersler/$lessonNameForPath/$topicFolderName/bilgikarti';
          print('📂 Trying alternative path: $storagePath');
        }
      } catch (e) {
        // Hata varsa alternatif path'i dene
        storagePath = 'dersler/$lessonNameForPath/$topicFolderName/bilgikarti';
        print('📂 Using fallback path: $storagePath');
      }
      
      // Storage'dan dosyaları listele
      final fileUrls = await _storageService.listFiles(storagePath);
      
      _cards = [];
      
      // Her dosyayı indir ve parse et (JSON veya CSV)
      for (int index = 0; index < fileUrls.length; index++) {
        final url = fileUrls[index];
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            // Response body'yi UTF-8 olarak decode et (Türkçe karakterler için)
            final body = utf8.decode(response.bodyBytes);
            final contentType = response.headers['content-type'] ?? '';
            final fileName = url.toLowerCase();
            
            // CSV formatını kontrol et
            if (fileName.endsWith('.csv') || contentType.contains('csv') || 
                body.trim().startsWith('front') || 
                body.contains(',')) {
              // CSV formatını parse et
              final lines = body.split('\n');
              if (lines.isNotEmpty) {
                // İlk satır header olabilir, atla
                final startIndex = lines[0].toLowerCase().contains('front') ? 1 : 0;
                
                for (int i = startIndex; i < lines.length; i++) {
                  final line = lines[i].trim();
                  if (line.isEmpty) continue;
                  
                  // CSV satırını parse et (front,back formatı)
                  // Virgülle split et, ama tırnak içindeki virgülleri koru
                  List<String> parts = [];
                  bool inQuotes = false;
                  String currentPart = '';
                  
                  for (int j = 0; j < line.length; j++) {
                    final char = line[j];
                    if (char == '"') {
                      inQuotes = !inQuotes;
                    } else if (char == ',' && !inQuotes) {
                      parts.add(currentPart.trim());
                      currentPart = '';
                    } else {
                      currentPart += char;
                    }
                  }
                  parts.add(currentPart.trim()); // Son kısmı ekle
                  
                  if (parts.length >= 2) {
                    final front = parts[0].replaceAll('"', '').trim();
                    final back = parts[1].replaceAll('"', '').trim();
                    
                    if (front.isNotEmpty && back.isNotEmpty) {
                      _cards.add(FlashCard(
                        id: '${_cards.length + 1}',
                        frontText: front,
                        backText: back,
                        isLearned: false,
                      ));
                    }
                  }
                }
              }
            } else {
              // JSON formatını parse et
              final jsonData = json.decode(body);
              
              // JSON formatını kontrol et
              if (jsonData is List) {
                // Liste formatında ise
                for (var cardData in jsonData) {
                  _cards.add(FlashCard(
                    id: cardData['id'] ?? '${_cards.length + 1}',
                    frontText: cardData['frontText'] ?? cardData['front'] ?? '',
                    backText: cardData['backText'] ?? cardData['back'] ?? '',
                    isLearned: cardData['isLearned'] ?? false,
                  ));
                }
              } else if (jsonData is Map) {
                // Tek bir kart veya kartlar listesi içeren map
                if (jsonData['cards'] != null && jsonData['cards'] is List) {
                  for (var cardData in jsonData['cards']) {
                    _cards.add(FlashCard(
                      id: cardData['id'] ?? '${_cards.length + 1}',
                      frontText: cardData['frontText'] ?? cardData['front'] ?? '',
                      backText: cardData['backText'] ?? cardData['back'] ?? '',
                      isLearned: cardData['isLearned'] ?? false,
                    ));
                  }
                } else {
                  // Tek bir kart
                  _cards.add(FlashCard(
                    id: jsonData['id'] ?? '${_cards.length + 1}',
                    frontText: jsonData['frontText'] ?? jsonData['front'] ?? '',
                    backText: jsonData['backText'] ?? jsonData['back'] ?? '',
                    isLearned: jsonData['isLearned'] ?? false,
                  ));
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Error loading flash card from $url: $e');
        }
      }
      
      // Eğer hiç kart yüklenmediyse, mock data kullan
      if (_cards.isEmpty) {
        print('⚠️ No flash cards found, using mock data');
        _cards = List.generate(
          widget.cardCount,
          (index) => FlashCard(
            id: '${index + 1}',
            frontText: 'Soru ${index + 1}: ${widget.topicName} konusunda önemli bir kavram nedir?',
            backText: 'Cevap ${index + 1}: Bu konuda önemli kavramlar şunlardır: Açıklama detayları burada yer alacak.',
          ),
        );
      }
      
      print('✅ Loaded ${_cards.length} flash cards');
      
      setState(() {
        _isLoading = false;
      });
      
      // İlerlemeyi yükle
      _loadSavedProgress();
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

