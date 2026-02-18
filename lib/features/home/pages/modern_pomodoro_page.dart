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
  bool _showSessionHistory = true;
  String _selectedTheme = 'indigo'; // indigo, emerald, rose, amber
  String _selectedOrbDesign = 'liquid'; // liquid, minimal, rings

  // Timer state
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreakTime = false;
  int _currentSession = 0;
  Duration _remainingTime = const Duration(minutes: 25);
  Timer? _timer;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _bgAnimationController;
  late AnimationController _liquidController;

  // Actual storage for saving to DB
  List<Map<String, dynamic>> _sessionRecords = [];

  // UI History (Grouped Segments)
  final List<Map<String, dynamic>> _segments = [];

  DateTime? _currentWorkStartTime;
  DateTime? _currentBreakStartTime;
  Duration _currentWorkDuration = Duration.zero;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
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
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    _pulseController.dispose();
    _bgAnimationController.dispose();
    _liquidController.dispose();
    super.dispose();
  }

  void _startNewSegment() {
    final type = _isBreakTime ? 'Mola' : 'Odaklanma';
    final primaryColor = _getThemeColor();

    setState(() {
      _segments.insert(0, {
        'type': type,
        'startTime': DateTime.now(),
        'endTime': null,
        'duration': Duration.zero,
        'color': primaryColor,
      });
    });
  }

  void _endCurrentSegment() {
    if (_segments.isNotEmpty && _segments[0]['endTime'] == null) {
      setState(() {
        _segments[0]['endTime'] = DateTime.now();
        _segments[0]['duration'] = DateTime.now().difference(
          _segments[0]['startTime'] as DateTime,
        );
      });
    }
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
      _showSessionHistory = prefs.getBool('pomodoro_show_history') ?? true;
      _selectedTheme = prefs.getString('pomodoro_theme') ?? 'indigo';
      _selectedOrbDesign = prefs.getString('pomodoro_orb_design') ?? 'liquid';
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

  void _startTimer() {
    if (_isPaused) {
      _resumeTimer();
      return;
    }

    _startNewSegment();

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
          if (_segments.isNotEmpty && _segments[0]['endTime'] == null) {
            _segments[0]['duration'] = DateTime.now().difference(
              _segments[0]['startTime'] as DateTime,
            );
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _pauseTimer() {
    _endCurrentSegment();
    setState(() => _isPaused = true);
    _timer?.cancel();
  }

  void _resumeTimer() {
    _startNewSegment();
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
          if (_segments.isNotEmpty && _segments[0]['endTime'] == null) {
            _segments[0]['duration'] = DateTime.now().difference(
              _segments[0]['startTime'] as DateTime,
            );
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _showStopConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Oturumu Bitir?',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Mevcut ilerlemenizi kaydetmek ister misiniz?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _stopTimer(save: false);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopTimer(save: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Kaydet',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _stopTimer({bool save = true}) {
    _timer?.cancel();
    _endCurrentSegment();
    if (save) {
      _finalizeSession();
      if (_sessionRecords.isNotEmpty) _showSavePage();
    } else {
      _sessionRecords.clear();
      _segments.clear();
      _currentWorkStartTime = null;
      _currentWorkDuration = Duration.zero;
      _currentBreakStartTime = null;
    }
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isBreakTime = false;
      _currentSession = 0;
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
    _endCurrentSegment();
    if (!_isBreakTime) {
      _finalizeSession();
      setState(() => _currentSession++);
      if (_currentSession < _sessionCount)
        _showBreakSelection();
      else
        _showSavePage();
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
    _startNewSegment();
    setState(() {
      _isBreakTime = true;
      _remainingTime = Duration(minutes: minutes);
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          if (_segments.isNotEmpty && _segments[0]['endTime'] == null) {
            _segments[0]['duration'] = DateTime.now().difference(
              _segments[0]['startTime'] as DateTime,
            );
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _skipBreak() {
    _timer?.cancel();
    _endCurrentSegment();
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
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Oturum Bitti',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
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
                const SizedBox(width: 12),
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
            const SizedBox(height: 16),
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
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.coffee_rounded, color: color, size: 24),
            const SizedBox(
              height: 8,
            ), // Changed from 9 to 8 to match existing code
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              '$minutes dk',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
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
              _segments.clear();
              _currentSession = 0;
            });
            _stopTimer(save: false);
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
          showSessionHistory: _showSessionHistory,
          selectedTheme: _selectedTheme,
          selectedOrbDesign: _selectedOrbDesign,
          onSettingsChanged: (settings) {
            setState(() {
              _sessionCount = settings['sessionCount'] as int;
              _sessionDuration = settings['sessionDuration'] as int;
              _shortBreakDuration = settings['shortBreakDuration'] as int;
              _longBreakDuration = settings['longBreakDuration'] as int;
              _useLongBreak = settings['useLongBreak'] as bool;
              _isDarkMode = settings['isDarkMode'] as bool;
              _showSessionHistory =
                  settings['showSessionHistory'] as bool? ?? true;
              _selectedTheme = settings['selectedTheme'] as String? ?? 'indigo';
              _selectedOrbDesign =
                  settings['selectedOrbDesign'] as String? ?? 'liquid';

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

  double _getProgress() {
    final total = _isBreakTime
        ? (_remainingTime.inSeconds > 0 ? _remainingTime.inSeconds : 1)
        : (_sessionDuration * 60);
    return 1.0 - (_remainingTime.inSeconds / (total > 0 ? total : 1));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildAuroraBlob({
    required double size,
    required Color color,
    required double blur,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: blur,
            spreadRadius: blur / 2,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF020617)
            : const Color(0xFFF8FAFC),
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          toolbarHeight: 56,
          title: Text(
            'ÇALIŞMALARIM',
            style: TextStyle(
              color: _tabController.index == 0
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: _tabController.index == 0
                  ? [
                      const Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
          flexibleSpace: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _tabController.index == 0 ? 1 : 0,
            child: Stack(
              children: [
                // Vibrant Solar Gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFF3366), // Vibrant Pink
                        Color(0xFFFFAC33), // Bright Orange
                        Color(0xFF6366F1), // Indigo
                      ],
                    ),
                  ),
                ),
                // Overlay blobs for depth
                Positioned(
                  top: -30,
                  right: -10,
                  child: _buildAuroraBlob(
                    size: 180,
                    color: Colors.white.withValues(alpha: 0.15),
                    blur: 40,
                  ),
                ),
                Positioned(
                  bottom: -20,
                  left: 0,
                  child: _buildAuroraBlob(
                    size: 140,
                    color: const Color(0xFF00D2FF).withValues(alpha: 0.15),
                    blur: 30,
                  ),
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _tabController.index == 0
                      ? Colors.white.withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _tabController.index == 0
                        ? Colors.white.withValues(alpha: 0.2)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1)),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'PROGRAMIM'),
                    Tab(text: 'POMODORO'),
                  ],
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: _tabController.index == 0
                        ? Colors.white
                        : (isDark ? Colors.white24 : Colors.white),
                    boxShadow: _tabController.index == 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  labelColor: _tabController.index == 0
                      ? const Color(0xFFFF3366)
                      : (isDark ? Colors.white : const Color(0xFFFF3366)),
                  unselectedLabelColor: _tabController.index == 0
                      ? Colors.white
                      : (isDark ? Colors.white38 : Colors.black38),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    fontSize: 10,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
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
      color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 48,
        ),
        child: const MyProgramPage(isTransparent: false),
      ),
    );
  }

  Widget _buildTimerTab(Size size, bool isLandscape, bool isDark) {
    return Stack(
      children: [
        _buildBackground(isDark),
        SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 8,
                child: Center(child: _buildOrb(size, isLandscape, isDark)),
              ),
              if (_showSessionHistory) _buildProfessionalHistory(isDark),
              const SizedBox(height: 24),
              _buildDock(isDark),
              const SizedBox(height: 16),
              // Labeled buttons for better clarity
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BlurButton(
                          icon: Icons.bar_chart_rounded,
                          isDark: isDark,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PomodoroStatsPage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'İSTATİSTİK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.4),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48), // Increased spacing for labels
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BlurButton(
                          icon: Icons.settings_rounded,
                          isDark: isDark,
                          onTap: _showSettings,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AYARLAR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.4),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80), // Avoid Nav Bar
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfessionalHistory(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OTURUM KAYİTLARİ',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (_isRunning && !_isPaused) const _LivePulse(),
                  ],
                ),
                const SizedBox(height: 12),
                if (_segments.isEmpty)
                  Center(
                    child: Text(
                      'Henüz aktivite yok',
                      style: TextStyle(
                        color: isDark ? Colors.white12 : Colors.black12,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _segments.length,
                      separatorBuilder: (_, __) => Divider(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.03),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final seg = _segments[index];
                        final isActive = index == 0 && _isRunning && !_isPaused;
                        return _buildSegmentCard(
                          seg['type'],
                          seg['startTime'],
                          seg['endTime'],
                          seg['duration'],
                          seg['color'],
                          isActive,
                          isDark,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentCard(
    String type,
    DateTime start,
    DateTime? end,
    Duration duration,
    Color color,
    bool isActive,
    bool isDark,
  ) {
    final timeStr =
        "${DateFormat.format('HH:mm', start)} - ${end != null ? DateFormat.format('HH:mm', end) : '...'}";
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              type == 'Mola' ? Icons.coffee_rounded : Icons.bolt_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isDark ? Colors.white24 : Colors.black38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDetailedDuration(duration),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isActive)
                Text(
                  'CANLI',
                  style: TextStyle(
                    color: color.withOpacity(0.5),
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDetailedDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours}sa ${d.inMinutes % 60}dk";
    if (d.inMinutes > 0) return "${d.inMinutes}dk ${d.inSeconds % 60}s";
    return "${d.inSeconds}s";
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
          themeColor: _getThemeColor(),
        ),
      ),
    );
  }

  Widget _buildOrb(Size size, bool isLandscape, bool isDark) {
    final orbSize = isLandscape ? size.height * 0.75 : size.width * 0.88;
    final primaryColor = _getThemeColor();
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
              color: primaryColor,
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
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black.withOpacity(0.85),
                  fontSize:
                      orbSize *
                      0.22, // Slightly smaller size for better proportion
                  fontWeight: FontWeight.w600, // Thicker weight for clarity
                  letterSpacing: 0, // Clean spacing
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              Text(
                _isBreakTime ? 'DİNLENME MODU' : 'ODAKLANMA VAKTİ',
                style: TextStyle(
                  color: primaryColor.withOpacity(0.5),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              if (_isRunning || _isPaused)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.05,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.05),
                      ),
                    ),
                    child: Text(
                      '${_currentSession + 1} / $_sessionCount',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
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
                  iconColor: isDark
                      ? Colors.white.withOpacity(0.34)
                      : Colors.black.withOpacity(0.34),
                ),
                const SizedBox(width: 4),
              ],
              _DockButton(
                icon: _isRunning && !_isPaused
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: _isRunning && !_isPaused ? _pauseTimer : _startTimer,
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.08),
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
                  iconColor: isDark
                      ? Colors.white.withOpacity(0.34)
                      : Colors.black.withOpacity(0.34),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse();
  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'CANLI',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 7,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
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
  final bool isPrimary, isDark;
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
        padding: EdgeInsets.all(isPrimary ? 16 : 10),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: iconColor, size: isPrimary ? 28 : 22),
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
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(8),
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            child: Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 16,
            ),
          ),
        ),
      ),
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
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    final primaryColor = isBreak ? const Color(0xFF00FFCC) : themeColor;
    if (!isDark)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF8FAFC),
      );
    for (int i = 0; i < 3; i++) {
      final angle = (animationValue * 2 * math.pi) + (i * math.pi * 2 / 3);
      final x = size.width / 2 + math.cos(angle) * (size.width * 0.4);
      final y = size.height / 2 + math.sin(angle * 0.5) * (size.height * 0.4);
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.7,
        paint..color = primaryColor.withOpacity(isDark ? 0.03 : 0.05),
      );
    }
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

    if (design == 'rings') {
      _paintRings(canvas, center, radius);
    } else if (design == 'modern') {
      _paintModern(canvas, center, radius);
    } else if (design == 'none') {
      _paintMinimal(canvas, center, radius);
    } else {
      _paintLiquid(canvas, center, radius, size);
    }
  }

  void _paintMinimal(Canvas canvas, Offset center, double radius) {
    // Very subtle background ring
    canvas.drawCircle(
      center,
      radius * 0.9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05),
    );

    // Precise, thin progress arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = color.withOpacity(0.8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.9),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );

    // Tiny dot at the end of progress
    if (progress > 0) {
      final ang = -math.pi / 2 + (2 * math.pi * progress);
      final pos = Offset(
        center.dx + math.cos(ang) * (radius * 0.9),
        center.dy + math.sin(ang) * (radius * 0.9),
      );
      canvas.drawCircle(pos, 3, Paint()..color = color);
    }
  }

  void _paintLiquid(Canvas canvas, Offset center, double radius, Size size) {
    // Original Liquid Design logic
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(isDark ? 0.1 : 0.05),
            color.withOpacity(0.01),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    if (isRunning) {
      final path = Path();
      final y = center.dy - (radius * 0.8) + (radius * 1.6 * progress);
      path.moveTo(center.dx - radius, size.height);
      for (double i = 0; i <= size.width; i++) {
        path.lineTo(
          i,
          y +
              math.sin(
                    (i / size.width * 2 * math.pi) +
                        (liquidValue * 2 * math.pi),
                  ) *
                  8,
        );
      }
      path.lineTo(center.dx + radius, size.height);
      path.close();
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.9)),
      );
      canvas.drawPath(path, Paint()..color = color.withOpacity(0.15));
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = (isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.2), color, color.withOpacity(0.2)],
        transform: GradientRotation(
          -math.pi / 2 + (2 * math.pi * progress) - 0.4,
        ),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.88));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );

    final ang = -math.pi / 2 + (2 * math.pi * progress);
    final pos = Offset(
      center.dx + math.cos(ang) * (radius * 0.88),
      center.dy + math.sin(ang) * (radius * 0.88),
    );
    canvas.drawCircle(
      pos,
      8,
      Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(pos, 4, Paint()..color = color);
    canvas.drawCircle(pos, 1.5, Paint()..color = Colors.white);
  }

  void _paintRings(Canvas canvas, Offset center, double radius) {
    for (int i = 0; i < 3; i++) {
      final ringRadius = radius * (0.6 + i * 0.15) + (pulse * 5);
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + (1 - i * 0.3)
          ..color = color.withOpacity((0.3 - i * 0.1) * (1 - progress)),
      );
    }
    final mainArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.88),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      mainArc,
    );

    // Glow effect
    canvas.drawCircle(
      center,
      radius * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.2 * (pulse + 0.5)), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6)),
    );
  }

  void _paintModern(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.05);

    canvas.drawCircle(center, radius * 0.85, paint);

    final segments = 40;
    final spacing = 0.05;
    final segmentAngle = (2 * math.pi) / segments;

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (int i = 0; i < segments; i++) {
      double startAngle = -math.pi / 2 + (i * segmentAngle);
      double sweepAngle = segmentAngle - spacing;

      bool isActive = (i / segments) < progress;
      if (isActive) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * 0.85),
          startAngle,
          sweepAngle,
          false,
          activePaint,
        );
      }
    }

    // Centered breathing glow
    canvas.drawCircle(
      center,
      radius * 0.4,
      Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + pulse * 10)
        ..color = color.withOpacity(0.1 * (pulse + 0.5)),
    );
  }

  @override
  bool shouldRepaint(covariant CinematicOrbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse ||
      oldDelegate.liquidValue != liquidValue ||
      oldDelegate.design != design;
}

class DateFormat {
  static String format(String pattern, DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
