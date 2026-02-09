import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/quick_access_service.dart';
import '../../../core/models/quick_access_item.dart';
import '../../../core/models/topic.dart';
import '../pages/tests_page.dart';
import '../pages/podcasts_page.dart';
import '../pages/videos_page.dart';
import '../pages/flash_cards_page.dart';
import '../pages/pdfs_page.dart';

class QuickAccessSection extends StatefulWidget {
  final bool isSmallScreen;

  const QuickAccessSection({super.key, this.isSmallScreen = false});

  @override
  State<QuickAccessSection> createState() => _QuickAccessSectionState();
}

class _QuickAccessSectionState extends State<QuickAccessSection> {
  List<QuickAccessItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await QuickAccessService.getQuickAccessItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeItem(String topicId) async {
    await QuickAccessService.removeQuickAccessItem(topicId);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading || _items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20.0 : 16.0,
            vertical: 8.0,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Favorilerim',
                style: TextStyle(
                  fontSize: widget.isSmallScreen ? 16.0 : 18.0,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 170, // Increased height for 3 full items + scroll hint
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20.0 : 16.0),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FavoriteTopicCard(
                  item: item,
                  isDark: isDark,
                  onRemove: _removeItem,
                  onNavigatePdfs: _navigateToPdfs,
                  onNavigatePodcasts: _navigateToPodcasts,
                  onNavigateVideos: _navigateToVideos,
                  onNavigateFlashCards: _navigateToFlashCards,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _navigateToPdfs(QuickAccessItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfsPage(
          topicName: item.topicName,
          pdfCount: item.pdfCount,
          topicId: item.topicId,
          lessonId: item.lessonId,
          topic: Topic(
            id: item.topicId,
            lessonId: item.lessonId,
            name: item.topicName,
            subtitle: '${item.topicName} konusu',
            duration: '0h 0min',
            averageQuestionCount: 0,
            testCount: 1,
            podcastCount: item.podcastCount,
            videoCount: item.videoCount,
            noteCount: 0,
            flashCardCount: item.flashCardCount,
            pdfCount: item.pdfCount,
            progress: 0.0,
            order: 0,
          ),
        ),
      ),
    );
  }

  void _navigateToPodcasts(QuickAccessItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PodcastsPage(
          topicName: item.topicName,
          podcastCount: item.podcastCount,
          topicId: item.topicId,
          lessonId: item.lessonId,
        ),
      ),
    );
  }

  void _navigateToVideos(QuickAccessItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideosPage(
          topicName: item.topicName,
          videoCount: item.videoCount,
          topicId: item.topicId,
          lessonId: item.lessonId,
        ),
      ),
    );
  }

  void _navigateToFlashCards(QuickAccessItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FlashCardsPage(
          topicName: item.topicName,
          cardCount: item.flashCardCount,
          topicId: item.topicId,
          lessonId: item.lessonId,
        ),
      ),
    );
  }
}

class FavoriteTopicCard extends StatefulWidget {
  final QuickAccessItem item;
  final bool isDark;
  final Function(String) onRemove;
  final Function(QuickAccessItem) onNavigatePdfs;
  final Function(QuickAccessItem) onNavigatePodcasts;
  final Function(QuickAccessItem) onNavigateVideos;
  final Function(QuickAccessItem) onNavigateFlashCards;

  const FavoriteTopicCard({
    super.key,
    required this.item,
    required this.isDark,
    required this.onRemove,
    required this.onNavigatePdfs,
    required this.onNavigatePodcasts,
    required this.onNavigateVideos,
    required this.onNavigateFlashCards,
  });

  @override
  State<FavoriteTopicCard> createState() => _FavoriteTopicCardState();
}

class _FavoriteTopicCardState extends State<FavoriteTopicCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: widget.isDark
              ? Colors.white10
              : Colors.black.withValues(alpha: 0.02),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.topicName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark
                              ? Colors.white
                              : AppColors.textPrimary,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.lessonName,
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark
                              ? Colors.white38
                              : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.onRemove(widget.item.topicId),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: widget.isDark ? Colors.white24 : Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Content
          Expanded(
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thumbColor: widget.isDark ? Colors.white24 : Colors.grey.shade400,
              thickness: 4,
              radius: const Radius.circular(2),
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildContentRow(
                    label: 'Konu Anlatımı',
                    count: widget.item.pdfCount,
                    icon: Icons.picture_as_pdf_rounded,
                    color: const Color(0xfff5a623),
                    onTap: () => widget.onNavigatePdfs(widget.item),
                  ),
                  const SizedBox(height: 4),
                  _buildContentRow(
                    label: 'Podcast',
                    count: widget.item.podcastCount,
                    icon: Icons.mic_none_rounded,
                    color: const Color(0xff9013fe),
                    onTap: () => widget.onNavigatePodcasts(widget.item),
                  ),
                  const SizedBox(height: 4),
                  _buildContentRow(
                    label: 'Video',
                    count: widget.item.videoCount,
                    icon: Icons.play_circle_outline_rounded,
                    color: const Color(0xfff44336),
                    onTap: () => widget.onNavigateVideos(widget.item),
                  ),
                  const SizedBox(height: 4),
                  _buildContentRow(
                    label: 'Bilgi Kartı',
                    count: widget.item.flashCardCount,
                    icon: Icons.filter_none_rounded,
                    color: const Color(0xffd0021b),
                    onTap: () => widget.onNavigateFlashCards(widget.item),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentRow({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: count > 0 ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ), // İdeal yükseklik
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark
                      ? Colors.white70
                      : color.withValues(alpha: 0.8),
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: widget.isDark
                    ? Colors.white24
                    : color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
