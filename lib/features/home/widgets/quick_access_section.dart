import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/quick_access_service.dart';
import '../../../core/models/quick_access_item.dart';
import '../../../core/models/topic.dart';
import '../pages/podcasts_page.dart';
import '../pages/videos_page.dart';
import '../pages/flash_cards_page.dart';
import '../pages/topic_detail_page.dart';
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
            vertical: 12.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: AppColors.primaryBlue,
                      size: 16, // Matched with ongoing section icons (16)
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ), // Matched with ongoing sections (10)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Favorilerim',
                        style: TextStyle(
                          fontSize: widget.isSmallScreen
                              ? 14.0
                              : 15.0, // Matched with ongoing sections
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          letterSpacing: -0.5, // Matched with ongoing sections
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 24,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_items.length > 3)
                Text(
                  '${_items.length} Konu',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height:
              185, // Increased slightly to 185 to prevent overflow while staying compact
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20.0 : 16.0),
            itemCount: _items.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.only(right: 14, bottom: 10, top: 4),
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

class _FavoriteTopicCardState extends State<FavoriteTopicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getLessonColor() {
    final name = widget.item.lessonName.toLowerCase();
    if (name.contains('tarih')) return const Color(0xFFFFAB40);
    if (name.contains('coğrafya')) return const Color(0xFF00E676);
    if (name.contains('vatandaşlık')) return const Color(0xFFFF5252);
    if (name.contains('türkçe')) return const Color(0xFF448AFF);
    if (name.contains('matematik')) return const Color(0xFF7C4DFF);
    if (name.contains('eğitim')) return const Color(0xFFFF4081);
    return const Color(0xFF00B0FF);
  }

  IconData _getLessonIcon() {
    final name = widget.item.lessonName.toLowerCase();
    if (name.contains('tarih')) return Icons.auto_stories_rounded;
    if (name.contains('coğrafya')) return Icons.public_rounded;
    if (name.contains('vatandaşlık')) return Icons.gavel_rounded;
    if (name.contains('türkçe')) return Icons.translate_rounded;
    if (name.contains('matematik')) return Icons.calculate_rounded;
    return Icons.school_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getLessonColor();
    final cardIcon = _getLessonIcon();

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 160, // Reduced from 170 for a more compact feel
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // 1. Midnight Dark Gradient Background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: const [Color(0xFF1E1E2C), Color(0xFF0F0F1A)],
                        ),
                      ),
                    ),
                  ),

                  // 3. Watermark Icon
                  Positioned(
                    top: -10,
                    right: -10,
                    child: Opacity(
                      opacity: 0.08,
                      child: Transform.rotate(
                        angle: -0.3,
                        child: Icon(cardIcon, size: 80, color: Colors.white),
                      ),
                    ),
                  ),

                  // 4. Content Overlay
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TopicDetailPage(
                              topic: Topic(
                                id: widget.item.topicId,
                                lessonId: widget.item.lessonId,
                                name: widget.item.topicName,
                                subtitle: '${widget.item.topicName} konusu',
                                duration: '0h 0min',
                                averageQuestionCount: 0,
                                testCount: 1,
                                podcastCount: widget.item.podcastCount,
                                videoCount: widget.item.videoCount,
                                noteCount: 0,
                                flashCardCount: widget.item.flashCardCount,
                                pdfCount: widget.item.pdfCount,
                                progress: 0.0,
                                order: 0,
                              ),
                              lessonName: widget.item.lessonName,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10), // Reduced from 12
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Glassy Header Bar
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    widget.item.lessonName,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: accentColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () =>
                                      widget.onRemove(widget.item.topicId),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4), // Reduced from 6
                            Text(
                              widget.item.topicName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            // Action Tiles (Luxe version)
                            Row(
                              children: [
                                _buildLuxeTile(
                                  icon: Icons.article_rounded,
                                  label: 'PDF',
                                  count: widget.item.pdfCount,
                                  color: const Color(0xFFEF5350),
                                  onTap: () =>
                                      widget.onNavigatePdfs(widget.item),
                                ),
                                const SizedBox(width: 4),
                                _buildLuxeTile(
                                  icon: Icons.play_circle_fill_rounded,
                                  label: 'Video',
                                  count: widget.item.videoCount,
                                  color: const Color(0xFF42A5F5),
                                  onTap: () =>
                                      widget.onNavigateVideos(widget.item),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 4,
                            ), // Increased from 2 for "sufficient" space
                            Row(
                              children: [
                                _buildLuxeTile(
                                  icon: Icons.headphones_rounded,
                                  label: 'Podcast',
                                  count: widget.item.podcastCount,
                                  color: const Color(0xFFAB47BC),
                                  onTap: () =>
                                      widget.onNavigatePodcasts(widget.item),
                                ),
                                const SizedBox(width: 4),
                                _buildLuxeTile(
                                  icon: Icons.style_rounded,
                                  label: 'Bilgi Kartı',
                                  count: widget.item.flashCardCount,
                                  color: const Color(0xFFFFA726),
                                  onTap: () =>
                                      widget.onNavigateFlashCards(widget.item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxeTile({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool isEmpty = count == 0;
    return Expanded(
      child: GestureDetector(
        onTap: isEmpty ? null : onTap,
        child: Opacity(
          opacity: isEmpty ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
