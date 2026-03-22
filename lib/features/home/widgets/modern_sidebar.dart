import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:ui';
import '../pages/modern_pomodoro_page.dart';
import '../pages/ai_assistant_page.dart';
import '../pages/news_detail_page.dart';
import '../../../core/services/sidebar_service.dart';
import '../../../core/models/sidebar_content.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/progress_service.dart';

class ModernSidebar extends StatefulWidget {
  final VoidCallback? onClose;
  final String? initialName;
  final int? initialScore;
  const ModernSidebar({super.key, this.onClose, this.initialName, this.initialScore});

  @override
  State<ModernSidebar> createState() => _ModernSidebarState();
}

class _ModernSidebarState extends State<ModernSidebar> {
  List<NewsItem> _news = [];
  DailyInfo? _dailyInfo;
  List<ExamDate> _examDates = [];
  bool _isLoading = true;
  String _userName = 'Kullanıcı';
  int _userTotalScore = 0;

  @override
  void initState() {
    super.initState();
    _userName = widget.initialName ?? 'Kullanıcı';
    _userTotalScore = widget.initialScore ?? 0;
    _isLoading = !SidebarService.instance.hasCache;
    _loadContent();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final name = await AuthService().getUserName();
      final score = await ProgressService().getUserTotalScore();
      if (mounted) {
        setState(() {
          _userName = name ?? 'Kullanıcı';
          _userTotalScore = score;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadContent() async {
    // Only show loading if we don't have any cached data at all
    final hasCache = SidebarService.instance.hasCache;
    if (!hasCache) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final futures = await Future.wait([
        SidebarService.instance.getNews(),
        SidebarService.instance.getDailyInfo(),
        SidebarService.instance.getExamDates(),
      ]);
      
      if (mounted) {
        setState(() {
          _news = futures[0] as List<NewsItem>;
          _dailyInfo = futures[1] as DailyInfo;
          _examDates = futures[2] as List<ExamDate>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı açılamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = MediaQuery.of(context).padding;

    return Stack(
      children: [
        // Full screen blur
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose ?? () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black26),
            ),
          ),
        ),
        
        // Sidebar Content
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: screenWidth * 0.75, // Reduced width
              height: double.infinity,
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF0F172A).withValues(alpha: 0.98) 
                    : Colors.white.withValues(alpha: 0.98),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(10, 0),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Close Button - Integrated better
                  Positioned(
                    top: padding.top + 10,
                    right: 12,
                    child: IconButton(
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white38 : Colors.black26,
                        size: 22,
                      ),
                    ),
                  ),

                  SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumHeader(context, isDark),
                        Expanded(
                          child: _isLoading 
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                            : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('ÖZELLİKLER', isDark),
                                const SizedBox(height: 12),
                                _buildFeatureGrid(context, isDark),
                                const SizedBox(height: 24),
                                
                                _buildSectionTitle('BÜLTEN', isDark),
                                const SizedBox(height: 12),
                                _buildNewsSection(context, isDark),
                                const SizedBox(height: 24),
                                
                                _buildSectionTitle('BİLİYOR MUYDUNUZ?', isDark),
                                const SizedBox(height: 12),
                                _buildDailyInfoCard(isDark),
                                const SizedBox(height: 24),

                                _buildSectionTitle('SINAV TAKVİMİ', isDark),
                                const SizedBox(height: 12),
                                _buildExamCalendar(isDark),
                                const SizedBox(height: 32),
                                
                                _buildLogoutButton(isDark),
                                SizedBox(height: padding.bottom + 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3366), Color(0xFFFFAC33)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF3366).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_userTotalScore PUAN',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFD97706),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassFeatureCard(
            context,
            'Pomodoro',
            'Odaklan',
            Icons.timer_rounded,
            const [Color(0xFF6366F1), Color(0xFF4F46E5)],
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModernPomodoroPage(standalonePomodoro: true))),
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGlassFeatureCard(
            context,
            'Yapay Zeka',
            'Asistan',
            Icons.auto_awesome_rounded,
            const [Color(0xFFA855F7), Color(0xFF7C3AED)],
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAssistantPage())),
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassFeatureCard(
    BuildContext context, 
    String title,
    String subtitle,
    IconData icon, 
    List<Color> colors, 
    VoidCallback onTap,
    bool isDark,
  ) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[0].withOpacity(0.15), colors[1].withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors[0].withOpacity(0.2), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors[0],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors[0].withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSection(BuildContext context, bool isDark) {
    if (_news.isEmpty) return const SizedBox.shrink();
    
    return Column(
      children: _news.take(2).map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (item.url != null && item.url!.isNotEmpty) {
                _launchURL(item.url);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailPage(news: item)));
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.date,
                          style: TextStyle(
                            fontSize: 10, 
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildDailyInfoCard(bool isDark) {
    if (_dailyInfo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F172A).withValues(alpha: 0.05),
            const Color(0xFF334155).withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tips_and_updates_rounded, color: Colors.blueAccent, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                _dailyInfo!.title,
                style: TextStyle(
                  color: isDark ? Colors.blueAccent.shade100 : Colors.blueAccent.shade700,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _dailyInfo!.content,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCalendar(bool isDark) {
    if (_examDates.isEmpty) return const SizedBox.shrink();

    final dateFormat = intl.DateFormat('dd.MM.yyyy', 'tr_TR');

    return Column(
      children: _examDates.map((exam) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                exam.title,
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateFormat.format(exam.date),
              style: const TextStyle(
                fontSize: 11, 
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return OutlinedButton(
      onPressed: () => AuthService().logout(),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        side: const BorderSide(color: Color(0xFFEF4444), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 44),
      ),
      child: const Text('Oturumu Kapat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}
