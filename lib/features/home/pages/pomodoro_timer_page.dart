import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/constants/app_colors.dart';

class PomodoroTimerPage extends StatefulWidget {
  const PomodoroTimerPage({super.key});

  @override
  State<PomodoroTimerPage> createState() => PomodoroTimerPageState();
}

class PomodoroTimerPageState extends State<PomodoroTimerPage>
    with TickerProviderStateMixin {
  // Timer settings
  int _sessionCount = 4;
  int _sessionDuration = 25; // minutes
  int _shortBreakDuration = 5; // minutes
  int _longBreakDuration = 15; // minutes
  bool _useLongBreak = false;

  // Timer state
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isBreakTime = false;
  int _currentSession = 0;
  Duration _remainingTime = const Duration(minutes: 25);
  Timer? _timer;
  late AnimationController _candleController;
  late AnimationController _flameController;
  late AnimationController _smokeController;
  late Animation<double> _candleAnimation;

  @override
  void initState() {
    super.initState();
    _remainingTime = Duration(minutes: _sessionDuration);
    
    _candleController = AnimationController(
      vsync: this,
      duration: Duration(minutes: _sessionDuration),
    );
    
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    
    _smokeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _candleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _candleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _candleController.dispose();
    _flameController.dispose();
    _smokeController.dispose();
    super.dispose();
  }

  void showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsSheet(
        sessionCount: _sessionCount,
        sessionDuration: _sessionDuration,
        shortBreakDuration: _shortBreakDuration,
        longBreakDuration: _longBreakDuration,
        useLongBreak: _useLongBreak,
        onSessionCountChanged: (value) {
          setState(() {
            _sessionCount = value;
          });
        },
        onSessionDurationChanged: (value) {
          setState(() {
            _sessionDuration = value;
            if (!_isRunning) {
              _remainingTime = Duration(minutes: _sessionDuration);
              _candleController.duration = Duration(minutes: _sessionDuration);
            }
          });
        },
        onShortBreakDurationChanged: (value) {
          setState(() {
            _shortBreakDuration = value;
          });
        },
        onLongBreakDurationChanged: (value) {
          setState(() {
            _longBreakDuration = value;
          });
        },
        onUseLongBreakChanged: (value) {
          setState(() {
            _useLongBreak = value;
          });
        },
      ),
    );
  }

  void _startTimer() {
    if (_isPaused) {
      _resumeTimer();
      return;
    }

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _candleController.forward();
    _flameController.repeat();
    _smokeController.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
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
    _candleController.stop();
    _flameController.stop();
    _smokeController.stop();
  }

  void _resumeTimer() {
    setState(() {
      _isPaused = false;
    });
    _candleController.forward();
    _flameController.repeat();
    _smokeController.repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        });
      } else {
        _completeSession();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _isBreakTime = false;
      _currentSession = 0;
      _remainingTime = Duration(minutes: _sessionDuration);
    });
    _candleController.reset();
    _flameController.stop();
    _smokeController.stop();
  }

  void _completeSession() {
    _timer?.cancel();
    _candleController.reset();
    _flameController.stop();
    _smokeController.stop();

    if (!_isBreakTime) {
      // Work session completed
      setState(() {
        _currentSession++;
        _isBreakTime = true;
      });

      // Determine break duration
      int breakDuration = _currentSession % 4 == 0 && _useLongBreak
          ? _longBreakDuration
          : _shortBreakDuration;

      setState(() {
        _remainingTime = Duration(minutes: breakDuration);
      });

      _candleController.duration = Duration(minutes: breakDuration);
      _candleController.forward();

      // Show break notification
      _showBreakDialog(breakDuration);
    } else {
      // Break completed
      if (_currentSession < _sessionCount) {
        setState(() {
          _isBreakTime = false;
          _remainingTime = Duration(minutes: _sessionDuration);
        });
        _candleController.duration = Duration(minutes: _sessionDuration);
        _candleController.reset();

        // Show work session notification
        _showWorkDialog();
      } else {
        // All sessions completed
        _showCompletionDialog();
        _stopTimer();
      }
    }
  }

  void _showBreakDialog(int duration) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Mola Zamanı! 🎉'),
        content: Text('${duration} dakikalık molaya çıkabilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
            child: const Text('Molaya Başla'),
          ),
        ],
      ),
    );
  }

  void _showWorkDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Çalışma Zamanı! 📚'),
        content: Text('Yeni bir çalışma oturumuna başlayabilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startTimer();
            },
            child: const Text('Başla'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tebrikler! 🎊'),
        content: Text('Tüm $_sessionCount oturumu tamamladınız!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Tamam'),
          ),
        ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Timer Display Section
          _buildTimerSection(),

          const SizedBox(height: 40),

          // Candle Animation
          _buildCandleAnimation(),

          const SizedBox(height: 40),

          // Control Buttons
          _buildControlButtons(),

          const SizedBox(height: 20),

          // Session Progress
          _buildSessionProgress(),
        ],
      ),
    );
  }

  Widget _buildTimerSection() {
    final progress = _getProgress();
    final isBreak = _isBreakTime;

    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isBreak
              ? [AppColors.gradientGreenStart, AppColors.gradientGreenEnd]
              : [AppColors.gradientBlueStart, AppColors.gradientBlueEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: (isBreak
                    ? AppColors.gradientGreenStart
                    : AppColors.gradientBlueStart)
                .withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress Circle
          SizedBox(
            width: 280,
            height: 280,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.8),
              ),
            ),
          ),
          // Timer Text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isBreak ? 'Mola' : 'Çalışma',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_remainingTime),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (_isRunning || _isPaused) ...[
                const SizedBox(height: 8),
                Text(
                  'Oturum ${_currentSession + 1}/$_sessionCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandleAnimation() {
    return AnimatedBuilder(
      animation: Listenable.merge([_candleAnimation, _flameController, _smokeController]),
      builder: (context, child) {
        final progress = _candleAnimation.value;
        return SizedBox(
          height: 350,
          width: double.infinity,
          child: Center(
            child: _buildHourglass(progress),
          ),
        );
      },
    );
  }
  
  Widget _buildHourglass(double progress) {
    // Progress'e göre kum seviyeleri
    const topBottomHeight = 120.0;
    final topSandLevel = topBottomHeight * (1 - progress); // Üstteki kum azalıyor
    final bottomSandLevel = topBottomHeight * progress; // Alttaki kum artıyor
    
    return CustomPaint(
      size: const Size(120.0, 300.0),
      painter: HourglassPainter(
        progress: progress,
        topSandLevel: topSandLevel,
        bottomSandLevel: bottomSandLevel,
        animation: _flameController.value,
        isRunning: _isRunning && !_isPaused,
        isBreak: _isBreakTime,
      ),
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isRunning || _isPaused) ...[
          // Stop Button
          ElevatedButton.icon(
            onPressed: _stopTimer,
            icon: const Icon(Icons.stop),
            label: const Text('Durdur'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.progressRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
        // Play/Pause Button
        ElevatedButton.icon(
          onPressed: _isRunning && !_isPaused ? _pauseTimer : _startTimer,
          icon: Icon(_isRunning && !_isPaused ? Icons.pause : Icons.play_arrow),
          label: Text(_isRunning && !_isPaused ? 'Duraklat' : 'Başlat'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRunning && !_isPaused
                ? AppColors.progressYellow
                : AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionProgress() {
    if (!_isRunning && !_isPaused) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'İlerleme',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(_sessionCount, (index) {
                final isCompleted = index < _currentSession;
                final isCurrent = index == _currentSession;
                final isBreak = isCurrent && _isBreakTime;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.gradientGreenEnd
                          : isCurrent
                              ? (isBreak
                                  ? AppColors.gradientGreenStart
                                  : AppColors.primaryBlue)
                              : AppColors.progressGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentSession}/$_sessionCount oturum tamamlandı',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Settings Bottom Sheet
class _SettingsSheet extends StatefulWidget {
  final int sessionCount;
  final int sessionDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final bool useLongBreak;
  final ValueChanged<int> onSessionCountChanged;
  final ValueChanged<int> onSessionDurationChanged;
  final ValueChanged<int> onShortBreakDurationChanged;
  final ValueChanged<int> onLongBreakDurationChanged;
  final ValueChanged<bool> onUseLongBreakChanged;

  const _SettingsSheet({
    required this.sessionCount,
    required this.sessionDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.useLongBreak,
    required this.onSessionCountChanged,
    required this.onSessionDurationChanged,
    required this.onShortBreakDurationChanged,
    required this.onLongBreakDurationChanged,
    required this.onUseLongBreakChanged,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                Text(
                  'Pomodoro Ayarları',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Session Count
                _buildSettingItem(
                  title: 'Oturum Sayısı',
                  value: '$_sessionCount',
                  child: Slider(
                    value: _sessionCount.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: _sessionCount.toString(),
                    onChanged: (value) {
                      setState(() {
                        _sessionCount = value.toInt();
                      });
                      widget.onSessionCountChanged(_sessionCount);
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Session Duration
                _buildSettingItem(
                  title: 'Oturum Süresi',
                  value: '$_sessionDuration dakika',
                  child: Slider(
                    value: _sessionDuration.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '$_sessionDuration dk',
                    onChanged: (value) {
                      setState(() {
                        _sessionDuration = value.toInt();
                      });
                      widget.onSessionDurationChanged(_sessionDuration);
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Short Break Duration
                _buildSettingItem(
                  title: 'Kısa Mola',
                  value: '$_shortBreakDuration dakika',
                  child: Slider(
                    value: _shortBreakDuration.toDouble(),
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: '$_shortBreakDuration dk',
                    onChanged: (value) {
                      setState(() {
                        _shortBreakDuration = value.toInt();
                      });
                      widget.onShortBreakDurationChanged(_shortBreakDuration);
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Long Break Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Uzun Mola Kullan',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Switch(
                      value: _useLongBreak,
                      onChanged: (value) {
                        setState(() {
                          _useLongBreak = value;
                        });
                        widget.onUseLongBreakChanged(_useLongBreak);
                      },
                    ),
                  ],
                ),

                if (_useLongBreak) ...[
                  const SizedBox(height: 20),
                  _buildSettingItem(
                    title: 'Uzun Mola',
                    value: '$_longBreakDuration dakika',
                    child: Slider(
                      value: _longBreakDuration.toDouble(),
                      min: 10,
                      max: 30,
                      divisions: 20,
                      label: '$_longBreakDuration dk',
                      onChanged: (value) {
                        setState(() {
                          _longBreakDuration = value.toInt();
                        });
                        widget.onLongBreakDurationChanged(_longBreakDuration);
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String value,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// Hourglass Painter - Kum Saati
class HourglassPainter extends CustomPainter {
  final double progress;
  final double topSandLevel;
  final double bottomSandLevel;
  final double animation;
  final bool isRunning;
  final bool isBreak;

  HourglassPainter({
    required this.progress,
    required this.topSandLevel,
    required this.bottomSandLevel,
    required this.animation,
    required this.isRunning,
    required this.isBreak,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final hourglassWidth = 120.0;
    final topBottomHeight = 120.0;
    final middleHeight = 60.0;
    final neckWidth = 8.0;
    
    // Kum saati şekli
    final topY = 0.0;
    final middleY = topBottomHeight;
    final bottomY = topBottomHeight + middleHeight;
    
    // Üst kısım (üçgen/konik)
    final topPath = Path();
    topPath.moveTo(centerX - hourglassWidth / 2, topY);
    topPath.lineTo(centerX + hourglassWidth / 2, topY);
    topPath.lineTo(centerX + neckWidth / 2, middleY);
    topPath.lineTo(centerX - neckWidth / 2, middleY);
    topPath.close();
    
    // Alt kısım (ters üçgen/konik)
    final bottomPath = Path();
    bottomPath.moveTo(centerX - neckWidth / 2, bottomY);
    bottomPath.lineTo(centerX + neckWidth / 2, bottomY);
    bottomPath.lineTo(centerX + hourglassWidth / 2, bottomY + topBottomHeight);
    bottomPath.lineTo(centerX - hourglassWidth / 2, bottomY + topBottomHeight);
    bottomPath.close();
    
    // Cam çerçeve
    final glassPaint = Paint()
      ..color = Colors.grey[300]!.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawPath(topPath, glassPaint);
    canvas.drawPath(bottomPath, glassPaint);
    
    // Üstteki kum
    if (topSandLevel > 0) {
      final topSandPath = Path();
      topSandPath.moveTo(centerX - hourglassWidth / 2, topY);
      topSandPath.lineTo(centerX + hourglassWidth / 2, topY);
      
      // Kum seviyesine göre üst kısmı çiz
      final sandTopY = topY + (topBottomHeight - topSandLevel);
      final sandWidth = hourglassWidth - ((topBottomHeight - topSandLevel) / topBottomHeight) * (hourglassWidth - neckWidth);
      
      topSandPath.lineTo(centerX + sandWidth / 2, sandTopY);
      topSandPath.lineTo(centerX - sandWidth / 2, sandTopY);
      topSandPath.close();
      
      final sandGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isBreak
            ? [
                const Color(0xFF81C784),
                const Color(0xFF66BB6A),
                const Color(0xFF4CAF50),
              ]
            : [
                const Color(0xFFFFD54F),
                const Color(0xFFFFB74D),
                const Color(0xFFFF9800),
              ],
      );
      
      final topSandPaint = Paint()
        ..shader = sandGradient.createShader(
          Rect.fromLTWH(centerX - hourglassWidth / 2, topY, hourglassWidth, topBottomHeight),
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(topSandPath, topSandPaint);
    }
    
    // Alttaki kum
    if (bottomSandLevel > 0) {
      final bottomSandPath = Path();
      final sandBottomY = bottomY + topBottomHeight - bottomSandLevel;
      final sandWidth = neckWidth + (bottomSandLevel / topBottomHeight) * (hourglassWidth - neckWidth);
      
      bottomSandPath.moveTo(centerX - sandWidth / 2, sandBottomY);
      bottomSandPath.lineTo(centerX + sandWidth / 2, sandBottomY);
      bottomSandPath.lineTo(centerX + hourglassWidth / 2, bottomY + topBottomHeight);
      bottomSandPath.lineTo(centerX - hourglassWidth / 2, bottomY + topBottomHeight);
      bottomSandPath.close();
      
      final sandGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isBreak
            ? [
                const Color(0xFF81C784),
                const Color(0xFF66BB6A),
                const Color(0xFF4CAF50),
              ]
            : [
                const Color(0xFFFFD54F),
                const Color(0xFFFFB74D),
                const Color(0xFFFF9800),
              ],
      );
      
      final bottomSandPaint = Paint()
        ..shader = sandGradient.createShader(
          Rect.fromLTWH(centerX - hourglassWidth / 2, bottomY, hourglassWidth, topBottomHeight),
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawPath(bottomSandPath, bottomSandPaint);
    }
    
    // Kum akışı animasyonu
    if (isRunning && topSandLevel > 0 && bottomSandLevel < topBottomHeight) {
      _drawSandFlow(canvas, centerX, middleY, animation, isBreak);
    }
  }
  
  void _drawSandFlow(Canvas canvas, double centerX, double middleY, double anim, bool isBreak) {
    final sandColor = isBreak
        ? const Color(0xFF66BB6A)
        : const Color(0xFFFFB74D);
    
    // Akış çizgisi
    final flowPaint = Paint()
      ..color = sandColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    
    // Animasyonlu kum parçacıkları
    final particlePaint = Paint()
      ..color = sandColor
      ..style = PaintingStyle.fill;
    
    // Akış çizgisi
    final flowPath = Path();
    flowPath.moveTo(centerX - 4, middleY - 30);
    flowPath.quadraticBezierTo(centerX, middleY, centerX + 4, middleY + 30);
    
    canvas.drawPath(flowPath, flowPaint);
    
    // Kum parçacıkları
    for (int i = 0; i < 8; i++) {
      final particleY = middleY - 25 + (anim * 50) + (i * 7);
      final particleX = centerX + math.sin(anim * math.pi * 2 + i) * 2;
      final size = 3 + math.sin(anim * math.pi * 4 + i) * 1;
      
      if (particleY > middleY - 30 && particleY < middleY + 30) {
        canvas.drawCircle(
          Offset(particleX, particleY),
          size,
          particlePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(HourglassPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.topSandLevel != topSandLevel ||
        oldDelegate.bottomSandLevel != bottomSandLevel ||
        oldDelegate.animation != animation ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.isBreak != isBreak;
  }
}

// Eski Candle Painter - artık kullanılmıyor
class ProfessionalCandlePainter extends CustomPainter {
  final double progress;
  final double flameAnimation;
  final double smokeAnimation;
  final bool isRunning;
  final bool isBreak;

  ProfessionalCandlePainter({
    required this.progress,
    required this.flameAnimation,
    required this.smokeAnimation,
    required this.isRunning,
    required this.isBreak,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height - 10;
    
    // Calculate candle dimensions - make it bigger and more visible
    final maxCandleHeight = 260.0;
    final minCandleHeight = 60.0;
    final candleHeight = maxCandleHeight - (maxCandleHeight - minCandleHeight) * progress;
    final candleWidth = 70.0; // Wider candle
    final holderWidth = candleWidth + 40;
    final holderHeight = 45.0;
    final wickHeight = 32.0 * (1 - progress * 0.7);
    
    final candleTop = baseY - holderHeight - candleHeight;
    final candleBottom = baseY - holderHeight;

    // Draw candle holder/base - more prominent
    final holderRect = Rect.fromCenter(
      center: Offset(centerX, baseY - holderHeight / 2),
      width: holderWidth,
      height: holderHeight,
    );
    
    final holderGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF6D4C41),
        const Color(0xFF4E342E),
        const Color(0xFF3E2723),
        const Color(0xFF1B0000),
      ],
    );
    
    final holderPaint = Paint()
      ..shader = holderGradient.createShader(holderRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(holderRect, const Radius.circular(22)),
      holderPaint,
    );
    
    // Draw holder shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        holderRect.translate(0, 3),
        const Radius.circular(22),
      ),
      shadowPaint,
    );
    
    // Draw holder highlight
    final highlightRect = Rect.fromLTWH(
      centerX - holderWidth / 2 + 8,
      baseY - holderHeight + 8,
      holderWidth - 16,
      18,
    );
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.25),
          Colors.transparent,
        ],
      ).createShader(highlightRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(18)),
      highlightPaint,
    );

    // Draw candle body - much more visible and realistic
    final candleRect = Rect.fromLTWH(
      centerX - candleWidth / 2,
      candleTop,
      candleWidth,
      candleHeight,
    );
    
    // Main candle body with strong gradient
    final candleGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      colors: [
        const Color(0xFFFFFFFF), // Bright white top
        const Color(0xFFFFF9E6), // Very light cream
        const Color(0xFFFFF0D6), // Light cream
        const Color(0xFFFFE5B4), // Cream
        const Color(0xFFFFD89C), // Warm beige
      ],
    );
    
    final candlePaint = Paint()
      ..shader = candleGradient.createShader(candleRect)
      ..style = PaintingStyle.fill;
    
    // Draw candle with rounded top
    final candlePath = Path();
    candlePath.addRRect(RRect.fromRectAndCorners(
      candleRect,
      topLeft: Radius.circular(candleWidth / 2),
      topRight: Radius.circular(candleWidth / 2),
      bottomLeft: const Radius.circular(15),
      bottomRight: const Radius.circular(15),
    ));
    
    canvas.drawPath(candlePath, candlePaint);
    
    // Add candle shadow for depth
    final candleShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(
      Path()..addRRect(RRect.fromRectAndCorners(
        candleRect.translate(2, 2),
        topLeft: Radius.circular(candleWidth / 2),
        topRight: Radius.circular(candleWidth / 2),
        bottomLeft: const Radius.circular(15),
        bottomRight: const Radius.circular(15),
      )),
      candleShadowPaint,
    );
    
    // Add vertical texture lines for realism
    final texturePaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    for (int i = 0; i < 6; i++) {
      final y = candleTop + (candleHeight / 7) * (i + 1);
      canvas.drawLine(
        Offset(centerX - candleWidth / 2 + 10, y),
        Offset(centerX + candleWidth / 2 - 10, y),
        texturePaint,
      );
    }
    
    // Add side highlights for 3D effect
    final sideHighlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withOpacity(0.3),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(candleRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(candlePath, sideHighlightPaint);
    
    // Draw melted wax drips - more visible
    if (progress > 0.08) {
      final dripProgress = (progress - 0.08) / 0.92;
      final dripPaint = Paint()
        ..color = const Color(0xFFFFD89C).withOpacity(0.9)
        ..style = PaintingStyle.fill;
      
      // Left side drips - more prominent
      for (int i = 0; i < 3; i++) {
        final dripX = centerX - candleWidth / 2 - 4;
        final dripY = candleBottom - (dripProgress * 40) - (i * 15);
        final dripWidth = 10 + (i * 3);
        final dripHeight = 18 + (i * 4);
        
        final dripPath = Path();
        dripPath.moveTo(dripX, dripY);
        dripPath.cubicTo(
          dripX - 3, dripY + dripHeight * 0.3,
          dripX - 2, dripY + dripHeight * 0.7,
          dripX, dripY + dripHeight,
        );
        dripPath.cubicTo(
          dripX + dripWidth * 0.6, dripY + dripHeight * 0.8,
          dripX + dripWidth, dripY + dripHeight * 0.4,
          dripX + dripWidth, dripY,
        );
        dripPath.close();
        
        canvas.drawPath(dripPath, dripPaint);
        
        // Add drip shadow
        final dripShadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawPath(
          dripPath.shift(const Offset(1, 1)),
          dripShadowPaint,
        );
      }
      
      // Right side drips
      for (int i = 0; i < 3; i++) {
        final dripX = centerX + candleWidth / 2 - 6;
        final dripY = candleBottom - (dripProgress * 40) - (i * 15);
        final dripWidth = 10 + (i * 3);
        final dripHeight = 18 + (i * 4);
        
        final dripPath = Path();
        dripPath.moveTo(dripX, dripY);
        dripPath.cubicTo(
          dripX + 3, dripY + dripHeight * 0.3,
          dripX + 2, dripY + dripHeight * 0.7,
          dripX, dripY + dripHeight,
        );
        dripPath.cubicTo(
          dripX - dripWidth * 0.6, dripY + dripHeight * 0.8,
          dripX - dripWidth, dripY + dripHeight * 0.4,
          dripX - dripWidth, dripY,
        );
        dripPath.close();
        
        canvas.drawPath(dripPath, dripPaint);
        
        // Add drip shadow
        final dripShadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..style = PaintingStyle.fill;
        canvas.drawPath(
          dripPath.shift(const Offset(-1, 1)),
          dripShadowPaint,
        );
      }
    }
    
    // Draw wick - more visible
    if (progress < 0.98) {
      final wickRect = Rect.fromLTWH(
        centerX - 3,
        candleTop - wickHeight,
        6,
        wickHeight,
      );
      
      final wickPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF616161),
            const Color(0xFF424242),
            const Color(0xFF212121),
          ],
        ).createShader(wickRect)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(wickRect, const Radius.circular(3)),
        wickPaint,
      );
      
      // Add wick highlight
      final wickHighlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - 2, candleTop - wickHeight, 4, wickHeight * 0.3),
          const Radius.circular(2),
        ),
        wickHighlightPaint,
      );
    }
    
    // Draw realistic flame
    if (isRunning && progress < 0.98) {
      _drawRealisticFlame(
        canvas,
        centerX,
        candleTop - wickHeight,
        flameAnimation,
        isBreak,
      );
      
      // Draw smoke
      _drawSmoke(canvas, centerX, candleTop - wickHeight - 55, smokeAnimation);
    }
  }
  
  void _drawRealisticFlame(Canvas canvas, double centerX, double baseY, double anim, bool isBreak) {
    final time = anim * 2 * math.pi;
    final sway = math.sin(time) * 3.5;
    final flicker = math.cos(time * 1.4) * 3;
    final flicker2 = math.sin(time * 0.9) * 2;
    
    // More vibrant flame colors
    final outerColor = isBreak
        ? const Color(0xFF81C784).withOpacity(0.5)
        : const Color(0xFFFF9800).withOpacity(0.55);
    final middleColor = isBreak
        ? const Color(0xFF66BB6A).withOpacity(0.75)
        : const Color(0xFFFF6F00).withOpacity(0.8);
    final innerColor = isBreak
        ? const Color(0xFF4CAF50).withOpacity(0.95)
        : const Color(0xFFFFC107).withOpacity(1.0);
    final coreColor = isBreak
        ? const Color(0xFF2E7D32)
        : const Color(0xFFFFEB3B);
    
    // Outer flame - larger and more visible
    final outerPath = Path();
    outerPath.moveTo(centerX - 16 + sway * 1.2, baseY);
    outerPath.cubicTo(
      centerX - 13 + sway, baseY - 25 + flicker,
      centerX - 9 + sway * 0.7, baseY - 50 + flicker * 0.7,
      centerX - 4 + sway * 0.5, baseY - 65 + flicker * 0.5,
    );
    outerPath.cubicTo(
      centerX, baseY - 72 + flicker2,
      centerX + 4 - sway * 0.5, baseY - 65 - flicker * 0.5,
      centerX + 9 - sway * 0.7, baseY - 50 - flicker * 0.7,
    );
    outerPath.cubicTo(
      centerX + 13 - sway, baseY - 25 - flicker,
      centerX + 16 - sway * 1.2, baseY,
      centerX, baseY,
    );
    outerPath.close();
    
    final outerPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(outerPath, outerPaint);
    
    // Middle flame - more prominent
    final middlePath = Path();
    middlePath.moveTo(centerX - 10 + sway * 0.8, baseY);
    middlePath.cubicTo(
      centerX - 8 + sway * 0.7, baseY - 20 + flicker * 0.8,
      centerX - 5 + sway * 0.5, baseY - 40 + flicker * 0.6,
      centerX - 2.5 + sway * 0.4, baseY - 52 + flicker * 0.4,
    );
    middlePath.cubicTo(
      centerX, baseY - 58 + flicker2 * 0.9,
      centerX + 2.5 - sway * 0.4, baseY - 52 - flicker * 0.4,
      centerX + 5 - sway * 0.5, baseY - 40 - flicker * 0.6,
    );
    middlePath.cubicTo(
      centerX + 8 - sway * 0.7, baseY - 20 - flicker * 0.8,
      centerX + 10 - sway * 0.8, baseY,
      centerX, baseY,
    );
    middlePath.close();
    
    final middlePaint = Paint()
      ..color = middleColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(middlePath, middlePaint);
    
    // Inner flame - bright and clear
    final innerPath = Path();
    innerPath.moveTo(centerX - 6 + sway * 0.5, baseY);
    innerPath.cubicTo(
      centerX - 5 + sway * 0.4, baseY - 15 + flicker * 0.6,
      centerX - 3 + sway * 0.3, baseY - 30 + flicker * 0.4,
      centerX - 1.5 + sway * 0.2, baseY - 42 + flicker * 0.3,
    );
    innerPath.cubicTo(
      centerX, baseY - 48 + flicker2 * 0.7,
      centerX + 1.5 - sway * 0.2, baseY - 42 - flicker * 0.3,
      centerX + 3 - sway * 0.3, baseY - 30 - flicker * 0.4,
    );
    innerPath.cubicTo(
      centerX + 5 - sway * 0.4, baseY - 15 - flicker * 0.6,
      centerX + 6 - sway * 0.5, baseY,
      centerX, baseY,
    );
    innerPath.close();
    
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);
    
    // Core - brightest and most visible part
    final corePath = Path();
    corePath.moveTo(centerX - 3, baseY);
    corePath.cubicTo(
      centerX - 2.5, baseY - 10 + flicker * 0.4,
      centerX - 2, baseY - 22 + flicker * 0.3,
      centerX - 1, baseY - 32 + flicker2 * 0.5,
    );
    corePath.cubicTo(
      centerX, baseY - 36 + flicker2 * 0.6,
      centerX + 1, baseY - 32 - flicker2 * 0.5,
      centerX + 2, baseY - 22 - flicker * 0.3,
    );
    corePath.cubicTo(
      centerX + 2.5, baseY - 10 - flicker * 0.4,
      centerX + 3, baseY,
      centerX, baseY,
    );
    corePath.close();
    
    final corePaint = Paint()
      ..color = coreColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(corePath, corePaint);
    
    // Add strong glow effect around flame
    final glowPaint = Paint()
      ..color = (isBreak ? const Color(0xFF4CAF50) : const Color(0xFFFFC107))
          .withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.drawPath(innerPath, glowPaint);
    
    // Add secondary glow for more realism
    final glowPaint2 = Paint()
      ..color = (isBreak ? const Color(0xFF66BB6A) : const Color(0xFFFF9800))
          .withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    
    canvas.drawPath(middlePath, glowPaint2);
  }
  
  void _drawSmoke(Canvas canvas, double centerX, double baseY, double anim) {
    final smokePaint = Paint()
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 10; i++) {
      final offset = anim * 2 * math.pi + (i * 0.7);
      final x = centerX + math.sin(offset) * (10 + i * 3);
      final y = baseY - (i * 14) - (anim * 25);
      final size = 6 - (i * 0.4);
      final opacity = (1.0 - (i / 10.0)) * 0.4;
      
      smokePaint.color = Colors.grey[500]!.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), size, smokePaint);
      
      // Add blur effect to smoke
      final blurPaint = Paint()
        ..color = Colors.grey[400]!.withOpacity(opacity * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), size * 1.2, blurPaint);
    }
  }

  @override
  bool shouldRepaint(ProfessionalCandlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.flameAnimation != flameAnimation ||
        oldDelegate.smokeAnimation != smokeAnimation ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.isBreak != isBreak;
  }
}
