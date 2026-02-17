import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'pomodoro_settings_page.dart';
import 'pomodoro_stats_page.dart';
import 'pomodoro_save_session_page.dart';
import 'my_program_page.dart';

class ModernPomodoroPage extends StatefulWidget {
  const ModernPomodoroPage({super.key});

  @override
  State<ModernPomodoroPage> createState() => ModernPomodoroPageState();
}

class ModernPomodoroPageState extends State<ModernPomodoroPage>
    with TickerProviderStateMixin {
  // Timer settings
  int _sessionCount = 4;
  int _sessionDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  bool _useLongBreak = false;
  bool _isDarkMode = true;

  // Timer state
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreakTime = false;
  int _currentSession = 0;
  Duration _remainingTime = const Duration(minutes: 25);
  Timer? _timer;

  late AnimationController _pulseController;
  late AnimationController _bgAnimationController;

  // Session records
  List<Map<String, dynamic>> _sessionRecords = [];
  DateTime? _currentWorkStartTime;
  DateTime? _currentBreakStartTime;
  Duration _currentWorkDuration = Duration.zero;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Update AppBar title
      }
    });
    _loadSettings();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    _pulseController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sessionCount = prefs.getInt('pomodoro_session_count') ?? 4;
      _sessionDuration = prefs.getInt('pomodoro_session_duration') ?? 25;
      _shortBreakDuration = prefs.getInt('pomodoro_short_break') ?? 5;
      _longBreakDuration = prefs.getInt('pomodoro_long_break') ?? 15;
      _useLongBreak = prefs.getBool('pomodoro_use_long_break') ?? false;
      _isDarkMode = prefs.getBool('pomodoro_dark_mode') ?? true;
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
  }

  void _startTimer() {
    if (_isPaused) {
      _resumeTimer();
      return;
    }
    if (!_isBreakTime && _currentWorkStartTime == null) {
      _currentWorkStartTime = DateTime.now();
      _currentWorkDuration = Duration.zero;
    }
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          if (!_isBreakTime) {
            _currentWorkDuration = Duration(
              seconds: _currentWorkDuration.inSeconds + 1,
            );
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _pauseTimer() {
    setState(() => _isPaused = true);
    _timer?.cancel();
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          if (!_isBreakTime) {
            _currentWorkDuration = Duration(
              seconds: _currentWorkDuration.inSeconds + 1,
            );
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _finalizeSession();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isBreakTime = false;
      _remainingTime = Duration(minutes: _sessionDuration);
    });
  }

  void _finalizeSession() {
    if (_currentWorkStartTime != null && _currentWorkDuration.inSeconds > 0) {
      _sessionRecords.add({
        'type': 'work',
        'startTime': _currentWorkStartTime!,
        'endTime': DateTime.now(),
        'duration': _currentWorkDuration,
      });
      _currentWorkStartTime = null;
      _currentWorkDuration = Duration.zero;
    }
    if (_currentBreakStartTime != null) {
      _sessionRecords.add({
        'type': 'break',
        'startTime': _currentBreakStartTime!,
        'endTime': DateTime.now(),
        'duration': DateTime.now().difference(_currentBreakStartTime!),
      });
      _currentBreakStartTime = null;
    }
  }

  void _completeSession() {
    _timer?.cancel();
    if (!_isBreakTime) {
      _finalizeSession();
      setState(() {
        _currentSession++;
      });
      if (_currentSession < _sessionCount) {
        _showBreakSelection();
      } else {
        _showSavePage();
      }
    } else {
      _finalizeSession();
      setState(() {
        _isBreakTime = false;
        _remainingTime = Duration(minutes: _sessionDuration);
        _isRunning = false;
      });
    }
  }

  void _startBreak(int minutes) {
    _finalizeSession();
    _currentBreakStartTime = DateTime.now();
    setState(() {
      _isBreakTime = true;
      _remainingTime = Duration(minutes: minutes);
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(
          () =>
              _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1),
        );
      } else {
        _completeSession();
      }
    });
  }

  void _skipBreak() {
    _timer?.cancel();
    _finalizeSession();
    setState(() {
      _isBreakTime = false;
      _remainingTime = Duration(minutes: _sessionDuration);
      _isRunning = false;
    });
  }

  void _showBreakSelection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Oturum Bitti!',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w200,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildBreakOption(
                    'Kısa Mola',
                    _shortBreakDuration,
                    const Color(0xFF00FFA3),
                    isDark,
                    () {
                      Navigator.pop(context);
                      _startBreak(_shortBreakDuration);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBreakOption(
                    'Uzun Mola',
                    _longBreakDuration,
                    const Color(0xFF00FFCC),
                    isDark,
                    () {
                      Navigator.pop(context);
                      _startBreak(_longBreakDuration);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakOption(
    String label,
    int minutes,
    Color color,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.coffee_rounded, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isDark ? color : color.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$minutes dk',
              style: TextStyle(
                color: isDark ? color.withOpacity(0.7) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavePage() {
    _finalizeSession();
    final totalWorkMinutes = _sessionRecords
        .where((r) => r['type'] == 'work')
        .fold<Duration>(
          Duration.zero,
          (prev, r) => prev + (r['duration'] as Duration),
        )
        .inMinutes;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroSaveSessionPage(
          sessionCount: _sessionRecords
              .where((r) => r['type'] == 'work')
              .length,
          totalMinutes: totalWorkMinutes,
          sessionDuration: _sessionDuration,
          onSaved: () {
            setState(() {
              _sessionRecords.clear();
              _currentSession = 0;
            });
            _stopTimer();
          },
        ),
      ),
    );
  }

  void _showSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroSettingsPage(
          sessionCount: _sessionCount,
          sessionDuration: _sessionDuration,
          shortBreakDuration: _shortBreakDuration,
          longBreakDuration: _longBreakDuration,
          useLongBreak: _useLongBreak,
          isDarkMode: _isDarkMode,
          onSettingsChanged: (settings) {
            setState(() {
              _sessionCount = settings['sessionCount'];
              _sessionDuration = settings['sessionDuration'];
              _shortBreakDuration = settings['shortBreakDuration'];
              _longBreakDuration = settings['longBreakDuration'];
              _useLongBreak = settings['useLongBreak'];
              _isDarkMode = settings['isDarkMode'];
              if (!_isRunning)
                _remainingTime = Duration(minutes: _sessionDuration);
            });
            _saveSettings();
          },
        ),
      ),
    );
  }

  double _getProgress() {
    final total = _isBreakTime
        ? (_remainingTime.inSeconds > 0 ? _remainingTime.inSeconds : 1)
        : (_sessionDuration * 60);
    return 1.0 - (_remainingTime.inSeconds / total);
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FE),
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: isDark
              ? Colors.black.withOpacity(0.2)
              : Colors.white.withOpacity(0.2),
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87,
              size: 20,
            ),
          ),
          centerTitle: true,
          title: Text(
            _tabController.index == 0 ? 'Pomodoro' : 'Program',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          actions: [
            _BlurButton(
              icon: Icons.bar_chart_rounded,
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PomodoroStatsPage()),
              ),
            ),
            const SizedBox(width: 8),
            _BlurButton(
              icon: Icons.settings_rounded,
              isDark: isDark,
              onTap: _showSettings,
            ),
            const SizedBox(width: 16),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'POMODORO'),
              Tab(text: 'PROGRAM'),
            ],
            indicatorColor: _isBreakTime
                ? const Color(0xFF00FFA3)
                : const Color(0xFF6366F1),
            indicatorWeight: 3,
            labelColor: isDark ? Colors.white : Colors.black87,
            unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTimerTab(size, isLandscape, isDark),
            _buildProgramTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramTab(bool isDark) {
    return Stack(
      children: [
        _buildBackground(isDark),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
          ),
          child: const MyProgramPage(isTransparent: true),
        ),
      ],
    );
  }

  Widget _buildTimerTab(Size size, bool isLandscape, bool isDark) {
    return Stack(
      children: [
        _buildBackground(isDark),
        SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(
                height: kToolbarHeight + 48,
              ), // Space for AppBar + Tabs
              Expanded(
                child: Center(child: _buildOrb(size, isLandscape, isDark)),
              ),
              _buildDock(isDark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(bool isDark) {
    return AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: AuroraAtmospherePainter(
          animationValue: _bgAnimationController.value,
          isBreak: _isBreakTime,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildOrb(Size size, bool isLandscape, bool isDark) {
    final orbSize = isLandscape ? size.height * 0.55 : size.width * 0.85;
    final primaryColor = _isBreakTime
        ? const Color(0xFF00FFA3)
        : const Color(0xFF6366F1);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(orbSize, orbSize),
            painter: SpatialOrbPainter(
              progress: _getProgress(),
              pulse: _pulseController.value,
              color: primaryColor,
              isRunning: _isRunning && !_isPaused,
              isDark: isDark,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDuration(_remainingTime),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: orbSize * 0.22,
                  fontWeight: FontWeight.w100,
                  letterSpacing: -5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: isDark
                      ? []
                      : [
                          Shadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (_isBreakTime ? 'M O L A' : 'F O K U S').split('').join(' '),
                style: TextStyle(
                  color: primaryColor.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
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
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRunning || _isPaused) ...[
                  _DockButton(
                    icon: Icons.stop_rounded,
                    onTap: _stopTimer,
                    color: Colors.transparent,
                    iconColor: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 8),
                ],
                _DockButton(
                  icon: _isRunning && !_isPaused
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: _isRunning && !_isPaused ? _pauseTimer : _startTimer,
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.08),
                  iconColor: isDark ? Colors.white : Colors.black87,
                  isPrimary: true,
                  isDark: isDark,
                ),
                if (_isBreakTime) ...[
                  const SizedBox(width: 8),
                  _DockButton(
                    icon: Icons.skip_next_rounded,
                    onTap: _skipBreak,
                    color: Colors.transparent,
                    iconColor: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ],
            ),
          ),
        ),
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
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 20 : 12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: isPrimary
              ? Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withOpacity(0.1),
                )
              : null,
        ),
        child: Icon(icon, color: iconColor, size: isPrimary ? 32 : 24),
      ),
    );
  }
}

