import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/saved_cards_service.dart';

// SavedCard'ı import et
import '../../../core/services/saved_cards_service.dart' show SavedCard;

class SavedCardTopicDetailPage extends StatefulWidget {
  final Lesson lesson;
  final String topicName;

  const SavedCardTopicDetailPage({
    super.key,
    required this.lesson,
    required this.topicName,
  });

  @override
  State<SavedCardTopicDetailPage> createState() => _SavedCardTopicDetailPageState();
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
    setState(() {
      _isLoading = true;
    });

    try {
      final allCards = await SavedCardsService.getSavedCardsByTopic(widget.topicName);
      // Sadece bu derse ait kartları filtrele
      final filteredCards = allCards.where((c) => c.lessonId == widget.lesson.id).toList();
      
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
      // Silent error handling
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    final success = await SavedCardsService.removeSavedCard(currentCard.id, currentCard.topicId);

    if (mounted && success) {
      // Kartı listeden kaldır
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kart kaydedilenlerden kaldırıldı.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );

      // Eğer tüm kartlar silindiyse geri dön
      if (_savedCards.isEmpty) {
        Navigator.of(context).pop();
      }
    }
  }

  Color _getColor() {
    switch (widget.lesson.color) {
      case 'orange':
        return const Color(0xFFFF6B35);
      case 'blue':
        return const Color(0xFF4A90E2);
      case 'red':
        return const Color(0xFFE74C3C);
      case 'green':
        return const Color(0xFF27AE60);
      case 'purple':
        return const Color(0xFF9B59B6);
      case 'teal':
        return const Color(0xFF16A085);
      case 'indigo':
        return const Color(0xFF5C6BC0);
      case 'pink':
        return const Color(0xFFE91E63);
      default:
        return AppColors.gradientRedStart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : _getColor(),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
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
    
    if (_savedCards.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : _getColor(),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: isSmallScreen ? 18 : 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
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
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Bu konuda kaydedilmiş kart yok',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final currentCard = _savedCards[_currentCardIndex];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : _getColor(),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
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
              '${_currentCardIndex + 1}/${_savedCards.length}',
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
              // Navigation buttons - ekran altında ama tam görünsün
              Container(
                padding: EdgeInsets.only(
                  left: isTablet ? 20 : 12,
                  right: isTablet ? 20 : 12,
                  top: isSmallScreen ? 16 : 20,
                  bottom: isSmallScreen ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
                  boxShadow: [
                    BoxShadow(
                      color: isDark 
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kaldır butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _removeCard,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Kaydedilenlerden Kaldır',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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
                              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                              padding: EdgeInsets.symmetric(
                                horizontal: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              minimumSize: Size(0, isSmallScreen ? 44 : 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark 
                                      ? Colors.grey.withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.3),
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
                              backgroundColor: _getColor(),
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
                              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
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

  Widget _buildCardFront(SavedCard card, bool isSmallScreen, bool isVerySmallScreen) {
    // Dinamik font boyutu hesapla - metin uzunluğuna göre
    final textLength = card.frontText.length;
    double baseFontSize;
    
    if (textLength <= 30) {
      baseFontSize = isVerySmallScreen ? 24 : isSmallScreen ? 30 : 36;
    } else if (textLength <= 50) {
      baseFontSize = isVerySmallScreen ? 22 : isSmallScreen ? 28 : 34;
    } else if (textLength <= 100) {
      baseFontSize = isVerySmallScreen ? 20 : isSmallScreen ? 26 : 32;
    } else if (textLength <= 200) {
      baseFontSize = isVerySmallScreen ? 18 : isSmallScreen ? 24 : 30;
    } else {
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
            _getColor(),
            _getColor().withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getColor().withValues(alpha: 0.4),
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

  Widget _buildCardBack(SavedCard card, bool isSmallScreen, bool isVerySmallScreen) {
    // Dinamik font boyutu hesapla - metin uzunluğuna göre
    final textLength = card.backText.length;
    double baseFontSize;
    
    if (textLength <= 30) {
      baseFontSize = isVerySmallScreen ? 24 : isSmallScreen ? 30 : 36;
    } else if (textLength <= 50) {
      baseFontSize = isVerySmallScreen ? 22 : isSmallScreen ? 28 : 34;
    } else if (textLength <= 100) {
      baseFontSize = isVerySmallScreen ? 20 : isSmallScreen ? 26 : 32;
    } else if (textLength <= 200) {
      baseFontSize = isVerySmallScreen ? 18 : isSmallScreen ? 24 : 30;
    } else {
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
                'Tekrar görmek için dokun',
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
