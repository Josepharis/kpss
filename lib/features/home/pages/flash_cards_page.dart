import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/flash_card.dart';

class FlashCardsPage extends StatefulWidget {
  final String topicName;
  final int cardCount;

  const FlashCardsPage({
    super.key,
    required this.topicName,
    required this.cardCount,
  });

  @override
  State<FlashCardsPage> createState() => _FlashCardsPageState();
}

class _FlashCardsPageState extends State<FlashCardsPage>
    with SingleTickerProviderStateMixin {
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  List<FlashCard> get _cards {
    // Mock data
    return List.generate(
      widget.cardCount,
      (index) => FlashCard(
        id: '${index + 1}',
        frontText: 'Soru ${index + 1}: ${widget.topicName} konusunda önemli bir kavram nedir?',
        backText: 'Cevap ${index + 1}: Bu konuda önemli kavramlar şunlardır: Açıklama detayları burada yer alacak.',
      ),
    );
  }

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
  }

  @override
  void dispose() {
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
    }
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
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

