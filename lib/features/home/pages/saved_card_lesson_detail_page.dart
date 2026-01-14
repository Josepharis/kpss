import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/saved_cards_service.dart' show SavedCard, SavedCardsService;
import 'saved_card_topic_detail_page.dart';

class SavedCardLessonDetailPage extends StatefulWidget {
  final Lesson lesson;

  const SavedCardLessonDetailPage({
    super.key,
    required this.lesson,
  });

  @override
  State<SavedCardLessonDetailPage> createState() => _SavedCardLessonDetailPageState();
}

class _SavedCardLessonDetailPageState extends State<SavedCardLessonDetailPage> {
  Map<String, List<SavedCard>> _groupedByTopic = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final savedCards = await SavedCardsService.getSavedCardsByLesson(widget.lesson.id);
      final Map<String, List<SavedCard>> grouped = {};

      for (var card in savedCards) {
        if (!grouped.containsKey(card.topicName)) {
          grouped[card.topicName] = [];
        }
        grouped[card.topicName]!.add(card);
      }

      if (mounted) {
        setState(() {
          _groupedByTopic = grouped;
          _isLoading = false;
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
        return AppColors.gradientGreenStart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final topics = _groupedByTopic.keys.toList();
    final totalCards = _groupedByTopic.values.fold<int>(0, (sum, list) => sum + list.length);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // Header (Kompakt)
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + (isSmallScreen ? 4 : 6),
              bottom: isSmallScreen ? 8 : 10,
              left: isTablet ? 16 : 12,
              right: isTablet ? 16 : 12,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getColor(),
                  _getColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: isSmallScreen ? 18 : 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.lesson.name,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalCards kaydedilmiş kart • ${topics.length} konu',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loadSavedCards,
                  tooltip: 'Yenile',
                ),
              ],
            ),
          ),
          // Topics List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  )
                : topics.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.style_outlined,
                              size: 80,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bu derste kaydedilmiş kart yok',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSavedCards,
                        color: AppColors.primaryBlue,
                        child: ListView.builder(
                          padding: EdgeInsets.all(isTablet ? 20 : 16),
                          itemCount: topics.length,
                          itemBuilder: (context, index) {
                            final topicName = topics[index];
                            final cards = _groupedByTopic[topicName]!;
                            final cardCount = cards.length;

                            return Container(
                              margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SavedCardTopicDetailPage(
                                          lesson: widget.lesson,
                                          topicName: topicName,
                                        ),
                                      ),
                                    ).then((_) {
                                      // Sayfa döndüğünde kartları yeniden yükle
                                      _loadSavedCards();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                topicName,
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 16 : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.gradientGreenStart.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.style_rounded,
                                                          size: isSmallScreen ? 14 : 16,
                                                          color: AppColors.gradientGreenStart,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$cardCount kart',
                                                          style: TextStyle(
                                                            fontSize: isSmallScreen ? 12 : 13,
                                                            fontWeight: FontWeight.w600,
                                                            color: AppColors.gradientGreenStart,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: isSmallScreen ? 18 : 20,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
