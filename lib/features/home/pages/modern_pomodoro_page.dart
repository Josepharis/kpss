import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/pomodoro_session.dart';
import '../../../core/services/pomodoro_storage_service.dart';
import 'my_program_page.dart';
import 'pomodoro_save_session_page.dart';
import 'pomodoro_settings_page.dart';
import 'pomodoro_stats_page.dart';

class ModernPomodoroPage extends StatefulWidget {
  final bool standalonePomodoro;
  const ModernPomodoroPage({super.key, this.standalonePomodoro = false});

  @override
  State<ModernPomodoroPage> createState() => _ModernPomodoroPageState();
}

class _ModernPomodoroPageState extends State<ModernPomodoroPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late AnimationController _liquidController;
  late AnimationController _atmosphereController;

  final PomodoroStorageService _storageService = PomodoroStorageService();
  final List<PomodoroSession> _history = [];

  int _sessionCount = 4;
  int _sessionDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  bool _useLongBreak = true;
  bool _isDarkMode = true;
  bool _showSessionHistory = true;
  String _selectedTheme = 'indigo';
  String _selectedOrbDesign = 'modern';

  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreakTime = false;
  int _completedSessions = 0;
  late Duration _remainingTime;
  Timer? _timer;

  bool _isHistoryExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.standalonePomodoro ? 1 : 0);
    _tabController.addListener(() => setState(() {}));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _atmosphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _remainingTime = Duration(minutes: _sessionDuration);
    _loadSettings();
    _loadHistory();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sessionCount = prefs.getInt('pomodoro_session_count') ?? 4;
      _sessionDuration = prefs.getInt('pomodoro_session_duration') ?? 25;
      _shortBreakDuration = prefs.getInt('pomodoro_short_break') ?? 5;
      _longBreakDuration = prefs.getInt('pomodoro_long_break') ?? 15;
      _useLongBreak = prefs.getBool('pomodoro_use_long_break') ?? true;
      _isDarkMode = prefs.getBool('pomodoro_dark_mode') ?? true;
      _showSessionHistory = prefs.getBool('pomodoro_show_history') ?? true;
      _selectedTheme = prefs.getString('pomodoro_theme') ?? 'indigo';
      _selectedOrbDesign = prefs.getString('pomodoro_orb_design') ?? 'modern';
      _remainingTime = Duration(minutes: _sessionDuration);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoro_session_count', _sessionCount);
    await prefs.setInt('pomodoro_session_duration', _sessionDuration);
    await prefs.setInt('pomodoro_short_break', _shortBreakDuration);
    await prefs.setInt('pomodoro_long_break', _longBreakDuration);
    await prefs.setBool('pomodoro_use_long_break', _useLongBreak);
    await prefs.setBool('pomodoro_dark_mode', _isDarkMode);
    await prefs.setBool('pomodoro_show_history', _showSessionHistory);
    await prefs.setString('pomodoro_theme', _selectedTheme);
    await prefs.setString('pomodoro_orb_design', _selectedOrbDesign);
  }

  Future<void> _loadHistory() async {
    final sessions = await _storageService.getAllSessions();
    setState(() {
      _history.clear();
      _history.addAll(sessions.take(10));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _liquidController.dispose();
    _atmosphereController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() => _remainingTime -= const Duration(seconds: 1));
      } else {
        _timer?.cancel();
        _handleSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingTime = Duration(minutes: _sessionDuration);
    });
  }

  void _handleSessionComplete() {
    HapticFeedback.heavyImpact();
    if (!_isBreakTime) {
      _completedSessions++;
      if (_completedSessions < _sessionCount) {
        _startBreak(false);
      } else {
        _startBreak(true);
      }
      _showSaveDialog();
    } else {
      _isBreakTime = false;
      _remainingTime = Duration(minutes: _sessionDuration);
      _isRunning = false;
    }
  }

  void _showSaveDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroSaveSessionPage(
        sessionCount: 1,
        totalMinutes: _sessionDuration,
        totalSeconds: _sessionDuration * 60,
        sessionDuration: _sessionDuration,
        onSaved: () {
          _loadHistory();
        },
      ),
      ),
    );
  }

  void _startBreak(bool isLongBreak) {
    setState(() {
      _isBreakTime = true;
      _remainingTime = Duration(
        minutes: isLongBreak ? _longBreakDuration : _shortBreakDuration,
      );
      _startTimer();
    });
  }

  void _skipBreak() {
    _timer?.cancel();
    setState(() {
      _isBreakTime = false;
      _remainingTime = Duration(minutes: _sessionDuration);
      _isRunning = false;
      _isPaused = false;
    });
  }

  void _showStopConfirmation() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Oturumu Durdur', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Çalışmanı durdurmak üzeresin. İlerlemen kaydedilmeyecek, emin misin?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Devam Et')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetTimer();
              },
              child: const Text('Durdur', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroSettingsPage(
          sessionCount: _sessionCount,
          sessionDuration: _sessionDuration,
          shortBreakDuration: _shortBreakDuration,
          longBreakDuration: _longBreakDuration,
          useLongBreak: _useLongBreak,
          isDarkMode: _isDarkMode,
          showSessionHistory: _showSessionHistory,
          selectedTheme: _selectedTheme,
          selectedOrbDesign: _selectedOrbDesign,
          onSettingsChanged: (settings) {
            setState(() {
              _sessionCount = settings['sessionCount'] as int? ?? 4;
              _sessionDuration = settings['sessionDuration'] as int? ?? 25;
              _shortBreakDuration = settings['shortBreakDuration'] as int? ?? 5;
              _longBreakDuration = settings['longBreakDuration'] as int? ?? 15;
              _useLongBreak = settings['useLongBreak'] as bool? ?? true;
              _isDarkMode = settings['isDarkMode'] as bool? ?? true;
              _showSessionHistory = settings['showSessionHistory'] as bool? ?? true;
              _selectedTheme = settings['selectedTheme'] as String? ?? 'indigo';
              _selectedOrbDesign = settings['selectedOrbDesign'] as String? ?? 'modern';

              if (!_isRunning) {
                _remainingTime = Duration(minutes: _sessionDuration);
              }
            });
            _saveSettings();
          },
        ),
      ),
    );
  }

  Color _getThemeColor() {
    if (_isBreakTime) return const Color(0xFF00FFA3);
    switch (_selectedTheme) {
      case 'emerald': return const Color(0xFF10B981);
      case 'rose': return const Color(0xFFF43F5E);
      case 'amber': return const Color(0xFFF59E0B);
      case 'violet': return const Color(0xFF8B5CF6);
      case 'cyan': return const Color(0xFF06B6D4);
      case 'crimson': return const Color(0xFFBE123C);
      case 'gold': return const Color(0xFFD97706);
      case 'obsidian': return const Color(0xFF1E293B);
      default: return const Color(0xFF6366F1);
    }
  }

  Color _getBgColor(bool isDark) {
    // Pure, solid theme color for the background
    return _getThemeColor();
  }

  double _getProgress() {
    final total = _isBreakTime
        ? (_remainingTime.inSeconds > 0 ? _remainingTime.inSeconds : 1)
        : (_sessionDuration * 60).toDouble();
    return _remainingTime.inSeconds / (total > 0 ? total : 1);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _getBgColor(isDark),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: widget.standalonePomodoro,
          leading: widget.standalonePomodoro ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ) : null,
          centerTitle: true,
          toolbarHeight: widget.standalonePomodoro ? 70 : 56,
          title: Text(
            widget.standalonePomodoro ? 'ODAKLAN' : 'ÇALIŞMALARIM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: [
                const Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          bottom: widget.standalonePomodoro ? null : PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [Tab(text: 'PROGRAMIM'), Tab(text: 'POMODORO')],
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: isDark ? Colors.white24 : Colors.white,
                  ),
                  labelColor: isDark ? Colors.white : _getThemeColor(),
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        body: widget.standalonePomodoro 
            ? _buildTimerTab(size, isLandscape, isDark)
            : TabBarView(
          controller: _tabController,
          children: [
            _buildProgramTab(isDark),
            _buildTimerTab(size, isLandscape, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramTab(bool isDark) {
    return Container(
      color: _getBgColor(isDark),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
        ),
        child: const MyProgramPage(isTransparent: true),
      ),
    );
  }

  Widget _buildTimerTab(Size size, bool isLandscape, bool isDark) {
    return Stack(
      children: [
        _buildBackground(isDark),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildOrb(size, isLandscape, isDark),
                const SizedBox(height: 48),
                _buildDock(isDark),
                const SizedBox(height: 32),
                _buildActionButtons(isDark),
                if (_showSessionHistory) ...[
                  const SizedBox(height: 40),
                  _buildCollapsibleHistory(isDark),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _atmosphereController,
      builder: (context, child) => CustomPaint(
        size: Size.infinite,
        painter: AuroraAtmospherePainter(
          animationValue: _atmosphereController.value,
          isBreak: _isBreakTime,
          isDark: isDark,
          themeColor: _getThemeColor(),
        ),
      ),
    );
  }

  Widget _buildOrb(Size size, bool isLandscape, bool isDark) {
    final orbSize = isLandscape ? size.height * 0.75 : size.width * 0.88;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _liquidController]),
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(orbSize, orbSize),
            painter: CinematicOrbPainter(
              progress: _getProgress(),
              pulse: _pulseController.value,
              liquidValue: _liquidController.value,
              color: _getThemeColor(),
              isRunning: _isRunning && !_isPaused,
              isDark: isDark,
              design: _selectedOrbDesign,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(_remainingTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 82,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isBreakTime ? 'MOLA' : 'ODAKLAN',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDock(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 64),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRunning || _isPaused) ...[
                _DockButton(
                  icon: Icons.stop_rounded,
                  onTap: _showStopConfirmation,
                  color: Colors.transparent,
                  iconColor: (isDark ? Colors.white : Colors.black).withOpacity(0.34),
                ),
                const SizedBox(width: 4),
              ],
              _DockButton(
                icon: _isRunning && !_isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onTap: _isRunning && !_isPaused ? _pauseTimer : _startTimer,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                iconColor: isDark ? Colors.white : Colors.black87,
                isPrimary: true,
                isDark: isDark,
              ),
              if (_isBreakTime) ...[
                const SizedBox(width: 4),
                _DockButton(
                  icon: Icons.skip_next_rounded,
                  onTap: _skipBreak,
                  color: Colors.transparent,
                  iconColor: (isDark ? Colors.white : Colors.black).withOpacity(0.34),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IconButtonWithLabel(
            icon: Icons.bar_chart_rounded,
            label: 'İSTATİSTİK',
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PomodoroStatsPage())),
          ),
          const SizedBox(width: 48),
          _IconButtonWithLabel(
            icon: Icons.settings_rounded,
            label: 'AYARLAR',
            isDark: isDark,
            onTap: _showSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleHistory(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isHistoryExpanded = !_isHistoryExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 16, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                      const SizedBox(width: 8),
                      Text('OTURUM KAYITLARI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                    ],
                  ),
                  Icon(_isHistoryExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3)),
                ],
              ),
            ),
          ),
          if (_isHistoryExpanded)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final session = _history[index];
                return ListTile(
                  title: Text(session.topic ?? 'Çalışma', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('${session.totalMinutes} dk • ${session.sessionCount} oturum', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
                  trailing: Text("${session.date.day}/${session.date.month}", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), fontSize: 10)),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;
  final bool isPrimary;
  final bool isDark;

  const _DockButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.iconColor,
    this.isPrimary = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: isPrimary ? 64 : 48,
        height: isPrimary ? 64 : 48,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: isPrimary ? 32 : 24),
      ),
    );
  }
}

