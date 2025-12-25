import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';

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
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _sessionCount = widget.sessionCount;
    _sessionDuration = widget.sessionDuration;
    _shortBreakDuration = widget.shortBreakDuration;
    _longBreakDuration = widget.longBreakDuration;
    _useLongBreak = widget.useLongBreak;
    _isDarkMode = widget.isDarkMode;
  }

  void _saveSettings() {
    widget.onSettingsChanged({
      'sessionCount': _sessionCount,
      'sessionDuration': _sessionDuration,
      'shortBreakDuration': _shortBreakDuration,
      'longBreakDuration': _longBreakDuration,
      'useLongBreak': _useLongBreak,
      'isDarkMode': _isDarkMode,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;
    
    return Theme(
      data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Ayarlar'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveSettings,
              tooltip: 'Kaydet',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Oturum Ayarları - Kompakt Grid
              _buildCompactSection(
                title: 'Oturum',
                icon: Icons.timer,
                children: [
                  _buildCompactSlider(
                    icon: Icons.repeat,
                    label: 'Oturum Sayısı',
                    value: _sessionCount,
                    min: 1,
                    max: 8,
                    unit: '',
                    onChanged: (v) => setState(() => _sessionCount = v),
                  ),
                  _buildCompactSlider(
                    icon: Icons.access_time,
                    label: 'Süre',
                    value: _sessionDuration,
                    min: 5,
                    max: 60,
                    unit: 'dk',
                    onChanged: (v) => setState(() => _sessionDuration = v),
                  ),
                ],
                isDark: isDark,
              ),
              
              const SizedBox(height: 12),
              
              // Mola Ayarları - Kompakt Grid
              _buildCompactSection(
                title: 'Mola',
                icon: Icons.coffee,
                children: [
                  _buildCompactSlider(
                    icon: Icons.pause_circle_outline,
                    label: 'Kısa Mola',
                    value: _shortBreakDuration,
                    min: 1,
                    max: 15,
                    unit: 'dk',
                    onChanged: (v) => setState(() => _shortBreakDuration = v),
                  ),
                  _buildCompactSwitch(
                    icon: Icons.extension,
                    label: 'Uzun Mola',
                    value: _useLongBreak,
                    onChanged: (v) => setState(() => _useLongBreak = v),
                  ),
                  if (_useLongBreak)
                    _buildCompactSlider(
                      icon: Icons.hourglass_empty,
                      label: 'Uzun Mola',
                      value: _longBreakDuration,
                      min: 10,
                      max: 30,
                      unit: 'dk',
                      onChanged: (v) => setState(() => _longBreakDuration = v),
                    ),
                ],
                isDark: isDark,
              ),
              
              const SizedBox(height: 12),
              
              // Görünüm Ayarları
              _buildCompactSection(
                title: 'Görünüm',
                icon: Icons.palette,
                children: [
                  _buildCompactSwitch(
                    icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    label: 'Karanlık Mod',
                    value: _isDarkMode,
                    onChanged: (v) => setState(() => _isDarkMode = v),
                  ),
                ],
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSlider({
    required IconData icon,
    required String label,
    required int value,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$value$unit',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: value.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  onChanged: (v) => onChanged(v.toInt()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSwitch({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
