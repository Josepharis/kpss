import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/quick_access_service.dart';
import '../../../core/widgets/floating_home_button.dart';
import '../../../../main.dart';
import 'topic_detail_page.dart';
import 'subscription_page.dart';

class LessonDetailPage extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailPage({super.key, required this.lesson});

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  final LessonsService _lessonsService = LessonsService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isPremium = false;
  List<Topic> _topics = [];
  bool _isLoadingTopics = true;
  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _totalQuestions = widget.lesson.questionCount;
    // Cache'den hemen kontrol et (non-blocking)
    _checkSubscriptionFromCache();
    // Arka planda Firestore'dan güncelle
    Future.microtask(() => _checkSubscription());
    // Konuları hemen yükle
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _lessonsService.getTopicsByLessonId(
        widget.lesson.id,
      );

      final prefs = await SharedPreferences.getInstance();
      int totalQ = 0;

      for (int i = 0; i < topics.length; i++) {
        final t = topics[i];
        int qCount = t.averageQuestionCount;
        int pCount = t.podcastCount;
        int vCount = t.videoCount;
        int fCount = t.flashCardCount;
        int pdfCount = t.pdfCount;

        // Try load from combined cache first
        final contentCountsJson = prefs.getString('content_counts_${t.id}');
        if (contentCountsJson != null && contentCountsJson.isNotEmpty) {
          try {
            final Map<String, dynamic> counts = jsonDecode(contentCountsJson);
            vCount = counts['videoCount'] as int? ?? vCount;
            pCount = counts['podcastCount'] as int? ?? pCount;
            fCount = counts['flashCardCount'] as int? ?? fCount;
            pdfCount = counts['pdfCount'] as int? ?? pdfCount;
            qCount = counts['testQuestionCount'] as int? ?? qCount;
          } catch (_) {}
        }

        // Fallback to specific questions cache
        if (qCount == 0 || qCount == t.averageQuestionCount) {
          int fallbackQCount = prefs.getInt('questions_count_${t.id}') ?? 0;
          if (fallbackQCount > 0) qCount = fallbackQCount;
        }

        totalQ += qCount;

        topics[i] = Topic(
          id: t.id,
          lessonId: t.lessonId,
          name: t.name,
          subtitle: t.subtitle,
          duration: t.duration,
          averageQuestionCount: qCount,
          testCount: qCount > 0 ? 1 : 0,
          podcastCount: pCount,
          videoCount: vCount,
          noteCount: t.noteCount,
          flashCardCount: fCount,
          pdfCount: pdfCount,
          progress: t.progress,
          order: t.order,
          pdfUrl: t.pdfUrl,
        );
      }

      if (mounted) {
        setState(() {
          _topics = topics;
          _totalQuestions = totalQ > 0 ? totalQ : widget.lesson.questionCount;
          _isLoadingTopics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTopics = false;
        });
      }
    }
  }

  Future<void> _checkSubscriptionFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getString('subscription_status');
      final cachedEndDate = prefs.getInt('subscription_end_date');

      if (cachedStatus == 'premium' && cachedEndDate != null) {
        final endDate = DateTime.fromMillisecondsSinceEpoch(cachedEndDate);
        if (endDate.isAfter(DateTime.now())) {
          setState(() {
            _isPremium = true;
          });
          return;
        }
      }
      setState(() {
        _isPremium = false;
      });
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _checkSubscription({bool forceRefresh = false}) async {
    final isPremium = await _subscriptionService.isPremium(
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
      });
    }
  }

  Future<void> _handleTopicTap(Topic topic) async {
    // Hızlı kontrol: order == 1 ise free, değilse premium gerekli
    final isFree = _subscriptionService.isTopicFree(topic);

    if (isFree) {
      // Free konu, direkt aç
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TopicDetailPage(topic: topic, lessonName: widget.lesson.name),
        ),
      );
      return;
    }

    // Premium konu - cache'den kontrol et (hızlı)
    if (!_isPremium) {
      // Premium gerekli - upgrade sayfasına yönlendir
      _showPremiumRequiredDialog(context, topic);
      return;
    }

    // Premium var, sayfayı aç
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TopicDetailPage(topic: topic, lessonName: widget.lesson.name),
      ),
    );
  }

  void _showPremiumRequiredDialog(BuildContext context, Topic topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryBlue, AppColors.primaryDarkBlue],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // Premium Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Premium Gerekli',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Bu konuya erişmek için Premium aboneliğe ihtiyacınız var.',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : AppColors.textPrimary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Her dersin ilk konusu ücretsizdir',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              'Kapat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SubscriptionPage(),
                                ),
                              );
                              // Premium aktif edildiyse subscription durumunu yeniden kontrol et
                              if (result == true) {
                                await _checkSubscription(forceRefresh: true);
                                await _checkSubscriptionFromCache();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: AppColors.primaryBlue.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Premium\'a Geç',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lessonColor = _getLessonColor();
    final screenWidth = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0F1A)
            : const Color(0xFFF8FAFF),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: const FloatingHomeButton(),
        body: Stack(
          children: [
            // 1. Dynamic Mesh Background
            _buildMeshBackground(isDark, screenWidth, lessonColor),

            // 2. Main Scroll Content
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Ultra-Premium Immersive Header
                SliverAppBar(
                  expandedHeight: 105,
                  collapsedHeight: 60,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leadingWidth: 64,
                  leading: Center(
                    child: _buildGlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Main Gradient Background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                lessonColor,
                                lessonColor.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                        // Large Filigree Icon
                        Positioned(
                          right: -10,
                          bottom: 0,
                          child: Opacity(
                            opacity: 0.12,
                            child: Transform.rotate(
                              angle: -0.15,
                              child: Icon(
                                _getLessonIcon(),
                                size: 120,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Header Content
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            64,
                            MediaQuery.of(context).padding.top + 6,
                            20,
                            0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lesson.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.2,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 15,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildHeaderStats(lessonColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 140),
                  sliver: _isLoadingTopics
                      ? const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _topics.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState(isDark))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final topic = _topics[index];
                            final topicNumber = (index + 1).toString().padLeft(
                              2,
                              '0',
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TopicListItem(
                                topic: topic,
                                topicNumber: topicNumber,
                                lessonName: widget.lesson.name,
                                isSmallScreen:
                                    MediaQuery.of(context).size.height < 700,
                                isDark: isDark,
                                onTap: () => _handleTopicTap(topic),
                                lessonColor: lessonColor,
                              ),
                            );
                          }, childCount: _topics.length),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(
    bool isDark,
    double screenWidth,
    Color lessonColor,
  ) {
    return Positioned.fill(
      child: Container(
        color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFF),
        child: Stack(
          children: [
            _buildBlurSpot(
              -screenWidth * 0.4,
              -screenWidth * 0.4,
              screenWidth * 1.4,
              lessonColor.withOpacity(isDark ? 0.25 : 0.15),
            ),
            _buildBlurSpot(
              screenWidth * 0.5,
              -screenWidth * 0.1,
              screenWidth * 1.1,
              const Color(0xFF7C3AED).withOpacity(isDark ? 0.2 : 0.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlurSpot(double top, double left, double size, Color color) {
    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 110, sigmaY: 110),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildHeaderStats(Color color) {
    return Row(
      children: [
        _buildGlassStat(Icons.menu_book_rounded, '${_topics.length}', 'Ünite'),
        const SizedBox(width: 14),
        _buildGlassStat(Icons.help_outline_rounded, '$_totalQuestions', 'Soru'),
      ],
    );
  }

  Widget _buildGlassStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Color _getLessonColor() {
    switch (widget.lesson.color) {
      case 'orange':
        return const Color(0xFFFF8C32);
      case 'blue':
        return const Color(0xFF00D2FF);
      case 'red':
        return const Color(0xFFFF4B2B);
      case 'green':
        return const Color(0xFF00F260);
      case 'purple':
        return const Color(0xFF8E2DE2);
      case 'teal':
        return const Color(0xFF00C9FF);
      case 'indigo':
        return const Color(0xFF396AFC);
      case 'pink':
        return const Color(0xFFFF00CC);
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getLessonIcon() {
    switch (widget.lesson.icon) {
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'calculate':
        return Icons.calculate_rounded;
      case 'history':
        return Icons.history_rounded;
      case 'map':
        return Icons.map_rounded;
      case 'gavel':
        return Icons.gavel_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      default:
        return Icons.book_rounded;
    }
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          const Text(
            'İçerik Hazırlanıyor',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicListItem extends StatefulWidget {
  final Topic topic;
  final String topicNumber;
  final String lessonName;
  final bool isSmallScreen;
  final bool isDark;
  final VoidCallback onTap;
  final Color lessonColor;

  const _TopicListItem({
    required this.topic,
    required this.topicNumber,
    required this.lessonName,
    required this.isSmallScreen,
    required this.isDark,
    required this.onTap,
    required this.lessonColor,
  });

  @override
  State<_TopicListItem> createState() => _TopicListItemState();
}

class _TopicListItemState extends State<_TopicListItem> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await QuickAccessService.isInQuickAccess(
      widget.topic.id,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
        _isLoadingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final newFavoriteState = await QuickAccessService.toggleQuickAccessItem(
      topicId: widget.topic.id,
      lessonId: widget.topic.lessonId,
      topicName: widget.topic.name,
      lessonName: widget.lessonName,
      podcastCount: widget.topic.podcastCount,
      videoCount: widget.topic.videoCount,
      flashCardCount: widget.topic.flashCardCount,
      pdfCount: widget.topic.pdfCount,
    );
    if (mounted) {
      setState(() {
        _isFavorite = newFavoriteState;
      });
      MainScreen.of(context)?.refreshHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: widget.isDark ? Colors.white.withOpacity(0.12) : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.4 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  // Premium Gradient Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.lessonColor,
                          widget.lessonColor.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.lessonColor.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.topicNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.topic.name,
                          style: TextStyle(
                            fontSize: widget.isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isLoadingFavorite)
                        GestureDetector(
                          onTap: _toggleFavorite,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (widget.isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.04),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: _isFavorite
                                  ? Colors.amber
                                  : (widget.isDark
                                        ? Colors.white24
                                        : Colors.grey.shade300),
                              size: 20,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: widget.isDark
                            ? Colors.white24
                            : Colors.grey.shade300,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
