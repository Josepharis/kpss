import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/run_pdf_update.dart';
import '../../../core/services/storage_cleanup_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/widgets/premium_snackbar.dart';
import '../../../../main.dart';
import 'subscription_page.dart';
import 'about_app_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _selectedTheme = 'Açık';
  bool _isUpdatingPdfUrls = false;
  final StorageCleanupService _cleanupService = StorageCleanupService();
  final ProgressService _progressService = ProgressService();
  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _autoCleanupEnabled = true;
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.free();
  int _cleanupDays = 7;
  double _maxStorageGB = 5.0;
  double _currentStorageGB = 0.0;
  bool _isLoadingStorage = false;
  bool _showCurrentTaskOnHome = true;

  // User statistics
  String _userName = 'Kullanıcı';
  String _kpssType = '';
  int _solvedQuestions = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;
  double _successRate = 0.0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadUserData();
      _loadStatistics();
      _loadSubscriptionStatus();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _autoCleanupEnabled = await _cleanupService.isAutoCleanupEnabled();
      _cleanupDays = await _cleanupService.getCleanupDays();
      _maxStorageGB = await _cleanupService.getMaxStorageGB();
      _currentStorageGB = await _cleanupService.getTotalStorageUsed();

      setState(() {
        _selectedTheme = prefs.getString('selected_theme') ?? 'Açık';
        _showCurrentTaskOnHome =
            prefs.getBool('show_current_task_on_home') ?? true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userName = await _authService.getUserName();
      final kpssType = await _authService.getKpssType();
      if (mounted) {
        setState(() {
          _userName = userName ?? 'Kullanıcı';
          _kpssType = _getKpssTypeLabel(kpssType);
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  String _getKpssTypeLabel(String? type) {
    if (type == null) return '';
    switch (type) {
      case 'ortaOgretim':
        return 'Ortaöğretim KPSS';
      case 'onLisans':
        return 'Ön Lisans KPSS';
      case 'lisans':
        return 'Lisans KPSS';
      case 'ags':
        return 'AGS';
      default:
        return type;
    }
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await _progressService.getUserStatistics();
      if (mounted) {
        setState(() {
          _solvedQuestions = stats['solvedQuestions'] ?? 0;
          _correctAnswers = stats['correctAnswers'] ?? 0;
          _wrongAnswers = stats['wrongAnswers'] ?? 0;
          _successRate = _solvedQuestions > 0
              ? (_correctAnswers / _solvedQuestions * 100)
              : 0.0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadSubscriptionStatus({bool forceRefresh = false}) async {
    try {
      final status = await _subscriptionService.getSubscriptionStatus(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
        });
      }
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _refreshStorageInfo() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStorage = true;
    });

    final currentStorage = await _cleanupService.getTotalStorageUsed();

    if (mounted) {
      setState(() {
        _currentStorageGB = currentStorage;
        _isLoadingStorage = false;
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Public method to refresh all content on the profile page
  Future<void> refreshContent() async {
    if (!mounted) return;
    await Future.wait([
      _loadSettings(),
      _loadUserData(),
      _loadStatistics(),
      _loadSubscriptionStatus(forceRefresh: true),
      _refreshStorageInfo(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final compactPadding = isSmallScreen ? 12.0 : 14.0;
    final compactSpacing = isSmallScreen ? 6.0 : 10.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark
            ? const Color(0xFF010101)
            : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF010101)
            : const Color(0xFFF8FAFF),
        body: Stack(
          children: [
            // Layer 1: Mesh Background
            _buildMeshBackground(isDark, screenWidth),

            // Layer 2: Content
            Column(
              children: [
                // Premium Header
                _buildPremiumHeader(
                  statusBarHeight,
                  isDark,
                  screenWidth,
                  isSmallScreen,
                ),

                // Main Content Area
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refreshContent,
                    color: Colors.blueAccent,
                    backgroundColor: isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        compactPadding,
                        4,
                        compactPadding,
                        100,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Statistics
                          _buildStatisticsCard(isSmallScreen, compactSpacing),
                          SizedBox(height: compactSpacing),

                          // Subscription
                          _buildSubscriptionCard(isSmallScreen, compactSpacing),
                          SizedBox(height: compactSpacing + 4),

                          // Settings Sections
                          _buildSectionTitle('AYARLAR', isSmallScreen, isDark),
                          const SizedBox(height: 4),
                          _buildSettingsCard(
                            isDark: isDark,
                            children: [
                              _buildSettingTile(
                                icon: Icons.palette_rounded,
                                title: 'Tema Görünümü',
                                subtitle: 'Şu anki: $_selectedTheme',
                                onTap: () => _showThemeDialog(),
                                isSmallScreen: isSmallScreen,
                                isDark: isDark,
                                color: Colors.purpleAccent,
                              ),
                              _buildDivider(isDark),
                              _buildSwitchTile(
                                icon: Icons.task_alt_rounded,
                                title: 'Günün Görevi',
                                subtitle: 'Anasayfada günün görevini göster',
                                value: _showCurrentTaskOnHome,
                                onChanged: (val) async {
                                  setState(() => _showCurrentTaskOnHome = val);
                                  await _saveSetting(
                                    'show_current_task_on_home',
                                    val,
                                  );
                                },
                                isDark: isDark,
                                color: Colors.orangeAccent,
                              ),
                            ],
                          ),
                          SizedBox(height: compactSpacing + 4),

                          _buildSectionTitle(
                            'DEPOLAMA YÖNETİMİ',
                            isSmallScreen,
                            isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildStorageCard(
                            isSmallScreen,
                            compactSpacing,
                            isDark,
                          ),
                          SizedBox(height: compactSpacing + 4),

                          _buildSectionTitle(
                            'HAKKINDA & YARDIM',
                            isSmallScreen,
                            isDark,
                          ),
                          const SizedBox(height: 4),
                          _buildSettingsCard(
                            isDark: isDark,
                            children: [
                              _buildSettingTile(
                                icon: Icons.info_rounded,
                                title: 'Uygulama Bilgisi',
                                subtitle: 'Versiyon 1.0.0',
                                onTap: () => _showAboutDialog(),
                                isSmallScreen: isSmallScreen,
                                isDark: isDark,
                                color: Colors.blueAccent,
                              ),
                              _buildDivider(isDark),
                              _buildSettingTile(
                                icon: Icons.cloud_sync_rounded,
                                title: 'Veri Eşitleme',
                                subtitle: _isUpdatingPdfUrls
                                    ? 'Güncelleniyor...'
                                    : 'İçerikleri senkronize et',
                                onTap: _isUpdatingPdfUrls
                                    ? null
                                    : () => _updatePdfUrls(),
                                isSmallScreen: isSmallScreen,
                                isDark: isDark,
                                color: Colors.tealAccent,
                              ),
                              _buildDivider(isDark),
                              _buildSettingTile(
                                icon: Icons.star_outline_rounded,
                                title: 'Premium Aktifleştir (Dev)',
                                subtitle: 'Simülatör için geçici çözüm',
                                onTap: () => _activatePremiumDev(),
                                isSmallScreen: isSmallScreen,
                                isDark: isDark,
                                color: Colors.orangeAccent,
                              ),
                            ],
                          ),
                          SizedBox(height: compactSpacing + 8),

                          // Account Actions
                          _buildLogoutButton(isSmallScreen, isDark),
                          const SizedBox(height: 8),
                          _buildDeleteAccountButton(isSmallScreen, isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark, double screenWidth) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF010101) : const Color(0xFFF8FAFF),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0D0221),
                    const Color(0xFF010101),
                    const Color(0xFF050505),
                  ]
                : [const Color(0xFFF0F4FF), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -screenWidth * 0.3,
              right: -screenWidth * 0.3,
              child: _buildBlurCircle(
                size: screenWidth * 1.5,
                color: isDark
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : const Color(0xFF818CF8).withOpacity(0.15),
              ),
            ),
            Positioned(
              bottom: -screenWidth * 0.4,
              left: -screenWidth * 0.4,
              child: _buildBlurCircle(
                size: screenWidth * 1.6,
                color: isDark
                    ? const Color(0xFFA855F7).withOpacity(0.15)
                    : const Color(0xFFC084FC).withOpacity(0.1),
              ),
            ),
          ],
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
          stops: const [0.1, 1.0],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(
    double statusBarHeight,
    bool isDark,
    double screenWidth,
    bool isSmallScreen,
  ) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: statusBarHeight + 8,
            bottom: 16,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (isDark ? Colors.black : const Color(0xFF1E1E2E)).withOpacity(
                  isDark ? 0.4 : 0.05,
                ),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              // Avatar with premium glow
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withOpacity(0.4),
                          Colors.purpleAccent.withOpacity(0.4),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person_rounded,
                            size: 30,
                            color: isDark
                                ? Colors.blueAccent.shade100
                                : Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_subscriptionStatus.isPremium)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.orange.shade700,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF010101)
                                : Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _subscriptionStatus.isPremium
                                ? Colors.amber.withOpacity(0.1)
                                : Colors.blueAccent.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _subscriptionStatus.isPremium
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.blueAccent.withOpacity(0.1),
                            ),
                          ),
                          child: Text(
                            _subscriptionStatus.isPremium
                                ? 'PREMIUM'
                                : 'ÜCRETSİZ',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: _subscriptionStatus.isPremium
                                  ? Colors.amber.shade700
                                  : Colors.blueAccent,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (_kpssType.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Text(
                              _kpssType,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white70 : Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildGlassCard({
    required Widget child,
    required bool isDark,
    double borderRadius = 20,
    EdgeInsets? padding,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color:
              borderColor ??
              (isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05)),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(bool isSmallScreen, double spacing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildGlassCard(
      isDark: isDark,
      borderRadius: 16,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      child: _isLoadingStats
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.auto_graph_rounded,
                    value: _solvedQuestions.toString(),
                    label: 'ÇÖZÜLEN',
                    color: Colors.blueAccent,
                    isSmallScreen: isSmallScreen,
                    isDark: isDark,
                  ),
                ),
                _buildStatDivider(isDark),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.check_circle_rounded,
                    value: _correctAnswers.toString(),
                    label: 'DOĞRU',
                    color: Colors.greenAccent,
                    isSmallScreen: isSmallScreen,
                    isDark: isDark,
                  ),
                ),
                _buildStatDivider(isDark),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.cancel_rounded,
                    value: _wrongAnswers.toString(),
                    label: 'YANLIŞ',
                    color: Colors.redAccent,
                    isSmallScreen: isSmallScreen,
                    isDark: isDark,
                  ),
                ),
                _buildStatDivider(isDark),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.shutter_speed_rounded,
                    value: '${_successRate.toStringAsFixed(0)}%',
                    label: 'BAŞARI',
                    color: Colors.orangeAccent,
                    isSmallScreen: isSmallScreen,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isSmallScreen,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white54 : Colors.black54,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isSmallScreen, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: isDark
              ? Colors.blueAccent.shade100
              : Colors.blueAccent.shade700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required List<Widget> children,
    required bool isDark,
  }) {
    return _buildGlassCard(
      isDark: isDark,
      borderRadius: 16,
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    required bool isSmallScreen,
    required bool isDark,
    required Color color,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      enabled: onTap != null,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white54 : Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 16,
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
    );
  }

  Widget _buildStorageCard(bool isSmallScreen, double spacing, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;

    return _buildSettingsCard(
      isDark: isDark,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storage_rounded,
                      size: 18,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Depolama Durumu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'İndirilen içeriklerin boyutu',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingStorage)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                      onPressed: _refreshStorageInfo,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _currentStorageGB.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        TextSpan(
                          text: ' GB',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '%${(_maxStorageGB > 0 ? (_currentStorageGB / _maxStorageGB * 100) : 0).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _currentStorageGB > _maxStorageGB * 0.9
                          ? Colors.redAccent
                          : Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _maxStorageGB > 0
                      ? (_currentStorageGB / _maxStorageGB).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _currentStorageGB > _maxStorageGB * 0.9
                        ? Colors.redAccent
                        : _currentStorageGB > _maxStorageGB * 0.7
                        ? Colors.orangeAccent
                        : Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildDivider(isDark),
        _buildSwitchTile(
          icon: Icons.auto_delete_rounded,
          title: 'Otomatik Temizleme',
          subtitle: _autoCleanupEnabled
              ? 'Kullanılmayanlar silinir'
              : 'Manuel yönetim aktif',
          value: _autoCleanupEnabled,
          onChanged: (value) async {
            setState(() => _autoCleanupEnabled = value);
            await _cleanupService.setAutoCleanupEnabled(value);
          },
          isDark: isDark,
          color: Colors.redAccent,
        ),
        _buildDivider(isDark),
        _buildSettingTile(
          icon: Icons.data_usage_rounded,
          title: 'Maksimum Depolama',
          subtitle: _maxStorageGB == 0.0
              ? 'Sınırsız Kapasite'
              : '${_maxStorageGB.toStringAsFixed(1)} GB Limit',
          onTap: () => _showMaxStorageDialog(),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          color: Colors.amberAccent,
        ),
        _buildDivider(isDark),
        _buildSettingTile(
          icon: Icons.calendar_today_rounded,
          title: 'Temizleme Aralığı',
          subtitle: '$_cleanupDays gün sonra sil',
          onTap: () => _showCleanupDaysDialog(),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          color: Colors.blueAccent,
        ),
        _buildDivider(isDark),
        _buildSettingTile(
          icon: Icons.cleaning_services_rounded,
          title: 'Şimdi Temizle',
          subtitle: 'Gereksiz dosyaları temizle',
          onTap: () => _runManualCleanup(),
          isSmallScreen: isSmallScreen,
          isDark: isDark,
          color: Colors.greenAccent,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
    required Color color,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white54 : Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
        ),
      ),
    );
  }

  Future<void> _showCleanupDaysDialog() async {
    final selectedDays = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temizleme Süresi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 3, 7, 14, 30].map((days) {
            return RadioListTile<int>(
              title: Text('$days gün'),
              value: days,
              groupValue: _cleanupDays,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedDays != null && selectedDays != _cleanupDays) {
      setState(() => _cleanupDays = selectedDays);
      await _cleanupService.setCleanupDays(selectedDays);
    }
  }

  Future<void> _showMaxStorageDialog() async {
    final storageOptions = [1.0, 3.0, 5.0, 10.0, 20.0, 0.0];
    final selectedStorage = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maksimum Depolama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: storageOptions.map((gb) {
            final label = gb == 0.0
                ? 'Sınırsız'
                : '${gb.toStringAsFixed(0)} GB';
            return RadioListTile<double>(
              title: Text(label),
              value: gb,
              groupValue: _maxStorageGB,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedStorage != null && selectedStorage != _maxStorageGB) {
      setState(() => _maxStorageGB = selectedStorage);
      await _cleanupService.setMaxStorageGB(selectedStorage);
      await _refreshStorageInfo();
    }
  }

  Future<void> _runManualCleanup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manuel Temizleme'),
        content: const Text(
          'Kullanılmayan içerikler temizlenecek. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final deletedCount = await _cleanupService.runCleanup();

      if (mounted) {
        Navigator.pop(context);
        await _refreshStorageInfo();

        PremiumSnackBar.show(
          context,
          message: deletedCount > 0
              ? '$deletedCount dosya temizlendi'
              : 'Temizlenecek dosya bulunamadı',
          type: deletedCount > 0 ? SnackBarType.success : SnackBarType.info,
        );
      }
    }
  }

  Widget _buildLogoutButton(bool isSmallScreen, bool isDark) {
    return _buildGlassCard(
      isDark: isDark,
      borderRadius: 16,
      borderColor: Colors.redAccent.withOpacity(0.2),
      onTap: () => _showLogoutDialog(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.logout_rounded,
            size: 18,
            color: Colors.redAccent,
          ),
        ),
        title: Text(
          'Çıkış Yap',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          'Giriş sayfasına döner',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(bool isSmallScreen, bool isDark) {
    return _buildGlassCard(
      isDark: isDark,
      borderRadius: 16,
      borderColor: Colors.redAccent.withOpacity(0.1),
      onTap: () => _showDeleteAccountDialog(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.no_accounts_rounded,
            size: 18,
            color: Colors.redAccent,
          ),
        ),
        title: const Text(
          'Hesabımı Sil',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.redAccent,
          ),
        ),
        subtitle: Text(
          'Tüm veriler temizlenir',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tema Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text('Açık'),
              value: 'Açık',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                _saveSetting('selected_theme', value);
                Navigator.pop(context);
                // Notify app to update theme
                _updateAppTheme();
              },
            ),
            RadioListTile<String>(
              title: Text('Koyu'),
              value: 'Koyu',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                _saveSetting('selected_theme', value);
                Navigator.pop(context);
                // Notify app to update theme
                _updateAppTheme();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateAppTheme() {
    // Update MyApp theme
    final myAppState = MyApp.of(context);
    final mainScreenState = MainScreen.of(context);
    if (myAppState != null) {
      myAppState.updateTheme(_selectedTheme);
      // Refresh MainScreen to update all pages
      if (mainScreenState != null) {
        mainScreenState.refreshForThemeChange();
      }
    }
  }

  Future<void> _updatePdfUrls() async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF URL\'lerini Güncelle'),
        content: Text(
          'Firebase Storage\'daki PDF dosyaları Firestore\'daki topic\'lerle eşleştirilecek. '
          'Bu işlem biraz zaman alabilir. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Güncelle'),
          ),
        ],
      ),
    );

    if (shouldUpdate != true) return;

    setState(() {
      _isUpdatingPdfUrls = true;
    });

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('PDF URL\'leri güncelleniyor...\nLütfen bekleyin.'),
            ],
          ),
        ),
      );

      await runPdfUpdate();

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'PDF URL\'leri başarıyla güncellendi!',
          type: SnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        PremiumSnackBar.show(
          context,
          message: 'Hata: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPdfUrls = false;
        });
      }
    }
  }

  void _showAboutDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutAppPage()),
    );
  }

  Widget _buildSubscriptionCard(bool isSmallScreen, double spacing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;

    return _buildGlassCard(
      isDark: isDark,
      borderRadius: 24,
      borderColor: _subscriptionStatus.isPremium
          ? Colors.amber.withOpacity(0.3)
          : Colors.blueAccent.withOpacity(0.1),
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SubscriptionPage()),
        );
        if (result == true) {
          _loadSubscriptionStatus(forceRefresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _subscriptionStatus.isPremium
                      ? [Colors.amber.shade300, Colors.orange.shade600]
                      : [Colors.blue.shade400, Colors.indigo.shade700],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        (_subscriptionStatus.isPremium
                                ? Colors.orange
                                : Colors.blue)
                            .withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _subscriptionStatus.isPremium
                    ? Icons.star_rounded
                    : Icons.workspace_premium_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _subscriptionStatus.isPremium
                        ? 'Premium Aktif'
                        : 'Premium\'a Yükselt',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subscriptionStatus.isPremium
                        ? 'Sınırsız erişimin tadını çıkarın'
                        : 'Özel içerikler için yükseltin',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_subscriptionStatus.isPremium &&
                      _subscriptionStatus.endDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Bitiş: ${_formatDate(_subscriptionStatus.endDate!)}',
                      style: TextStyle(
                        fontSize: 9,
                        color: secondaryTextColor.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Çıkış Yap'),
        content: Text('Hesabınızdan çıkmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.logout();
              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );

    if (password == null) return;

    if (password.trim().isEmpty) {
      if (!mounted) return;
      PremiumSnackBar.show(
        context,
        message: 'Lütfen şifrenizi girin.',
        type: SnackBarType.error,
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _authService.deleteAccount(password: password);

    if (!mounted) return;
    Navigator.pop(context); // progress dialog

    if (result.success) {
      PremiumSnackBar.show(
        context,
        message: result.message.isNotEmpty
            ? result.message
            : 'Hesabınız silindi.',
        type: SnackBarType.success,
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } else {
      PremiumSnackBar.show(
        context,
        message: result.message.isNotEmpty ? result.message : 'Hata oluştu.',
        type: SnackBarType.error,
      );
    }
  }

  Future<void> _activatePremiumDev() async {
    final result = await _subscriptionService.setSubscriptionStatus(
      status: 'premium',
      type: 'yearly',
      endDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (result && mounted) {
      await _loadSubscriptionStatus(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Premium başarıyla aktifleştirildi (Dev)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController _passwordController;
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E2E).withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Hesabınızı Silmek İstiyor musunuz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu işlem geri alınamaz. İlerleme verileriniz, çözdüğünüz testler ve tüm kayıtlı içerikleriniz kalıcı olarak temizlenecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Password field
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black26
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withOpacity(0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _isObscured,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Onaylamak için şifrenizi girin',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _isObscured = !_isObscured),
                        icon: Icon(
                          _isObscured ? Icons.visibility : Icons.visibility_off,
                          size: 18,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'İptal',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _passwordController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Hesabımı Sil',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
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
}
