import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_lessons_page.dart';
import 'admin_notifications_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoadingStats = true;
  
  int _totalUsers = 0;
  int _androidUsers = 0;
  int _iosUsers = 0;
  int _activeSubscribers = 0;
  int _totalQuestions = 0;
  Map<String, int> _subscriptionTypes = {'monthly': 0, '6monthly': 0, 'yearly': 0};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      // 1. Total Users Breakdown
      final usersCollection = _firestore.collection('users');
      
      final totalRes = await usersCollection.count().get();
      _totalUsers = totalRes.count ?? 0;

      final androidRes = await usersCollection.where('platform', isEqualTo: 'android').count().get();
      _androidUsers = androidRes.count ?? 0;

      final iosRes = await usersCollection.where('platform', isEqualTo: 'ios').count().get();
      _iosUsers = iosRes.count ?? 0;

      // 2. Active Subscribers (Collection Group query)
      // Note: This might require an index, but let's try. 
      // If it fails, we fall back to a safer (but heavier) method or 0.
      try {
        final subsSnapshot = await _firestore
            .collectionGroup('subscription')
            .where('status', isEqualTo: 'premium')
            .where('endDate', isGreaterThan: Timestamp.now())
            .get();
        
        _activeSubscribers = subsSnapshot.docs.length;
        
        // Reset and count types
        _subscriptionTypes = {'monthly': 0, '6monthly': 0, 'yearly': 0};
        for (var doc in subsSnapshot.docs) {
          final type = doc.data()['type'] as String? ?? 'monthly';
          if (_subscriptionTypes.containsKey(type)) {
            _subscriptionTypes[type] = (_subscriptionTypes[type] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Collection group query error (likely index missing): $e');
        _activeSubscribers = 0;
      }

      // 3. Total Questions
      final questionsSnapshot = await _firestore.collection('questions').count().get();
      _totalQuestions = questionsSnapshot.count ?? 0;

      if (mounted) setState(() => _isLoadingStats = false);
    } catch (e) {
      debugPrint('Error loading admin stats: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'Yönetici Paneli',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsSection(isDark),
              const SizedBox(height: 20),
              _buildPlatformBreakdown(isDark),
              const SizedBox(height: 20),
              _buildSubscriptionBreakdown(isDark),
              const SizedBox(height: 30),
              const Text(
                'Yönetim Araçları',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 15),
              _buildAdminMenu(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformBreakdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E).withOpacity(0.5) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Platform Dağılımı (Kullanıcı)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Icon(Icons.devices_rounded, size: 16, color: Colors.grey.shade500),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPlatformItem('Android', _androidUsers, Icons.android, Colors.green),
              _buildPlatformItem('iOS', _iosUsers, Icons.apple, Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformItem(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildStatsSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _isLoadingStats 
          ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Toplam Kullanıcı', _totalUsers.toString(), Icons.people_rounded, Colors.blue),
                    _buildStatItem('Aktif Abone', _activeSubscribers.toString(), Icons.star_rounded, Colors.amber),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Soru Sayısı', _totalQuestions.toString(), Icons.quiz_rounded, Colors.purple),
                    _buildStatItem('Abonelik Oranı', 
                      _totalUsers > 0 ? '%${((_activeSubscribers / _totalUsers) * 100).toStringAsFixed(1)}' : '%0', 
                      Icons.trending_up_rounded, Colors.green),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSubscriptionBreakdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E).withOpacity(0.5) : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Abonelik Detayları',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat('Aylık', _subscriptionTypes['monthly'] ?? 0, Colors.blue),
              _buildMiniStat('6 Aylık', _subscriptionTypes['6monthly'] ?? 0, Colors.purple),
              _buildMiniStat('Yıllık', _subscriptionTypes['yearly'] ?? 0, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenu(BuildContext context, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.1,
      children: [
        _buildMenuCard(
          context,
          'Soru Bankası',
          'Soruları düzenle, sil',
          Icons.format_list_bulleted_rounded,
          const Color(0xFF6366F1),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLessonsPage(initialMode: 'questions')),
            );
          },
        ),
        _buildMenuCard(
          context,
          'Bölüm Yönetimi',
          'Üniteleri erişime aç',
          Icons.visibility_rounded,
          const Color(0xFFEC4899),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminLessonsPage(initialMode: 'publish')),
            );
          },
        ),
        _buildMenuCard(
          context,
          'Bildirim Gönder',
          'Kullanıcılara mesaj yolla',
          Icons.notifications_active_rounded,
          const Color(0xFF10B981),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminNotificationsPage()),
          ),
        ),
        _buildMenuCard(
          context,
          'Ayarlar',
          'Sistem yapılandırması',
          Icons.settings_suggest_rounded,
          const Color(0xFFF59E0B),
          () {},
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
