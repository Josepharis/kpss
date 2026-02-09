import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/services/quick_access_service.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../core/widgets/floating_home_button.dart';
import '../../../../main.dart';
import 'topic_detail_page.dart';
import 'subscription_page.dart';

class LessonDetailPage extends StatefulWidget {
  final Lesson lesson;

  const LessonDetailPage({
    super.key,
    required this.lesson,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  final LessonsService _lessonsService = LessonsService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isPremium = false;
  List<Topic> _topics = [];
  bool _isLoadingTopics = true;

  @override
  void initState() {
    super.initState();
    // Cache'den hemen kontrol et (non-blocking)
    _checkSubscriptionFromCache();
    // Arka planda Firestore'dan güncelle
    Future.microtask(() => _checkSubscription());
    // Konuları hemen yükle
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final topics = await _lessonsService.getTopicsByLessonId(widget.lesson.id);
      if (mounted) {
        setState(() {
          _topics = topics;
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

  Future<void> _checkSubscription() async {
    final isPremium = await _subscriptionService.isPremium();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
      });
    }
  }

  IconData _getIcon() {
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


  Future<void> _handleTopicTap(Topic topic) async {
    // Hızlı kontrol: order == 1 ise free, değilse premium gerekli
    final isFree = _subscriptionService.isTopicFree(topic);
    
    if (isFree) {
      // Free konu, direkt aç
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TopicDetailPage(
            topic: topic,
            lessonName: widget.lesson.name,
          ),
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
        builder: (context) => TopicDetailPage(
          topic: topic,
          lessonName: widget.lesson.name,
        ),
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
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryDarkBlue,
                    ],
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
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textPrimary,
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
                                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Text(
                              'Kapat',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary,
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
                                MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                              );
                              // Premium aktif edildiyse subscription durumunu yeniden kontrol et
                              if (result == true) {
                                await _checkSubscription();
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
                              shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundWhite,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: const FloatingHomeButton(),
        body: Column(
          children: [
            // Blue Header Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: statusBarHeight + (isSmallScreen ? 12 : 16),
                left: isTablet ? 24 : 18,
                right: isTablet ? 24 : 18,
                bottom: isSmallScreen ? 20 : 24,
              ),
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryDarkBlue,
                      ],
                    ),
              color: isDark ? const Color(0xFF1E1E1E) : null,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Watermark
                Positioned(
                  top: -20,
                  right: -20,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Text(
                      'KPSS',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.1),
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                // Content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row - Back button, Icon and Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Back button - more minimal
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 18 : 20,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 14 : 18),
                        // Icon - more prominent
                        Container(
                          width: isSmallScreen ? 56 : 64,
                          height: isSmallScreen ? 56 : 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getIcon(),
                            size: isSmallScreen ? 30 : 34,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 16 : 20),
                        // Title - better alignment
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final title = turkishToUpper(widget.lesson.name);
                                  final hasSpaces = title.trim().contains(' ');

                                  final style = TextStyle(
                                    fontSize: isSmallScreen ? 22 : 26,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    // Slightly reduced to prevent awkward breaks on long titles.
                                    letterSpacing: isSmallScreen ? 1.0 : 1.2,
                                    height: 1.2,
                                  );

                                  // If it's a single long word (e.g. "VATANDAŞLIK"),
                                  // don't let Flutter split it into awkward pieces like "VATANDAŞLI" + "K".
                                  if (!hasSpaces) {
                                    return FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        title,
                                        style: style,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.visible,
                                      ),
                                    );
                                  }

                                  // Multi-word titles can wrap nicely into 2 lines.
                                  return Text(
                                    title,
                                    style: style,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 14 : 18),
                    // Description and topic count
                    Padding(
                      padding: EdgeInsets.only(left: isSmallScreen ? 0 : 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lesson.description,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14.5,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 14),
                          Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 10 : 12,
                                  vertical: isSmallScreen ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${_topics.length} KONU',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
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
          // Topics List
          Expanded(
            child: _isLoadingTopics
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _topics.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 64,
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz konu eklenmemiş',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: isTablet ? 24 : 18,
                          right: isTablet ? 24 : 18,
                          top: isSmallScreen ? 12 : 16,
                          bottom: bottomPadding + (isSmallScreen ? 12 : 16),
                        ),
                        itemCount: _topics.length,
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          final topicNumber = (index + 1).toString().padLeft(2, '0');
                          
                          return _TopicListItem(
                            topic: topic,
                            topicNumber: topicNumber,
                            lessonName: widget.lesson.name,
                            isSmallScreen: isSmallScreen,
                            isDark: isDark,
                            onTap: () => _handleTopicTap(topic),
                          );
                        },
                      ),
          ),
        ],
      ),
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

  const _TopicListItem({
    required this.topic,
    required this.topicNumber,
    required this.lessonName,
    required this.isSmallScreen,
    required this.isDark,
    required this.onTap,
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
    final isFavorite = await QuickAccessService.isInQuickAccess(widget.topic.id);
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
      // Anasayfayı yenile
      final mainScreen = MainScreen.of(context);
      if (mainScreen != null) {
        mainScreen.refreshHomePage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: widget.isSmallScreen ? 14 : 18,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: widget.isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number
            Container(
              width: widget.isSmallScreen ? 40 : 44,
              alignment: Alignment.topLeft,
              child: Text(
                widget.topicNumber,
                style: TextStyle(
                  fontSize: widget.isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            SizedBox(width: widget.isSmallScreen ? 12 : 16),
            // Title
            Expanded(
              child: Text(
                widget.topic.name,
                style: TextStyle(
                  fontSize: widget.isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: widget.isSmallScreen ? 8 : 12),
            // Favorite button
            if (!_isLoadingFavorite)
              GestureDetector(
                onTap: () => _toggleFavorite(),
                child: Container(
                  padding: EdgeInsets.all(widget.isSmallScreen ? 6 : 8),
                  child: Icon(
                    _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _isFavorite ? Colors.amber : (widget.isDark ? Colors.white70 : AppColors.textSecondary),
                    size: widget.isSmallScreen ? 20 : 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