class _BlurButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _BlurButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            child: Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class AuroraAtmospherePainter extends CustomPainter {
  final double animationValue;
  final bool isBreak;
  final bool isDark;
  AuroraAtmospherePainter({
    required this.animationValue,
    required this.isBreak,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    final primaryColor = isBreak
        ? const Color(0xFF00FFCC)
        : const Color(0xFF6366F1);

    // Background base for light mode
    if (!isDark) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF8F9FE),
      );
    }

    for (int i = 0; i < 3; i++) {
      final angle = (animationValue * 2 * math.pi) + (i * math.pi * 2 / 3);
      final x = size.width / 2 + math.cos(angle) * (size.width * 0.4);
      final y = size.height / 2 + math.sin(angle * 0.5) * (size.height * 0.4);
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.7,
        paint..color = primaryColor.withOpacity(isDark ? 0.06 : 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SpatialOrbPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final Color color;
  final bool isRunning;
  final bool isDark;

  SpatialOrbPainter({
    required this.progress,
    required this.pulse,
    required this.color,
    required this.isRunning,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Deep Core Glow (Dynamic)
    final coreGradient = RadialGradient(
      colors: [
        color.withOpacity(isDark ? 0.3 * (1.0 + pulse * 0.2) : 0.2),
        color.withOpacity(0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);

    canvas.drawCircle(center, radius, Paint()..shader = coreGradient);

    // 2. Secondary Pulsing Ring (The "Premium" hint)
    final secondaryRadius = radius * (0.75 + (pulse * 0.03));
    final secondaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withOpacity(isDark ? 0.2 : 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, secondaryRadius, secondaryPaint);

    // 3. Main Progress Track (Minimal & Glassy)
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.04);
    canvas.drawCircle(center, radius * 0.85, trackPaint);

    // 4. Glowing Progress Ring
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: (math.pi * 1.5),
        colors: [color, color.withOpacity(0.4), color],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(-math.pi / 2 + (2 * math.pi * progress)),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.85));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // 5. Spatial Particles (Refined)
    if (isRunning) {
      final particlePaint = Paint()
        ..color = (isDark ? Colors.white : color).withOpacity(0.4);
      for (int i = 0; i < 15; i++) {
        final angle = (pulse * math.pi * 0.5) + (i * 2 * math.pi / 15);
        final distance = radius * 0.92 + math.sin(pulse * 10 + i) * 6;
        final x = center.dx + math.cos(angle) * distance;
        final y = center.dy + math.sin(angle) * distance;

        canvas.drawCircle(Offset(x, y), 1.2, particlePaint);

        // Very subtle tail/glow for particles
        canvas.drawCircle(
          Offset(x, y),
          3,
          Paint()..color = (isDark ? Colors.white : color).withOpacity(0.02),
        );
      }
    }

    // 6. Center Glass Reflection (Top half)
    final reflectionPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (isDark ? Colors.white : Colors.white).withOpacity(
                isDark ? 0.08 : 0.2,
              ),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(
              center.dx - radius * 0.4,
              center.dy - radius * 0.6,
              radius * 0.8,
              radius * 0.4,
            ),
          );

    canvas.drawOval(
      Rect.fromLTWH(
        center.dx - radius * 0.4,
        center.dy - radius * 0.6,
        radius * 0.8,
        radius * 0.3,
      ),
      reflectionPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
