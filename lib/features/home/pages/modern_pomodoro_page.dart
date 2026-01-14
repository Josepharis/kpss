import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';
import 'pomodoro_settings_page.dart';
import 'pomodoro_stats_page.dart';
import 'pomodoro_save_session_page.dart';

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
  bool _isDarkMode = false;

  // Timer state
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreakTime = false;
  int _currentSession = 0;
  Duration _remainingTime = const Duration(minutes: 25);
  Timer? _timer;
  VideoPlayerController? _videoController;
  bool _videoAvailable = false;

  late AnimationController _pulseController;
  
  // Session records
  List<Map<String, dynamic>> _sessionRecords = [];
  DateTime? _currentWorkStartTime;
  DateTime? _currentBreakStartTime;
  Duration _currentWorkDuration = Duration.zero;
  int _completedMinutes = 0; // For backward compatibility

  @override
  void initState() {
    super.initState();
    _remainingTime = Duration(minutes: _sessionDuration);
    _loadSettings();
    
    // Pulse animation for timer
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Video'yu ilk frame'den sonra başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideo();
    });
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;
    
    try {
      // Eski controller'ı temizle
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }
      
      if (!mounted) return;
      
      // Video controller'ı oluştur
      _videoController = VideoPlayerController.asset('assets/images/kum.mp4');
      
      // Listener ekle
      _videoController!.addListener(_videoListener);
      
      // Video'yu initialize et
      await _videoController!.initialize();
      
      if (!mounted) return;
      
      // Video başarıyla yüklendi
      if (_videoController!.value.isInitialized && !_videoController!.value.hasError) {
        _videoController!.setLooping(true);
        _videoController!.setVolume(0);
        _videoAvailable = true;
        
        // Video'yu oynatma - sadece timer başlatıldığında oynatılacak
        
        if (mounted) {
          setState(() {});
        }
      } else {
        _videoAvailable = false;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      _videoAvailable = false;
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  void _videoListener() {
    if (_videoController != null && _videoController!.value.hasError) {
      _videoAvailable = false;
      if (mounted) {
        setState(() {});
      }
    } else if (_videoController != null && _videoController!.value.isInitialized) {
      if (!_videoAvailable) {
        _videoAvailable = true;
        if (mounted) {
          setState(() {});
        }
      }
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
      _isDarkMode = prefs.getBool('pomodoro_dark_mode') ?? false;
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

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void showSettings() {
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
          onSettingsChanged: (settings) {
            setState(() {
              _sessionCount = settings['sessionCount'] as int;
              _sessionDuration = settings['sessionDuration'] as int;
              _shortBreakDuration = settings['shortBreakDuration'] as int;
              _longBreakDuration = settings['longBreakDuration'] as int;
              _useLongBreak = settings['useLongBreak'] as bool;
              _isDarkMode = settings['isDarkMode'] as bool;
              
              // Timer çalışmıyorsa veya mola sırasındaysa süreyi güncelle
              if (!_isRunning || _isBreakTime) {
                if (_isBreakTime) {
                  // Mola sırasındaysa mevcut mola süresini koru
                  // (uzun mola butonu ile değiştirilebilir)
                } else {
                  // Çalışma sırasında değilse yeni süreyi ayarla
                  _remainingTime = Duration(minutes: _sessionDuration);
                }
              }
            });
            _saveSettings();
          },
        ),
      ),
    );
  }

  void _startTimer() {
    if (_isPaused) {
      _resumeTimer();
      return;
    }

    // Çalışma başlangıcını kaydet
    if (!_isBreakTime && _currentWorkStartTime == null) {
      _currentWorkStartTime = DateTime.now();
      _currentWorkDuration = Duration.zero;
    }

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    if (_videoAvailable && 
        _videoController != null && 
        _videoController!.value.isInitialized) {
      try {
        _videoController?.play();
      } catch (e) {
        // Video play error
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          if (!_isBreakTime) {
            _completedMinutes++;
            _currentWorkDuration = Duration(seconds: _currentWorkDuration.inSeconds + 1);
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _pauseTimer() {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
    if (_videoAvailable && 
        _videoController != null && 
        _videoController!.value.isInitialized) {
      try {
        _videoController?.pause();
      } catch (e) {
        // Video pause error
      }
    }
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
    });
    if (_videoAvailable && 
        _videoController != null && 
        _videoController!.value.isInitialized) {
      try {
        _videoController?.play();
      } catch (e) {
        // Video play error
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          if (!_isBreakTime) {
            _completedMinutes++;
          }
        });
      } else {
        _completeSession();
      }
    });
  }

  void _startBreak(int minutes) {
    _timer?.cancel();
    
    // Çalışma kaydını kaydet
    if (_currentWorkStartTime != null && _currentWorkDuration.inSeconds > 0) {
      final workEndTime = DateTime.now();
      _sessionRecords.add({
        'type': 'work',
        'startTime': _currentWorkStartTime!,
        'endTime': workEndTime,
        'duration': _currentWorkDuration,
      });
      _currentWorkStartTime = null;
      _currentWorkDuration = Duration.zero;
    }
    
    // Mola başlangıcını kaydet
    _currentBreakStartTime = DateTime.now();
    
    setState(() {
      _isBreakTime = true;
      _remainingTime = Duration(minutes: minutes);
      _isRunning = true;
      _isPaused = false;
    });

    if (_videoAvailable && 
        _videoController != null && 
        _videoController!.value.isInitialized) {
      try {
        _videoController?.play();
      } catch (e) {
        // Video play error
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        });
      } else {
        _endBreak();
      }
    });
  }

  void _endBreak() {
    _timer?.cancel();
    
    // Mola kaydını kaydet
    if (_currentBreakStartTime != null) {
      final breakEndTime = DateTime.now();
      final breakDuration = breakEndTime.difference(_currentBreakStartTime!);
      _sessionRecords.add({
        'type': 'break',
        'startTime': _currentBreakStartTime!,
        'endTime': breakEndTime,
        'duration': breakDuration,
      });
      _currentBreakStartTime = null;
    }
    
    if (_videoAvailable && 
        _videoController != null && 
        _videoController!.value.isInitialized) {
      try {
        _videoController?.pause();
        _videoController?.seekTo(Duration.zero);
      } catch (e) {
        // Video seek error
      }
    }

    setState(() {
      _isBreakTime = false;
      _isRunning = false;
      _isPaused = false;
      _remainingTime = Duration(minutes: _sessionDuration);
    });
  }

  void _skipBreak() {
    if (_isBreakTime) {
      _endBreak();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    
    // Aktif çalışma kaydını kaydet
    if (_currentWorkStartTime != null && _currentWorkDuration.inSeconds > 0) {
      final workEndTime = DateTime.now();
      _sessionRecords.add({
        'type': 'work',
        'startTime': _currentWorkStartTime!,
        'endTime': workEndTime,
        'duration': _currentWorkDuration,
      });
      _currentWorkStartTime = null;
      _currentWorkDuration = Duration.zero;
    }
    
    // Aktif mola kaydını kaydet
    if (_currentBreakStartTime != null) {
      final breakEndTime = DateTime.now();
      final breakDuration = breakEndTime.difference(_currentBreakStartTime!);
      _sessionRecords.add({
        'type': 'break',
        'startTime': _currentBreakStartTime!,
        'endTime': breakEndTime,
        'duration': breakDuration,
      });
      _currentBreakStartTime = null;
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isBreakTime = false;
      _currentSession = 0;
      _remainingTime = Duration(minutes: _sessionDuration);
      _completedMinutes = 0;
    });
    if (_videoAvailable && _videoController != null) {
      try {
        _videoController?.pause();
        _videoController?.seekTo(Duration.zero);
      } catch (e) {
        // Video stop error
      }
    }
  }

  void _completeSession() {
    _timer?.cancel();
    if (_videoAvailable && _videoController != null) {
      try {
        _videoController?.pause();
        _videoController?.seekTo(Duration.zero);
      } catch (e) {
        // Video seek error
      }
    }

    if (!_isBreakTime) {
      // Çalışma kaydını kaydet
      if (_currentWorkStartTime != null && _currentWorkDuration.inSeconds > 0) {
        final workEndTime = DateTime.now();
        _sessionRecords.add({
          'type': 'work',
          'startTime': _currentWorkStartTime!,
          'endTime': workEndTime,
          'duration': _currentWorkDuration,
        });
        _currentWorkStartTime = null;
        _currentWorkDuration = Duration.zero;
      }
      
      setState(() {
        _currentSession++;
      });
      
      if (_currentSession < _sessionCount) {
        // Mola seçimi dialog'u göster
        _showBreakSelectionDialog();
      } else {
        _showSaveSessionDialog();
      }
    } else {
      // Mola kaydını kaydet
      if (_currentBreakStartTime != null) {
        final breakEndTime = DateTime.now();
        final breakDuration = breakEndTime.difference(_currentBreakStartTime!);
        _sessionRecords.add({
          'type': 'break',
          'startTime': _currentBreakStartTime!,
          'endTime': breakEndTime,
          'duration': breakDuration,
        });
        _currentBreakStartTime = null;
      }
      
      if (_currentSession < _sessionCount) {
        setState(() {
          _isBreakTime = false;
          _remainingTime = Duration(minutes: _sessionDuration);
          _isRunning = false;
          _isPaused = false;
        });
      } else {
        _showSaveSessionDialog();
      }
    }
  }
  
  void _showBreakSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee, color: AppColors.gradientGreenStart),
            SizedBox(width: 8),
            Text('Mola Zamanı! ☕'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Çalışma tamamlandı. Hangi molayı almak istersiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _startBreak(_shortBreakDuration);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.gradientGreenStart,
                              AppColors.gradientGreenEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gradientGreenStart.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.coffee,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kısa Mola',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_shortBreakDuration dakika',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _startBreak(_longBreakDuration);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.gradientTealStart,
                              AppColors.gradientTealEnd,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gradientTealStart.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_cafe,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Uzun Mola',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_longBreakDuration dakika',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
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

  void _finishWork() {
    // Timer'ı durdur
    _timer?.cancel();
    if (_videoAvailable && _videoController != null) {
      try {
        _videoController?.pause();
        _videoController?.seekTo(Duration.zero);
      } catch (e) {
        // Video stop error
      }
    }
    
    // Son çalışma kaydını kaydet
    if (_currentWorkStartTime != null && _currentWorkDuration.inSeconds > 0) {
      final workEndTime = DateTime.now();
      _sessionRecords.add({
        'type': 'work',
        'startTime': _currentWorkStartTime!,
        'endTime': workEndTime,
        'duration': _currentWorkDuration,
      });
      _currentWorkStartTime = null;
      _currentWorkDuration = Duration.zero;
    }
    
    // Aktif mola kaydını kaydet
    if (_currentBreakStartTime != null) {
      final breakEndTime = DateTime.now();
      final breakDuration = breakEndTime.difference(_currentBreakStartTime!);
      _sessionRecords.add({
        'type': 'break',
        'startTime': _currentBreakStartTime!,
        'endTime': breakEndTime,
        'duration': breakDuration,
      });
      _currentBreakStartTime = null;
    }
    
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isBreakTime = false;
    });
    
    // Kaydetme dialog'unu göster
    _showSaveSessionDialog();
  }

  void _showSaveSessionDialog() {
    final workCount = _sessionRecords.where((r) => r['type'] == 'work').length;
    final breakCount = _sessionRecords.where((r) => r['type'] == 'break').length;
    final totalWorkDuration = _sessionRecords
        .where((r) => r['type'] == 'work')
        .fold<Duration>(Duration.zero, (sum, record) => sum + (record['duration'] as Duration));
    final size = MediaQuery.of(context).size;
    final isCompact = size.height < 700;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 24),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kompakt Header
              Container(
                padding: EdgeInsets.all(isCompact ? 20 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gradientGreenStart,
                      AppColors.gradientGreenEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 12),
                    const Text(
                      'Çalışma Tamamlandı!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Kompakt Content
              Padding(
                padding: EdgeInsets.all(isCompact ? 18 : 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_sessionRecords.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(isCompact ? 14 : 16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primaryBlue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildCompactStatRow(
                              icon: Icons.work_outline,
                              label: 'Çalışma',
                              value: '$workCount',
                              color: AppColors.primaryBlue,
                              isCompact: isCompact,
                            ),
                            if (breakCount > 0) ...[
                              SizedBox(height: isCompact ? 8 : 10),
                              _buildCompactStatRow(
                                icon: Icons.coffee_outlined,
                                label: 'Mola',
                                value: '$breakCount',
                                color: AppColors.gradientGreenStart,
                                isCompact: isCompact,
                              ),
                            ],
                            SizedBox(height: isCompact ? 8 : 10),
                            _buildCompactStatRow(
                              icon: Icons.access_time_rounded,
                              label: 'Süre',
                              value: '${totalWorkDuration.inMinutes} dk',
                              color: AppColors.gradientTealStart,
                              isCompact: isCompact,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompact ? 14 : 16),
                    ],
                    Text(
                      'Çalışma kayıtlarınızı kaydetmek ister misiniz?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 15,
                        height: 1.4,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Kompakt Actions
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 18 : 20,
                  0,
                  isCompact ? 18 : 20,
                  isCompact ? 18 : 20,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _sessionRecords.clear();
                            _stopTimer();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Kaydetme',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isCompact ? 14 : 15,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 10 : 12),
                    Expanded(
                      flex: 2,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showSaveSessionPage();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gradientBlueStart,
                                  AppColors.gradientBlueEnd,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.25),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.save_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kaydet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompact ? 14 : 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
  
  Widget _buildCompactStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isCompact,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 6 : 7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: isCompact ? 16 : 17),
        ),
        SizedBox(width: isCompact ? 10 : 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 13 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showSaveSessionPage() {
    // Toplam çalışma süresini hesapla
    final totalWorkDuration = _sessionRecords
        .where((r) => r['type'] == 'work')
        .fold<Duration>(Duration.zero, (sum, record) => sum + (record['duration'] as Duration));
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroSaveSessionPage(
          sessionCount: _currentSession,
          totalMinutes: totalWorkDuration.inMinutes,
          sessionDuration: _sessionDuration,
          onSaved: () {
            _sessionRecords.clear();
            _stopTimer();
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  double _getProgress() {
    final totalSeconds = _isBreakTime
        ? (_currentSession % 4 == 0 && _useLongBreak
            ? _longBreakDuration
            : _shortBreakDuration) *
            60
        : _sessionDuration * 60;
    final remainingSeconds = _remainingTime.inSeconds;
    return 1.0 - (remainingSeconds / totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;
    final isLandscape = screenWidth > screenHeight;
    
    // Responsive timer size - landscape mode'da daha küçük
    double timerSize;
    if (isLandscape) {
      // Landscape mode'da ekran yüksekliğine göre ayarla
      timerSize = math.min(screenHeight * 0.5, screenWidth * 0.4);
    } else {
      // Portrait mode'da normal hesaplama
      timerSize = screenWidth < 400 
          ? screenWidth * 0.85 
          : screenHeight < 700 
              ? screenWidth * 0.80 
              : screenWidth * 0.85;
    }
    
    return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          toolbarHeight: 50,
          title: const Text(
            'Pomodoro',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PomodoroStatsPage(),
                  ),
                );
              },
              tooltip: 'İstatistikler',
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              onPressed: showSettings,
              tooltip: 'Ayarlar',
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.maxHeight;
              final isCompact = availableHeight < 700;
              
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: isCompact ? 8 : 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: isCompact ? 8 : 12),
                    
                    // Circular Timer with Video Inside
                    _buildCircularTimerWithVideo(timerSize, isDark),
                    
                    SizedBox(height: isCompact ? 12 : 16),
                    
                    // Timer Text Below (Altında)
                    _buildTimerTextBelow(timerSize, isDark, isCompact),
                    
                    SizedBox(height: isCompact ? 12 : 16),
                    
                    // Status Text
                    _buildStatusText(isDark, isCompact),
                    
                    SizedBox(height: isCompact ? 12 : 16),
                    
                    // Control Buttons
                    _buildControlButtons(isDark, isCompact),
                    
                    // Finish Work Button (sadece çalışma sırasında)
                    if (!_isBreakTime && (_isRunning || _isPaused || _currentWorkStartTime != null))
                      Column(
                        children: [
                          SizedBox(height: isCompact ? 12 : 16),
                          _buildFinishWorkButton(isDark, isCompact),
                        ],
                      ),
                    
                    SizedBox(height: isCompact ? 12 : 16),
                    
                    // Session Records (Mola alındığında veya kayıtlar varsa) - Kompakt
                    if (_isBreakTime || _sessionRecords.isNotEmpty || _currentWorkStartTime != null)
                      _buildSessionRecords(isDark, isCompact),
                  ],
                ),
              );
            },
          ),
        ),
      );
  }

  Widget _buildCircularTimerWithVideo(double size, bool isDark) {
    final progress = _getProgress();
    final isBreak = _isBreakTime;
    final primaryColor = isBreak 
        ? AppColors.gradientGreenStart 
        : AppColors.gradientBlueStart;
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _isRunning && !_isPaused 
            ? 1.0 + (_pulseController.value * 0.02)
            : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Progress Ring
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: isDark 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                
                // Middle Ring
                Container(
                  width: size * 0.85,
                  height: size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
                
                // Video Container (Circular)
                Container(
                  width: size * 0.7,
                  height: size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.black87 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildVideoContent(size * 0.7),
                  ),
                ),
                
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoContent(double size) {
    // Video controller durumunu kontrol et
    final isInitialized = _videoController != null && 
        _videoController!.value.isInitialized;
    final hasError = _videoController != null && 
        _videoController!.value.hasError;
    
    if (_videoAvailable && isInitialized && !hasError) {
      return SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }
    
    // Video yüklenene kadar placeholder
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.primaryBlue.withOpacity(0.3),
            AppColors.primaryBlue.withOpacity(0.1),
          ],
        ),
      ),
      child: Icon(
        Icons.hourglass_empty,
        size: size * 0.4,
        color: AppColors.primaryBlue.withOpacity(0.5),
      ),
    );
  }

  Widget _buildTimerTextBelow(double timerSize, bool isDark, bool isCompact) {
    final isBreak = _isBreakTime;
    final primaryColor = isBreak 
        ? AppColors.gradientGreenStart 
        : AppColors.gradientBlueStart;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatDuration(_remainingTime),
          style: TextStyle(
            color: primaryColor,
            fontSize: isCompact ? 36 : 42,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
            shadows: [
              Shadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Text(
          isBreak ? 'Mola' : 'Çalışma',
          style: TextStyle(
            color: primaryColor.withOpacity(0.8),
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText(bool isDark, bool isCompact) {
    if (!_isRunning && !_isPaused && !_isBreakTime) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Başlamak için butona basın',
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Text(
            'Oturum ${_currentSession + 1}/$_sessionCount',
            style: TextStyle(
              fontSize: isCompact ? 13 : 14,
              color: isDark ? Colors.white60 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Oturum ${_currentSession + 1}/$_sessionCount',
          style: TextStyle(
            fontSize: isCompact ? 15 : 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (_isPaused) ...[
          SizedBox(height: isCompact ? 4 : 6),
          Text(
            'Duraklatıldı',
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }


  Widget _buildControlButtons(bool isDark, bool isCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isRunning || _isPaused) ...[
          _buildIconButton(
            icon: Icons.stop,
            color: Colors.red,
            onPressed: _stopTimer,
            isDark: isDark,
            tooltip: 'Durdur',
            isCompact: isCompact,
          ),
          SizedBox(width: isCompact ? 12 : 16),
        ],
        _buildIconButton(
          icon: _isRunning && !_isPaused ? Icons.pause : Icons.play_arrow,
          color: _isRunning && !_isPaused 
              ? Colors.orange 
              : AppColors.primaryBlue,
          onPressed: _isRunning && !_isPaused ? _pauseTimer : _startTimer,
          isDark: isDark,
          tooltip: _isRunning && !_isPaused ? 'Duraklat' : 'Başlat',
          isPrimary: true,
          isCompact: isCompact,
        ),
        if (_isBreakTime && _isRunning) ...[
          SizedBox(width: isCompact ? 12 : 16),
          _buildIconButton(
            icon: Icons.skip_next,
            color: Colors.grey,
            onPressed: _skipBreak,
            isDark: isDark,
            tooltip: 'Molayı Atla',
            isCompact: isCompact,
          ),
        ],
      ],
    );
  }

  Widget _buildFinishWorkButton(bool isDark, bool isCompact) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _finishWork,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 24,
            vertical: isCompact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gradientGreenStart,
                AppColors.gradientGreenEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.gradientGreenStart.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Çalışmayı Bitir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isDark,
    required String tooltip,
    required bool isCompact,
    bool isPrimary = false,
  }) {
    final size = isCompact 
        ? (isPrimary ? 56.0 : 50.0)
        : (isPrimary ? 64.0 : 56.0);
    final iconSize = isCompact
        ? (isPrimary ? 26.0 : 24.0)
        : (isPrimary ? 28.0 : 26.0);
    
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: isPrimary ? 12.0 : 8.0,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionRecords(bool isDark, bool isCompact) {
    // Aktif çalışma kaydını da göster
    final recordsToShow = List<Map<String, dynamic>>.from(_sessionRecords);
    if (_currentWorkStartTime != null && _currentWorkDuration.inSeconds > 0) {
      recordsToShow.add({
        'type': 'work',
        'startTime': _currentWorkStartTime!,
        'endTime': null, // Henüz bitmedi
        'duration': _currentWorkDuration,
        'isActive': true,
      });
    }
    
    if (recordsToShow.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                color: AppColors.primaryBlue,
                size: isCompact ? 18 : 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Kayıtlar',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 12),
          ...recordsToShow.reversed.take(isCompact ? 3 : 4).map((record) {
            final isWork = record['type'] == 'work';
            final isActive = record['isActive'] == true;
            final startTime = record['startTime'] as DateTime;
            final endTime = record['endTime'] as DateTime?;
            final duration = record['duration'] as Duration;
            
            return Padding(
              padding: EdgeInsets.only(bottom: isCompact ? 8 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: isCompact ? 40 : 45,
                    decoration: BoxDecoration(
                      color: isWork 
                          ? AppColors.primaryBlue 
                          : AppColors.gradientGreenStart,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isWork ? Icons.work : Icons.coffee,
                              size: isCompact ? 14 : 15,
                              color: isWork 
                                  ? AppColors.primaryBlue 
                                  : AppColors.gradientGreenStart,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isWork ? 'Çalışma' : 'Mola',
                                style: TextStyle(
                                  fontSize: isCompact ? 12 : 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Aktif',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: isCompact ? 3 : 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatDateTime(startTime),
                              style: TextStyle(
                                fontSize: isCompact ? 10 : 11,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            if (endTime != null) ...[
                              Text(
                                ' → ${_formatDateTime(endTime)}',
                                style: TextStyle(
                                  fontSize: isCompact ? 10 : 11,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: isCompact ? 2 : 3),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: isWork 
                                ? AppColors.primaryBlue 
                                : AppColors.gradientGreenStart,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
