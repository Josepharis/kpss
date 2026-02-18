import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class PomodoroSettingsPage extends StatefulWidget {
  final int sessionCount;
  final int sessionDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final bool useLongBreak;
  final bool isDarkMode;
  final bool showSessionHistory;
  final String selectedTheme;
  final String selectedOrbDesign;
  final Function(Map<String, dynamic>) onSettingsChanged;

  const PomodoroSettingsPage({
    super.key,
    required this.sessionCount,
    required this.sessionDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.useLongBreak,
    required this.isDarkMode,
    required this.showSessionHistory,
    required this.selectedTheme,
    required this.selectedOrbDesign,
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
  late bool _showSessionHistory;
  late String _selectedTheme;
  late String _selectedOrbDesign;

  @override
  void initState() {
    super.initState();
    _sessionCount = widget.sessionCount;
    _sessionDuration = widget.sessionDuration;
    _shortBreakDuration = widget.shortBreakDuration;
    _longBreakDuration = widget.longBreakDuration;
    _useLongBreak = widget.useLongBreak;
    _showSessionHistory = widget.showSessionHistory;
    _selectedTheme = widget.selectedTheme;
    _selectedOrbDesign = widget.selectedOrbDesign;
  }

  void _saveSettings() {
    widget.onSettingsChanged({
      'sessionCount': _sessionCount,
      'sessionDuration': _sessionDuration,
      'shortBreakDuration': _shortBreakDuration,
      'longBreakDuration': _longBreakDuration,
      'useLongBreak': _useLongBreak,
      'isDarkMode': widget.isDarkMode,
      'showSessionHistory': _showSessionHistory,
      'selectedTheme': _selectedTheme,
      'selectedOrbDesign': _selectedOrbDesign,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = _getThemeColor(_selectedTheme);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF020617)
          : const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
        title: Text(
          'AYARLAR',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: Icon(Icons.check_rounded, color: themeColor, size: 24),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildCompactSection(
                  title: 'TEMA SEÇİMİ',
                  icon: Icons.palette_outlined,
                  isDark: isDark,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildThemeOption(
                          'indigo',
                          const Color(0xFF6366F1),
                          isDark,
                        ),
                        _buildThemeOption(
                          'emerald',
                          const Color(0xFF10B981),
                          isDark,
                        ),
                        _buildThemeOption(
                          'rose',
                          const Color(0xFFF43F5E),
                          isDark,
                        ),
                        _buildThemeOption(
                          'amber',
                          const Color(0xFFF59E0B),
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'SAYAÇ TASARIMI',
                  icon: Icons.auto_awesome_mosaic_outlined,
                  isDark: isDark,
                  children: [
                    Row(
                      children: [
                        _buildDesignOption(
                          'liquid',
                          'Sıvı',
                          Icons.waves_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildDesignOption(
                          'rings',
                          'Halka',
                          Icons.blur_circular_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildDesignOption(
                          'modern',
                          'Modern',
                          Icons.adjust_rounded,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildDesignOption(
                          'none',
                          'Sade',
                          Icons.circle_outlined,
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'ZAMANLAYICI',
                  icon: Icons.timer_outlined,
                  isDark: isDark,
                  children: [
                    _buildCompactSlider(
                      'Oturum Sayısı',
                      _sessionCount,
                      'Adet',
                      1,
                      10,
                      isDark,
                      (v) => setState(() => _sessionCount = v),
                    ),
                    const SizedBox(height: 16),
                    _buildCompactSlider(
                      'Oturum Süresi',
                      _sessionDuration,
                      'Dk',
                      5,
                      90,
                      isDark,
                      (v) => setState(() => _sessionDuration = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'MOLA',
                  icon: Icons.coffee_outlined,
                  isDark: isDark,
                  children: [
                    _buildCompactSlider(
                      'Kısa Mola',
                      _shortBreakDuration,
                      'Dk',
                      1,
                      20,
                      isDark,
                      (v) => setState(() => _shortBreakDuration = v),
                    ),
                    const SizedBox(height: 12),
                    _buildCompactSwitch(
                      'Uzun Mola Aktif',
                      _useLongBreak,
                      isDark,
                      (v) => setState(() => _useLongBreak = v),
                    ),
                    if (_useLongBreak) ...[
                      const SizedBox(height: 12),
                      _buildCompactSlider(
                        'Uzun Mola Sür.',
                        _longBreakDuration,
                        'Dk',
                        10,
                        60,
                        isDark,
                        (v) => setState(() => _longBreakDuration = v),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _buildCompactSection(
                  title: 'GÖRÜNÜM',
                  icon: Icons.auto_awesome_outlined,
                  isDark: isDark,
                  children: [
                    _buildCompactSwitch(
                      'Oturum Kayıtları',
                      _showSessionHistory,
                      isDark,
                      (v) => setState(() => _showSessionHistory = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String theme, Color color, bool isDark) {
    bool isSelected = _selectedTheme == theme;
    return GestureDetector(
      onTap: () => setState(() => _selectedTheme = theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }

  Widget _buildDesignOption(
    String design,
    String label,
    IconData icon,
    bool isDark,
  ) {
    bool isSelected = _selectedOrbDesign == design;
    final themeColor = _getThemeColor(_selectedTheme);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOrbDesign = design),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? themeColor
                : (isDark ? Colors.white : Colors.black).withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? themeColor : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white54 : Colors.black54),
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getThemeColor(String theme) {
    switch (theme) {
      case 'emerald':
        return const Color(0xFF10B981);
      case 'rose':
        return const Color(0xFFF43F5E);
      case 'amber':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: _getThemeColor(_selectedTheme)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCompactSlider(
    String label,
    int value,
    String unit,
    double min,
    double max,
    bool isDark,
    ValueChanged<int> onChanged,
  ) {
    final themeColor = _getThemeColor(_selectedTheme);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$value $unit',
              style: TextStyle(
                color: themeColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 1.5,
            activeTrackColor: themeColor,
            inactiveTrackColor: (isDark ? Colors.white : Colors.black)
                .withOpacity(0.05),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSwitch(
    String label,
    bool value,
    bool isDark,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(
          height: 24,
          child: Switch.adaptive(
            value: value,
            activeColor: _getThemeColor(_selectedTheme),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
