import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/topic.dart';
import '../../../core/services/lessons_service.dart';
import '../../../core/services/subscription_service.dart';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Premium Gerekli'),
        content: Text(
          'Bu konuya erişmek için Premium aboneliğe ihtiyacınız var.\n\n'
          'Her dersin ilk konusu ücretsizdir. Diğer konular için Premium\'a geçin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SubscriptionPage()),
            );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Premium\'a Geç'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundWhite,
      body: Column(
        children: [
          // Blue Header Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + (isSmallScreen ? 12 : 16),
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
                              Text(
                                widget.lesson.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  height: 1.2,
                                ),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 18,
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        itemCount: _topics.length,
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          final topicNumber = (index + 1).toString().padLeft(2, '0');
                          
                          final isFree = _subscriptionService.isTopicFree(topic);
                          final isLocked = !isFree && !_isPremium;
                          
                          return GestureDetector(
                            onTap: () => _handleTopicTap(topic),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14 : 18,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Number
                                  Container(
                                    width: isSmallScreen ? 40 : 44,
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      topicNumber,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.w700,
                                        color: isLocked 
                                            ? Colors.grey 
                                            : AppColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isSmallScreen ? 12 : 16),
                                  // Title
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            topic.name,
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 16 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: isLocked
                                                  ? Colors.grey
                                                  : (isDark ? Colors.white : AppColors.textPrimary),
                                            ),
                                          ),
                                        ),
                                        if (isLocked) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.lock_outline,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
