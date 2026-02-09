import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ongoing_flash_card.dart';
import '../../../core/services/progress_service.dart';
import '../../../../main.dart';
import 'flash_cards_page.dart';

class OngoingFlashCardsListPage extends StatefulWidget {
  final List<OngoingFlashCard> flashCards;

  const OngoingFlashCardsListPage({
    super.key,
    required this.flashCards,
  });

  @override
  State<OngoingFlashCardsListPage> createState() => _OngoingFlashCardsListPageState();
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
        title: const Text('Bilgi kartı ilerlemesi sıfırlansın mı?'),
        content: Text('"${flashCard.topic}" için kaldığın kart silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _resetFlashCard(OngoingFlashCard flashCard) async {
    final confirmed = await _confirmReset(flashCard);
    if (!confirmed) return;

    await _progressService.deleteFlashCardProgress(flashCard.topicId);
    if (!mounted) return;

    setState(() {
      _flashCards.removeWhere((f) => f.topicId == flashCard.topicId);
      _didChange = true;
    });
    await _saveToCache();

    if (!mounted) return;
    MainScreen.of(context)?.refreshHomePage();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bilgi kartı ilerlemesi sıfırlandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.gradientGreenStart,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
          onPressed: () => Navigator.of(context).pop(_didChange),
        ),
        title: Text(
          'Devam Eden Bilgi Kartları',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _flashCards.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Devam eden bilgi kartı bulunmuyor',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              itemCount: _flashCards.length,
              itemBuilder: (context, index) {
                final flashCard = _flashCards[index];
                return Card(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
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
                    contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    leading: Container(
                      width: isSmallScreen ? 50 : 60,
                      height: isSmallScreen ? 50 : 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gradientGreenStart,
                            AppColors.gradientGreenEnd,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.book_rounded,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    title: Text(
                      flashCard.topic,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${flashCard.currentCard}/${flashCard.totalCards} kart • %${(flashCard.progress * 100).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sıfırla',
                          onPressed: () => _resetFlashCard(flashCard),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red.shade400,
                            size: isSmallScreen ? 20 : 22,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                          size: isSmallScreen ? 20 : 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
