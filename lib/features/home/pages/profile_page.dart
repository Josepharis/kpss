import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/run_pdf_update.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _selectedLanguage = 'Türkçe';
  String _selectedTheme = 'Otomatik';
  bool _isUpdatingPdfUrls = false;

  @override
  void initState() {
    super.initState();
    // Load settings after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _selectedLanguage = prefs.getString('selected_language') ?? 'Türkçe';
        _selectedTheme = prefs.getString('selected_theme') ?? 'Otomatik';
      });
    } catch (e) {
      // If there's an error loading settings, use default values
      // Don't call setState if widget is not mounted
      if (mounted) {
        setState(() {
          // Keep default values already set in field declarations
        });
      }
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
      // Silently fail if saving settings fails
      // This prevents crashes if storage is unavailable
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.primaryBlue,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Column(
          children: [
            // Compact Header
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
                    AppColors.primaryBlue,
                    AppColors.primaryDarkBlue,
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
                          'Kullanıcı',
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
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Colors.white, size: iconSize),
                    onPressed: () {
                      // Edit profile action
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
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
                    // İstatistikler - Kompakt
                    _buildStatsCard(isSmallScreen, compactSpacing),
                    SizedBox(height: compactSpacing),
                    
                    // Genel Ayarlar
                    _buildSectionTitle('Genel', isSmallScreen),
                    SizedBox(height: compactSpacing / 2),
                    _buildSettingsCard(
                      children: [
                        _buildSettingTile(
                          icon: Icons.language,
                          title: 'Dil',
                          subtitle: _selectedLanguage,
                          onTap: () => _showLanguageDialog(),
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
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
                    
                    // Bildirimler
                    _buildSectionTitle('Bildirimler', isSmallScreen),
                    SizedBox(height: compactSpacing / 2),
                    _buildSettingsCard(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.notifications_outlined,
                          title: 'Bildirimler',
                          subtitle: 'Yeni içerik ve hatırlatmalar',
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            _saveSetting('notifications_enabled', value);
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.volume_up_outlined,
                          title: 'Ses',
                          subtitle: 'Bildirim sesleri',
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() => _soundEnabled = value);
                            _saveSetting('sound_enabled', value);
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.vibration,
                          title: 'Titreşim',
                          subtitle: 'Bildirim titreşimleri',
                          value: _vibrationEnabled,
                          onChanged: (value) {
                            setState(() => _vibrationEnabled = value);
                            _saveSetting('vibration_enabled', value);
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                      ],
                    ),
                    SizedBox(height: compactSpacing),
                    
                    // Çalışma Ayarları
                    _buildSectionTitle('Çalışma', isSmallScreen),
                    SizedBox(height: compactSpacing / 2),
                    _buildSettingsCard(
                      children: [
                        _buildSettingTile(
                          icon: Icons.timer_outlined,
                          title: 'Pomodoro Ayarları',
                          subtitle: 'Çalışma zamanlayıcısı',
                          onTap: () {
                            // Navigate to pomodoro settings
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.backup_outlined,
                          title: 'Yedekleme',
                          subtitle: 'Verilerinizi yedekleyin',
                          onTap: () {
                            // Backup action
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.restore_outlined,
                          title: 'Geri Yükle',
                          subtitle: 'Yedekten geri yükleyin',
                          onTap: () {
                            // Restore action
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
                          icon: Icons.privacy_tip_outlined,
                          title: 'Gizlilik Politikası',
                          subtitle: 'Kullanım koşulları',
                          onTap: () {
                            // Privacy policy
                          },
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        _buildDivider(),
                        _buildSettingTile(
                          icon: Icons.help_outline,
                          title: 'Yardım & Destek',
                          subtitle: 'SSS ve destek',
                          onTap: () {
                            // Help & support
                          },
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

  Widget _buildStatsCard(bool isSmallScreen, double spacing) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.check_circle_outline,
              value: '1,234',
              label: 'Çözülen Soru',
              isSmallScreen: isSmallScreen,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.progressGray,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.access_time,
              value: '45s',
              label: 'Çalışma Süresi',
              isSmallScreen: isSmallScreen,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.progressGray,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.trending_up,
              value: '78%',
              label: 'Başarı Oranı',
              isSmallScreen: isSmallScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required bool isSmallScreen,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 18 : 20,
          color: AppColors.primaryBlue,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 9 : 10,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 13 : 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
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
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: fontSize - 2,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.textLight,
      ),
      onTap: onTap,
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
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: fontSize - 2,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: AppColors.progressGray,
    );
  }

  Widget _buildLogoutButton(bool isSmallScreen, double fontSize) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
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

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dil Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text('Türkçe'),
              value: 'Türkçe',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() => _selectedLanguage = value!);
                _saveSetting('selected_language', value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('English'),
              value: 'English',
              groupValue: _selectedLanguage,
              onChanged: (value) {
                setState(() => _selectedLanguage = value!);
                _saveSetting('selected_language', value);
                Navigator.pop(context);
              },
            ),
          ],
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
              title: Text('Otomatik'),
              value: 'Otomatik',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                _saveSetting('selected_theme', value);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: Text('Açık'),
              value: 'Açık',
              groupValue: _selectedTheme,
              onChanged: (value) {
                setState(() => _selectedTheme = value!);
                _saveSetting('selected_theme', value);
                Navigator.pop(context);
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePdfUrls() async {
    // Show confirmation dialog
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
      // Show loading dialog
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

      // Run the update script
      await runPdfUpdate();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
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
      // Close loading dialog if still open
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
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
            onPressed: () {
              Navigator.pop(context);
              // Logout logic here
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