class _IconButtonWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _IconButtonWithLabel({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), letterSpacing: 1)),
      ],
    );
  }
}

class AuroraAtmospherePainter extends CustomPainter {
  final double animationValue;
  final bool isBreak, isDark;
  final Color themeColor;

  AuroraAtmospherePainter({
    required this.animationValue,
    required this.isBreak,
    required this.isDark,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background is now a pure solid immersive color as requested.
    // No more blobs or variations.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CinematicOrbPainter extends CustomPainter {
  final double progress, pulse, liquidValue;
  final Color color;
  final bool isRunning, isDark;
  final String design;

  CinematicOrbPainter({
    required this.progress,
    required this.pulse,
    required this.liquidValue,
    required this.color,
    required this.isRunning,
    required this.isDark,
    required this.design,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Draw dark semi-transparent orb base so everything is always visible ──
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    if (design == 'liquid') {
      _paintLiquid(canvas, center, radius, size);
    } else if (design == 'modern') {
      _paintModern(canvas, center, radius);
    } else {
      _paintAura(canvas, center, radius);
    }

    // ── Always draw the outer glass border ring on top ──
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withOpacity(0.3),
    );
  }

  // ──────────────────────────────────────────────────
  //  LIQUID DESIGN
  // ──────────────────────────────────────────────────
  void _paintLiquid(Canvas canvas, Offset center, double radius, Size size) {
    // Clip to circle
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius - 2));
    canvas.save();
    canvas.clipPath(clipPath);

    // Water level logic: progress 1.0 (full) -> 0.0 (empty)
    // Moving from top (ymin) to bottom (ymax)
    final waterLevel = center.dy - radius + (2 * radius * (1.0 - progress));

    // High-speed sloshing physics
    final phase = liquidValue * 2 * math.pi;
    final waveAmplitude = isRunning ? 18.0 : 4.0;
    
    // 1. Back Wave (Secondary Tone)
    final backPath = Path();
    backPath.moveTo(center.dx - radius - 20, size.height);
    for (double x = center.dx - radius - 20; x <= center.dx + radius + 20; x += 4) {
      final y = waterLevel + 12 + math.sin((x * 0.025) + phase + math.pi) * (waveAmplitude * 0.8);
      backPath.lineTo(x, y);
    }
    backPath.lineTo(center.dx + radius + 20, size.height);
    backPath.close();
    canvas.drawPath(backPath, Paint()..color = color.withOpacity(0.5));

    // 2. Front Wave (Primary Tone)
    final frontPath = Path();
    frontPath.moveTo(center.dx - radius - 20, size.height);
    for (double x = center.dx - radius - 20; x <= center.dx + radius + 20; x += 4) {
      final y = waterLevel + math.sin((x * 0.035) + phase) * waveAmplitude;
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(center.dx + radius + 20, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, Paint()..color = color.withOpacity(0.9));

    // 3. Subtle Wave Rim (Instead of harsh white flare)
    canvas.drawPath(frontPath, Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    canvas.restore();

    // Soft Refraction - very subtle
    canvas.drawOval(
      Rect.fromLTWH(center.dx - radius * 0.6, center.dy - radius * 0.85, radius * 0.4, radius * 0.15),
      Paint()..color = Colors.white.withOpacity(0.12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  // ──────────────────────────────────────────────────
  //  MODERN HUD DESIGN
  // ──────────────────────────────────────────────────
  void _paintModern(Canvas canvas, Offset center, double radius) {
    const segments = 40;
    const segmentAngle = (2 * math.pi) / segments;
    const outerR = 0.85;
    const innerR = 0.76;

    // Technical ticks
    for (int i = 0; i < segments; i++) {
      final angle = -math.pi / 2 + (i * segmentAngle);
      final isActive = (i / segments) < (1.0 - progress); // Inverted for "filling" look or direct ratio
      
      final p1 = Offset(center.dx + math.cos(angle) * radius * innerR, center.dy + math.sin(angle) * radius * innerR);
      final p2 = Offset(center.dx + math.cos(angle) * radius * outerR, center.dy + math.sin(angle) * radius * outerR);
      
      canvas.drawLine(
        p1, p2,
        Paint()
          ..color = isActive ? color.withOpacity(0.9) : Colors.white.withOpacity(0.1)
          ..strokeWidth = isActive ? 4 : 2
          ..strokeCap = StrokeCap.square
          ..maskFilter = isActive ? MaskFilter.blur(BlurStyle.normal, 2 + pulse * 2) : null,
      );
    }

    // Central technical core
    canvas.drawCircle(center, radius * 0.4, Paint()..color = Colors.white.withOpacity(0.02)..style = PaintingStyle.stroke..strokeWidth = 1);
    
    if (isRunning) {
      // Pulsing hexagon or core
      final path = Path();
      const sides = 6;
      final coreR = radius * (0.15 + pulse * 0.05);
      for (int i = 0; i < sides; i++) {
        final angle = (i * 2 * math.pi / sides) + liquidValue * math.pi;
        final x = center.dx + math.cos(angle) * coreR;
        final y = center.dy + math.sin(angle) * coreR;
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  // ──────────────────────────────────────────────────
  //  AURA ENERGY DESIGN
  // ──────────────────────────────────────────────────
  void _paintAura(Canvas canvas, Offset center, double radius) {
    // 1. Energy Atmosphere
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(0.6), color.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 + pulse * 30);
    
    canvas.drawCircle(center, radius * (0.7 + pulse * 0.2), auraPaint);

    // 2. Cinematic Progress Ring
    final ringR = radius * 0.88;
    canvas.drawCircle(center, ringR, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withOpacity(0.1));
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringR),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.5), color],
          stops: const [0.0, 0.5, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: ringR))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 3. Central Energy Seed
    canvas.drawCircle(center, radius * 0.06, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
    canvas.drawCircle(center, radius * 0.12, Paint()..color = color.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
  }

  @override
  bool shouldRepaint(covariant CinematicOrbPainter oldDelegate) => true;
}
