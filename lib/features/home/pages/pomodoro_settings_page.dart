import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class PomodoroSettingsPage extends StatefulWidget {
  final int sessionCount;
  final int sessionDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final bool useLongBreak;
  final bool isDarkMode;
  final Function(Map<String, dynamic>) onSettingsChanged;

  const PomodoroSettingsPage({
    super.key,
    required this.sessionCount,
    required this.sessionDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.useLongBreak,
    required this.isDarkMode,
    required this.onSettingsChanged,
  });

  @override
  State<PomodoroSettingsPage> createState() => _PomodoroSettingsPageState();
}

class _PomodoroSettingsPageState extends State<PomodoroSettingsPage> {
  late int _sessionCount;
  late int _sessionDuration;
  late int _shortBreakDuration;
  late int _longBreakDuration;
  late bool _useLongBreak;

  @override
  void initState() {
    super.initState();
    _sessionCount = widget.sessionCount;
    _sessionDuration = widget.sessionDuration;
    _shortBreakDuration = widget.shortBreakDuration;
    _longBreakDuration = widget.longBreakDuration;
    _useLongBreak = widget.useLongBreak;
  }

  void _saveSettings() {
    widget.onSettingsChanged({
      'sessionCount': _sessionCount,
      'sessionDuration': _sessionDuration,
      'shortBreakDuration': _shortBreakDuration,
      'longBreakDuration': _longBreakDuration,
      'useLongBreak': _useLongBreak,
      'isDarkMode': widget.isDarkMode, // Keep existing dark mode setting
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarStyle = isDark 
        ? SystemUiOverlayStyle.light 
        : SystemUiOverlayStyle.dark;
    final statusBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle.copyWith(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text(
            'Pomodoro Ayarları',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: isDark 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _saveSettings,
              icon: Icon(
                Icons.check_rounded,
                size: 20,
                color: isDark ? Colors.white : AppColors.primaryBlue,
              ),
              label: Text(
                'Kaydet',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.primaryBlue,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              // Oturum Ayarları - Profesyonel Tasarım
              _buildProfessionalSection(
                title: 'Oturum Ayarları',
                icon: Icons.timer,
                gradientColors: const [], // Not used anymore
                children: [
                  _buildProfessionalSlider(
                    icon: Icons.repeat,
                    label: 'Oturum Sayısı',
                    description: 'Toplam çalışma oturumu sayısı',
                    value: _sessionCount,
                    min: 1,
                    max: 8,
                    unit: 'oturum',
                    onChanged: (v) => setState(() => _sessionCount = v),
                  ),
                  const Divider(height: 24),
                  _buildProfessionalSlider(
                    icon: Icons.access_time,
                    label: 'Oturum Süresi',
                    description: 'Her oturumun süresi',
                    value: _sessionDuration,
                    min: 5,
                    max: 60,
                    unit: 'dakika',
                    onChanged: (v) => setState(() => _sessionDuration = v),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Mola Ayarları - Profesyonel Tasarım
              _buildProfessionalSection(
                title: 'Mola Ayarları',
                icon: Icons.coffee,
                gradientColors: const [], // Not used anymore
                children: [
                  _buildProfessionalSlider(
                    icon: Icons.pause_circle_outline,
                    label: 'Kısa Mola',
                    description: 'Her oturum arası kısa mola süresi',
                    value: _shortBreakDuration,
                    min: 1,
                    max: 15,
                    unit: 'dakika',
                    onChanged: (v) => setState(() => _shortBreakDuration = v),
                  ),
                  const Divider(height: 24),
                  _buildProfessionalSwitch(
                    icon: Icons.extension,
                    label: 'Uzun Mola Kullan',
                    description: 'Belirli oturumlardan sonra uzun mola al',
                    value: _useLongBreak,
                    onChanged: (v) => setState(() => _useLongBreak = v),
                  ),
                  if (_useLongBreak) ...[
                    const Divider(height: 24),
                    _buildProfessionalSlider(
                      icon: Icons.hourglass_empty,
                      label: 'Uzun Mola Süresi',
                      description: 'Uzun mola süresi',
                      value: _longBreakDuration,
                      min: 10,
                      max: 30,
                      unit: 'dakika',
                      onChanged: (v) => setState(() => _longBreakDuration = v),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfessionalSection({
    required String title,
    required IconData icon,
    required List<Color> gradientColors,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon, 
                    color: isDark ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.08),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalSlider({
    required IconData icon,
    required String label,
    required String description,
    required int value,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black87;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon, 
                size: 20, 
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withOpacity(0.2) 
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                '$value $unit',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: primaryColor,
          inactiveColor: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.black.withOpacity(0.1),
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  Widget _buildProfessionalSwitch({
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black87;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon, 
            size: 20, 
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: primaryColor,
        ),
      ],
    );
  }
}
