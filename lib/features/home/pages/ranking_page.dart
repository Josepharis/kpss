import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/ranking_service.dart';
import '../../../core/widgets/premium_snackbar.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RankingService _rankingService = RankingService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  String _selectedSubject = 'Tarih';
  final List<String> _subjects = ['Tarih', 'Coğrafya', 'Vatandaşlık', 'Türkçe', 'Matematik', 'Eğitim'];

  List<RankingUser> _generalRankings = [];
  List<RankingUser> _subjectRankings = [];
  final Map<String, List<RankingUser>> _cachedSubjectRankings = {};
  
  int _userCurrentRank = 0;
  int _userCurrentScore = 0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isIndexError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadRankingData();
  }

  void _handleTabSelection() {
    // Only reload if we landed on a tab that has no data yet
    _loadRankingData();
  }

  Future<void> _loadRankingData({bool forceReload = false}) async {
    final int index = _tabController.index;
    
    // 1. If switching to "Deneme"
    if (index == 1) {
      if (mounted) {
        setState(() {
          _userCurrentRank = 0;
          _userCurrentScore = 0;
          _errorMessage = null;
        });
      }
      return; 
    }

    // 2. Determine if list data needs to be loaded from Firestore
    bool needsListReload = false;
    if (index == 0 && (_generalRankings.isEmpty || forceReload)) needsListReload = true;
    if (index == 2 && (!_cachedSubjectRankings.containsKey(_selectedSubject) || forceReload)) needsListReload = true;

    // 3. Immediate UI update if we have cached results for subjects
    if (index == 2 && _cachedSubjectRankings.containsKey(_selectedSubject) && !needsListReload) {
      if (mounted) {
        setState(() {
          _subjectRankings = _cachedSubjectRankings[_selectedSubject]!;
          _errorMessage = null;
          _isIndexError = false;
        });
      }
    }

    // Show spinner ONLY if we have no data at all for the target view
    if (needsListReload) {
      bool shouldShowSpinner = false;
      if (index == 0 && _generalRankings.isEmpty) shouldShowSpinner = true;
      if (index == 2 && !_cachedSubjectRankings.containsKey(_selectedSubject)) shouldShowSpinner = true;
      
      if (shouldShowSpinner && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }
    
    try {
      if (index == 0) {
        // Load General List if needed
        if (needsListReload) {
          _generalRankings = await _rankingService.getGeneralRankings();
        }
        // Always load current user general rank/score to ensure fresh data
        final rank = await _rankingService.getCurrentUserRank(_currentUserId);
        final score = await _rankingService.getCurrentUserScore(_currentUserId);
        if (mounted) {
          setState(() {
            _userCurrentRank = rank;
            _userCurrentScore = score;
            _errorMessage = null;
            _isIndexError = false;
          });
        }
      } else if (index == 2) {
        // Load Subject List if needed
        if (needsListReload) {
          debugPrint('🔍 Loading subject rankings for: $_selectedSubject');
          final results = await _rankingService.getSubjectRankings(_selectedSubject);
          _subjectRankings = results;
          _cachedSubjectRankings[_selectedSubject] = results;
          debugPrint('📊 Found ${results.length} users for $_selectedSubject');
          
          if (results.isEmpty && mounted) {
            debugPrint('Ranking results for $_selectedSubject are EMPTY');
          }
        }
        // Always load current user subject rank/score to ensure fresh data
        final rank = await _rankingService.getCurrentUserSubjectRank(_currentUserId, _selectedSubject);
        final score = await _rankingService.getCurrentUserSubjectScore(_currentUserId, _selectedSubject);
        if (mounted) {
          setState(() {
            _userCurrentRank = rank;
            _userCurrentScore = score;
            _errorMessage = null;
            _isIndexError = false;
          });
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase Error loading rankings: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isIndexError = (e.code == 'failed-precondition');
        });
        
        // Show index link in a dialog if it's an index error
        if (e.code == 'failed-precondition') {
          _showErrorDialog('Eksik Veritabanı Dizini', e.message ?? 'Verileri getirmek için index oluşturulması gerekiyor.');
        }
      }
    } catch (e) {
      debugPrint('Error loading rankings: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Beklenmedik bir hata oluştu: $e');
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // Background Glows
          if (isDark) ...[
            Positioned(
              top: -screenWidth * 0.3,
              right: -screenWidth * 0.3,
              child: _buildBlurCircle(
                size: screenWidth,
                color: const Color(0xFF10B981).withOpacity(0.15),
              ),
            ),
            Positioned(
              bottom: -screenWidth * 0.4,
              left: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.2,
                color: const Color(0xFF3B82F6).withOpacity(0.1),
              ),
            ),
          ],

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 20,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Başarı Sıralaması',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Premium Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.05) 
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Genel'),
                      Tab(text: 'Deneme'),
                      Tab(text: 'Ders'),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      RefreshIndicator(
                        onRefresh: () => _loadRankingData(forceReload: true),
                        color: const Color(0xFF10B981),
                        child: _buildRankingContent(_generalRankings, isDark, screenWidth),
                      ),
                      _buildEmptyDenemeState(isDark),
                      RefreshIndicator(
                        onRefresh: () => _loadRankingData(forceReload: true),
                        color: const Color(0xFF10B981),
                        child: _buildRankingContent(_subjectRankings, isDark, screenWidth, showSubjectFilter: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // User's own Rank Sticky (Floating at bottom)
          if (_tabController.index != 1)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _buildUserRankCard(isDark, _userCurrentRank, _userCurrentScore, _tabController.index == 0),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingContent(List<RankingUser> rankings, bool isDark, double screenWidth, {bool showSubjectFilter = false}) {
    if (_errorMessage != null) {
      return _buildErrorState(isDark);
    }

    if (!_isLoading && rankings.isEmpty) {
      return _buildEmptyState(isDark, showSubjectFilter ? '$_selectedSubject dersinde henüz sıralama yok.' : 'Henüz sıralama yok.');
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    // Top 3 and Others
    final top3 = rankings.length >= 3 ? rankings.sublist(0, 3) : rankings;
    final others = rankings.length > 3 ? rankings.sublist(3) : <RankingUser>[];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (showSubjectFilter)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _subjects.length,
                  itemBuilder: (context, index) {
                    final subject = _subjects[index];
                    final isSelected = _selectedSubject == subject;
                    return GestureDetector(
                      onTap: () {
                      if (_selectedSubject != subject) {
                        setState(() => _selectedSubject = subject);
                        _loadRankingData(forceReload: true);
                      }
                    },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF10B981).withOpacity(0.1) 
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white10 : Colors.black12),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            subject,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected 
                                  ? const Color(0xFF10B981) 
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

        // Podium Section
        if (top3.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 20),
              child: _buildEnhancedPodium(top3, isDark),
            ),
          ),

        // List Section
        SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0 && top3.isNotEmpty) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'DİĞER SIRALAMALAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white38 : Colors.black38,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  );
                }
                
                final rankUser = rankings.isEmpty ? null : (top3.isNotEmpty ? (index < others.length ? others[index] : null) : (index < rankings.length ? rankings[index] : null));
                if (rankUser == null) return const SizedBox.shrink();
                
                return _buildRankingItem(rankUser, isDark);
              },
              childCount: rankings.isEmpty ? 0 : (top3.isNotEmpty ? (others.length + 1) : rankings.length),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.withOpacity(0.5), size: 64),
          const SizedBox(height: 16),
          Text(
            _isIndexError ? 'Veritabanı Yapılandırması Eksik' : 'Bir Hata Oluştu',
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage ?? 'Bilinmeyen bir hata oluştu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadRankingData(forceReload: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tekrar Dene', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              PremiumSnackBar.show(context, message: 'Hata mesajı kopyalandı.', type: SnackBarType.success);
            },
            child: const Text('Kopyala'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 64, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDenemeState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, size: 48, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Deneme Sıralamaları Henüz Aktif Değil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Türkiye geneli deneme sınavları başladığında sıralamalar burada otomatik olarak gözükecektir.',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPodium(List<RankingUser> top3, bool isDark) {
    if (top3.isEmpty) return const SizedBox.shrink();

    // Map top 3 to correct positions (2nd, 1st, 3rd)
    RankingUser? first = top3.isNotEmpty ? top3[0] : null;
    RankingUser? second = top3.length > 1 ? top3[1] : null;
    RankingUser? third = top3.length > 2 ? top3[2] : null;

    // Dynamic heights based on screen size to prevent overflows
    final double screenHeight = MediaQuery.of(context).size.height;
    final double baseHeight = screenHeight * 0.15; // Responsive height
 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (second != null)
          _buildAnimatedPodiumItem(
            name: second.name,
            score: second.score.toString(),
            rank: 2,
            height: baseHeight * 0.7,
            colors: [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)],
            isDark: isDark,
            delay: 300,
          ),
          const SizedBox(width: 8),
          // 1st Place
          if (first != null)
          _buildAnimatedPodiumItem(
            name: first.name,
            score: first.score.toString(),
            rank: 1,
            height: baseHeight,
            colors: [const Color(0xFFFCD34D), const Color(0xFFF59E0B)],
            isDark: isDark,
            delay: 0,
            isWinner: true,
          ),
          const SizedBox(width: 8),
          // 3rd Place
          if (third != null)
          _buildAnimatedPodiumItem(
            name: third.name,
            score: third.score.toString(),
            rank: 3,
            height: baseHeight * 0.5,
            colors: [const Color(0xFFF97316), const Color(0xFFC2410C)],
            isDark: isDark,
            delay: 600,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPodiumItem({
    required String name,
    required String score,
    required int rank,
    required double height,
    required List<Color> colors,
    required bool isDark,
    required int delay,
    bool isWinner = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 800 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.none,
                  children: [
                    if (isWinner)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.2, end: 0.6),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOut,
                        builder: (context, glow, _) {
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(glow),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: isWinner ? 34 : 28,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1) : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colors[1],
                            fontSize: isWinner ? 22 : 16,
                          ),
                        ),
                      ),
                    ),
                    
                    if (isWinner)
                      const Positioned(
                        top: -26,
                        child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 34),
                      ),
                    
                    Positioned(
                      bottom: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                
                const SizedBox(height: 4),
                
                Container(
                  width: 90,
                  height: height * value,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [colors[0].withOpacity(0.9), colors[1].withOpacity(0.2)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          score,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -1),
                        ),
                        const Text(
                          'PUAN',
                          style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRankingItem(RankingUser user, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
              shape: BoxShape.circle,
            ),
            child: Text(
              user.rank.toString(),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: (user.rank % 2 == 0 ? const Color(0xFF6366F1) : const Color(0xFFA855F7)).withOpacity(0.1),
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w900,
                color: user.rank % 2 == 0 ? const Color(0xFF6366F1) : const Color(0xFFA855F7),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user.score.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF10B981),
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'PUAN',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankCard(bool isDark, int rank, int score, bool isGeneral) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGeneral ? 'SENİN SIRALAMAN (GENEL)' : 'SENİN SIRALAMAN ($_selectedSubject)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        rank > 0 ? rank.toString() : '-',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        ' . sırada',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toString(),
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    isGeneral ? 'Toplam Puan' : '$_selectedSubject Puanı',
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlurCircle({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.2, 1.0],
        ),
      ),
    );
  }
}
