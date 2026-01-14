import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/run_pdf_update.dart';
import '../../../core/services/storage_cleanup_service.dart';
import '../../../core/services/progress_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../../main.dart';
import 'subscription_page.dart';

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
  
  // User statistics
  String _userName = 'Kullanıcı';
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
      if (mounted) {
        setState(() {
          _userName = userName ?? 'Kullanıcı';
        });
      }
    } catch (e) {
      // Silent error handling
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

  Future<void> _loadSubscriptionStatus() async {
    try {
      final status = await _subscriptionService.getSubscriptionStatus();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenHeight < 700;
    
    final compactPadding = isSmallScreen ? 12.0 : 16.0;
    final compactSpacing = isSmallScreen ? 8.0 : 12.0;
    final iconSize = isSmallScreen ? 18.0 : 20.0;
    final fontSize = isSmallScreen ? 13.0 : 14.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? const Color(0xFF1E1E1E) : AppColors.primaryBlue;
    final headerDarkColor = isDark ? const Color(0xFF121212) : AppColors.primaryDarkBlue;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF121212) : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: Column(
          children: [
            // Header with user name
            Container(
              padding: EdgeInsets.only(
                top: statusBarHeight + (isSmallScreen ? 8 : 12),
                bottom: isSmallScreen ? 12 : 16,
                left: isTablet ? 24 : compactPadding,
                right: isTablet ? 24 : compactPadding,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    headerColor,
                    headerDarkColor,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 48 : 56,
                    height: isSmallScreen ? 48 : 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: isSmallScreen ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'KPSS & AGS 2026',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compactPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Statistics Card
                    _buildStatisticsCard(isSmallScreen, compactSpacing),
                    SizedBox(height: compactSpacing),
                    
                    // Abonelik Durumu
                    _buildSubscriptionCard(isSmallScreen, compactSpacing, iconSize, fontSize),
                    SizedBox(height: compactSpacing),
                    
                    // Tema Ayarları
                    _buildSectionTitle('Ayarlar', isSmallScreen),
                    SizedBox(height: compactSpacing / 2),
                    _buildSettingsCard(
                      children: [
                        _buildSettingTile(
                          icon: Icons.palette_outlined,
                          title: 'Tema',
                          subtitle: _selectedTheme,
                          onTap: () => _showThemeDialog(),
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                      ],
                    ),
                    SizedBox(height: compactSpacing),
                    
                    // Depolama Yönetimi
                    _buildSectionTitle('Depolama Yönetimi', isSmallScreen),
                    SizedBox(height: compactSpacing / 2),
                    _buildStorageCard(isSmallScreen, compactSpacing, iconSize, fontSize),
                    SizedBox(height: compactSpacing),
                    
                    // Hakkında
                    _buildSectionTitle('Hakkında', isSmallScreen),
                    SizedBox(height: compactSpacing / 2),
                    _buildSettingsCard(
                      children: [
                        _buildSettingTile(
                          icon: Icons.info_outline,
                          title: 'Uygulama Hakkında',
                          subtitle: 'Versiyon 1.0.0',
                          onTap: () {
                            _showAboutDialog();
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'PDF URL\'lerini Güncelle',
                          subtitle: _isUpdatingPdfUrls 
                              ? 'Güncelleniyor...' 
                              : 'Storage\'daki PDF\'leri eşleştir',
                          onTap: _isUpdatingPdfUrls 
                              ? null 
                              : () => _updatePdfUrls(),
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                      ],
                    ),
                    SizedBox(height: compactSpacing),
                    
                    // Çıkış
                    _buildLogoutButton(isSmallScreen, fontSize),
                    SizedBox(height: compactSpacing),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(bool isSmallScreen, double spacing) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : AppColors.cardBackground;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : AppColors.cardShadow;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingStats
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
              ),
            )
          : Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final dividerColor = isDark ? Colors.white.withOpacity(0.1) : AppColors.progressGray;
                
                return Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.quiz_outlined,
                        value: _solvedQuestions.toString(),
                        label: 'Çözülen',
                        color: AppColors.primaryBlue,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.check_circle_outline,
                        value: _correctAnswers.toString(),
                        label: 'Doğru',
                        color: Colors.green,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.cancel_outlined,
                        value: _wrongAnswers.toString(),
                        label: 'Yanlış',
                        color: Colors.red,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: dividerColor,
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.trending_up_outlined,
                        value: '${_successRate.toStringAsFixed(0)}%',
                        label: 'Oran',
                        color: AppColors.gradientPurpleStart,
                        isSmallScreen: isSmallScreen,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isSmallScreen,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 16 : 18,
          color: color,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 9 : 10,
            color: secondaryTextColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isSmallScreen) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 13 : 14,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : AppColors.cardBackground;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : AppColors.cardShadow;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    required double iconSize,
    required double fontSize,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final lightTextColor = isDark ? Colors.white60 : AppColors.textLight;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      enabled: onTap != null,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.primaryBlue,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: fontSize - 2,
          color: secondaryTextColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: lightTextColor,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white.withOpacity(0.1) : AppColors.progressGray;
    
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: dividerColor,
    );
  }
  
  Widget _buildStorageCard(bool isSmallScreen, double spacing, double iconSize, double fontSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final progressBgColor = isDark ? Colors.white.withOpacity(0.1) : AppColors.progressGray;
    final iconColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return _buildSettingsCard(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storage,
                    size: iconSize,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Depolama Kullanımı',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Spacer(),
                  if (_isLoadingStorage)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.refresh, size: 18, color: iconColor),
                      onPressed: _refreshStorageInfo,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                ],
              ),
              SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_currentStorageGB.toStringAsFixed(2)} GB',
                        style: TextStyle(
                          fontSize: fontSize - 1,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '/ ${_maxStorageGB.toStringAsFixed(1)} GB',
                        style: TextStyle(
                          fontSize: fontSize - 1,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _maxStorageGB > 0 ? (_currentStorageGB / _maxStorageGB).clamp(0.0, 1.0) : 0.0,
                      minHeight: 8,
                      backgroundColor: progressBgColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentStorageGB > _maxStorageGB * 0.9
                            ? Colors.red
                            : _currentStorageGB > _maxStorageGB * 0.7
                                ? Colors.orange
                                : AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDivider(),
        _buildSwitchTile(
          icon: Icons.auto_delete_outlined,
          title: 'Otomatik Temizleme',
          subtitle: _autoCleanupEnabled 
              ? 'Kullanılmayan içerikler otomatik silinir'
              : 'Otomatik temizleme kapalı',
          value: _autoCleanupEnabled,
          onChanged: (value) async {
            setState(() => _autoCleanupEnabled = value);
            await _cleanupService.setAutoCleanupEnabled(value);
          },
          iconSize: iconSize,
          fontSize: fontSize,
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.calendar_today_outlined,
          title: 'Temizleme Süresi',
          subtitle: '$_cleanupDays gün (kullanılmayan içerikler silinir)',
          onTap: () => _showCleanupDaysDialog(),
          iconSize: iconSize,
          fontSize: fontSize,
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.data_usage_outlined,
          title: 'Maksimum Depolama',
          subtitle: _maxStorageGB == 0.0
              ? 'Sınırsız'
              : '${_maxStorageGB.toStringAsFixed(1)} GB (limit aşıldığında en az kullanılan silinir)',
          onTap: () => _showMaxStorageDialog(),
          iconSize: iconSize,
          fontSize: fontSize,
        ),
        _buildDivider(),
        _buildSettingTile(
          icon: Icons.cleaning_services_outlined,
          title: 'Manuel Temizleme',
          subtitle: 'Şimdi temizle',
          onTap: () => _runManualCleanup(),
          iconSize: iconSize,
          fontSize: fontSize,
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
    required double iconSize,
    required double fontSize,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.primaryBlue,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: fontSize - 2,
          color: secondaryTextColor,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
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
            final label = gb == 0.0 ? 'Sınırsız' : '${gb.toStringAsFixed(0)} GB';
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
        content: const Text('Kullanılmayan içerikler temizlenecek. Devam etmek istiyor musunuz?'),
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
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final deletedCount = await _cleanupService.runCleanup();
      
      if (mounted) {
        Navigator.pop(context);
        await _refreshStorageInfo();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletedCount > 0
                  ? '$deletedCount dosya temizlendi'
                  : 'Temizlenecek dosya bulunamadı',
            ),
            backgroundColor: deletedCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildLogoutButton(bool isSmallScreen, double fontSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : AppColors.cardBackground;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : AppColors.cardShadow;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.logout,
            size: isSmallScreen ? 18 : 20,
            color: Colors.red,
          ),
        ),
        title: Text(
          'Çıkış Yap',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        onTap: () {
          _showLogoutDialog();
        },
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF URL\'leri başarıyla güncellendi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('KPSS & AGS 2026'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versiyon: 1.0.0'),
            SizedBox(height: 8),
            Text(
              'KPSS ve AGS sınavlarına hazırlık için kapsamlı bir çalışma uygulaması.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(bool isSmallScreen, double spacing, double iconSize, double fontSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : AppColors.cardBackground;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : AppColors.cardShadow;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: _subscriptionStatus.isPremium
            ? Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.5),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _subscriptionStatus.isPremium
                ? AppColors.primaryBlue.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _subscriptionStatus.isPremium ? Icons.star_rounded : Icons.star_outline,
            size: iconSize,
            color: _subscriptionStatus.isPremium ? AppColors.primaryBlue : Colors.grey,
          ),
        ),
        title: Text(
          _subscriptionStatus.isPremium ? 'Premium Aktif' : 'Premium\'a Geç',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              _subscriptionStatus.isPremium
                  ? _subscriptionStatus.displayText
                  : 'Tüm konulara erişim için Premium\'a geçin',
              style: TextStyle(
                fontSize: fontSize - 2,
                color: secondaryTextColor,
              ),
            ),
            if (_subscriptionStatus.isPremium && _subscriptionStatus.endDate != null) ...[
              SizedBox(height: 4),
              Text(
                'Bitiş: ${_formatDate(_subscriptionStatus.endDate!)}',
                style: TextStyle(
                  fontSize: fontSize - 3,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: secondaryTextColor,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubscriptionPage()),
          ).then((_) {
            // Sayfa döndüğünde abonelik durumunu yenile
            _loadSubscriptionStatus();
          });
        },
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
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text(
              'Çıkış Yap',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
