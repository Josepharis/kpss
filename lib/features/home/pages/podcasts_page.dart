import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/podcast.dart';
import '../../../core/services/audio_service.dart';

class PodcastsPage extends StatefulWidget {
  final String topicName;
  final int podcastCount;

  const PodcastsPage({
    super.key,
    required this.topicName,
    required this.podcastCount,
  });

  @override
  State<PodcastsPage> createState() => _PodcastsPageState();
}

class _PodcastsPageState extends State<PodcastsPage>
    with TickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService();
  bool _isPlaying = false;
  bool _ignoreStreamUpdate = false;
  double _playbackSpeed = 1.0;
  Duration _currentPosition = Duration.zero;
  Duration? _totalDuration;
  int _selectedPodcastIndex = 0;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    
    // Listen to position updates
    _positionSubscription = _audioService.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // Listen to duration updates
    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // Listen to playing state
    _playingSubscription = _audioService.playingStream.listen((playing) {
      if (mounted) {
        if (!_ignoreStreamUpdate) {
          setState(() {
            _isPlaying = playing;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    // Don't dispose audio service here - it should persist for background playback
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    // Optimistic update - immediately update UI
    final wasPlaying = _isPlaying;
    setState(() {
      _isPlaying = !_isPlaying;
    });
    _ignoreStreamUpdate = true;
    
    try {
      if (wasPlaying) {
        await _audioService.pause();
      } else {
        if (_currentPosition == Duration.zero || _audioService.processingState == ProcessingState.completed) {
          await _loadAndPlayCurrentPodcast();
        } else {
          await _audioService.resume();
        }
      }
      // Reset flag after operation completes
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _ignoreStreamUpdate = false;
          });
        }
      });
    } catch (e) {
      // Revert on error
      setState(() {
        _isPlaying = wasPlaying;
        _ignoreStreamUpdate = false;
      });
    }
  }

  Future<void> _loadAndPlayCurrentPodcast() async {
    final podcasts = _getPodcasts();
    final currentPodcast = podcasts[_selectedPodcastIndex];
    
    // Use a mock URL for now - replace with actual podcast URL
    final audioUrl = currentPodcast.audioUrl.isNotEmpty 
        ? currentPodcast.audioUrl 
        : 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3'; // Mock URL
    
    try {
      // Calculate duration from podcast durationMinutes
      final duration = Duration(minutes: currentPodcast.durationMinutes);
      
      await _audioService.play(
        audioUrl,
        title: currentPodcast.title,
        artist: widget.topicName,
        duration: duration,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Podcast yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reset() async {
    await _audioService.stop();
    await _audioService.seek(Duration.zero);
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    }
  }

  Future<void> _selectPodcast(int index) async {
    if (_selectedPodcastIndex == index) return;
    
    await _audioService.stop();
    setState(() {
      _selectedPodcastIndex = index;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = null;
    });
  }

  Future<void> _seekTo(Duration position) async {
    await _audioService.seek(position);
  }

  Future<void> _changeSpeed(double speed) async {
    await _audioService.setSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final secs = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  List<Podcast> _getPodcasts() {
    return List.generate(
      widget.podcastCount,
      (index) => Podcast(
        id: '${index + 1}',
        title: '${widget.topicName} - Bölüm ${index + 1}',
        description: 'Bu konu hakkında detaylı bilgiler ve açıklamalar',
        audioUrl: '',
        durationMinutes: 15 + (index * 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isTablet = screenWidth > 600;
        final isSmallScreen = screenHeight < 700;
        final isVerySmallScreen = screenWidth < 360;

        final podcasts = _getPodcasts();
        final currentPodcast = podcasts[_selectedPodcastIndex];

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          extendBodyBehindAppBar: false,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isSmallScreen ? 80 : 90),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gradientPurpleStart,
                    AppColors.gradientPurpleEnd,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gradientPurpleStart.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Watermark
                    Positioned(
                      top: -10,
                      right: -10,
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          'PODCAST',
                          style: TextStyle(
                            fontSize: isVerySmallScreen ? 40 : 50,
                            fontWeight: FontWeight.w900,
                            color: Colors.white.withValues(alpha: 0.08),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 14,
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      child: Row(
                        children: [
                          // Back button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 10 : 12),
                          // Title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Podcastler',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 11,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  widget.topicName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
          body: Column(
            children: [
              // Premium Player Card
              Container(
                margin: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 12,
                  isSmallScreen ? 10 : 12,
                  isTablet ? 20 : 12,
                  isSmallScreen ? 10 : 12,
                ),
                constraints: BoxConstraints(
                  maxHeight: isSmallScreen ? 280 : 320,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gradientPurpleStart,
                      AppColors.gradientPurpleEnd,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gradientPurpleStart.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Background Pattern
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.topRight,
                              radius: 1.5,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Decorative circles
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Podcast Title
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentPodcast.title,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 15 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: isSmallScreen ? 12 : 14,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '${currentPodcast.durationMinutes} dk',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 11 : 12,
                                                color: Colors.white.withValues(alpha: 0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 8 : 10),
                                // Waveform visualization
                                AnimatedBuilder(
                                  animation: _waveController,
                                  builder: (context, child) {
                                    return SizedBox(
                                      width: isSmallScreen ? 45 : 55,
                                      height: isSmallScreen ? 30 : 38,
                                      child: CustomPaint(
                                        painter: WaveformPainter(
                                          isPlaying: _isPlaying,
                                          animationValue: _waveController.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            // Progress Section
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 8 : 10,
                                          vertical: isSmallScreen ? 3 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _formatTime(_currentPosition),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 8 : 10,
                                          vertical: isSmallScreen ? 3 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _totalDuration != null 
                                              ? _formatTime(_totalDuration!)
                                              : '--:--',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 10),
                                // Custom Progress Bar
                                Container(
                                  height: isSmallScreen ? 5 : 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                  child: Stack(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 100),
                                        width: double.infinity,
                                        child: FractionallySizedBox(
                                          widthFactor: _totalDuration != null && _totalDuration!.inSeconds > 0
                                              ? (_currentPosition.inSeconds / _totalDuration!.inSeconds).clamp(0.0, 1.0)
                                              : 0.0,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white,
                                                  Colors.white.withValues(alpha: 0.8),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withValues(alpha: 0.5),
                                                  blurRadius: 6,
                                                  spreadRadius: 0.5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            // Controls
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isVerySmall = constraints.maxWidth < 320;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Rewind 10s
                                      _buildControlButton(
                                        icon: Icons.replay_10_rounded,
                                        onPressed: () {
                                          final newPosition = Duration(
                                            seconds: math.max(0, _currentPosition.inSeconds - 10),
                                          );
                                          _seekTo(newPosition);
                                        },
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      SizedBox(width: isVerySmall ? 6 : isSmallScreen ? 8 : 10),
                                      // Reset
                                      _buildControlButton(
                                        icon: Icons.restart_alt_rounded,
                                        onPressed: _reset,
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      SizedBox(width: isVerySmall ? 8 : isSmallScreen ? 12 : 16),
                                      // Play/Pause - Main Button
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.white.withValues(
                                                    alpha: _isPlaying ? 0.6 : 0.3,
                                                  ),
                                                  blurRadius: _isPlaying
                                                      ? 15 + (_pulseController.value * 8)
                                                      : 10,
                                                  spreadRadius: _isPlaying
                                                      ? _pulseController.value * 3
                                                      : 0,
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: _togglePlayPause,
                                                borderRadius: BorderRadius.circular(50),
                                                child: Container(
                                                  width: isSmallScreen ? 52 : 60,
                                                  height: isSmallScreen ? 52 : 60,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        AppColors.gradientPurpleStart,
                                                        AppColors.gradientPurpleEnd,
                                                      ],
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    _isPlaying
                                                        ? Icons.pause_rounded
                                                        : Icons.play_arrow_rounded,
                                                    color: Colors.white,
                                                    size: isSmallScreen ? 26 : 30,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(width: isVerySmall ? 8 : isSmallScreen ? 12 : 16),
                                      // Forward 10s
                                      _buildControlButton(
                                        icon: Icons.forward_10_rounded,
                                        onPressed: () {
                                          if (_totalDuration != null) {
                                            final newPosition = Duration(
                                              seconds: math.min(
                                                _totalDuration!.inSeconds,
                                                _currentPosition.inSeconds + 10,
                                              ),
                                            );
                                            _seekTo(newPosition);
                                          }
                                        },
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      SizedBox(width: isVerySmall ? 6 : isSmallScreen ? 8 : 10),
                                      // Speed Control - PopupMenuButton
                                      PopupMenuButton<double>(
                                        initialValue: _playbackSpeed,
                                        onSelected: (value) {
                                          _changeSpeed(value);
                                        },
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        color: Colors.white,
                                        child: Container(
                                          constraints: BoxConstraints(
                                            minWidth: isVerySmall ? 60 : isSmallScreen ? 70 : 80,
                                            maxWidth: isVerySmall ? 70 : isSmallScreen ? 80 : 90,
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isVerySmall ? 5 : isSmallScreen ? 6 : 8,
                                            vertical: isSmallScreen ? 5 : 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.speed_rounded,
                                                color: Colors.white,
                                                size: isVerySmall ? 11 : isSmallScreen ? 12 : 14,
                                              ),
                                              SizedBox(width: isVerySmall ? 2 : 3),
                                              Flexible(
                                                child: Text(
                                                  '${_playbackSpeed}x',
                                                  style: TextStyle(
                                                    fontSize: isVerySmall ? 9 : isSmallScreen ? 10 : 11,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(width: isVerySmall ? 1 : 2),
                                              Icon(
                                                Icons.arrow_drop_down_rounded,
                                                color: Colors.white,
                                                size: isVerySmall ? 12 : isSmallScreen ? 14 : 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                        itemBuilder: (context) {
                                          return [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                                              .map((speed) {
                                            return PopupMenuItem<double>(
                                              value: speed,
                                              child: Row(
                                                children: [
                                                  if (_playbackSpeed == speed)
                                                    Icon(
                                                      Icons.check_rounded,
                                                      color: AppColors.gradientPurpleStart,
                                                      size: 18,
                                                    )
                                                  else
                                                    SizedBox(width: 18),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '${speed}x',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: _playbackSpeed == speed
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: _playbackSpeed == speed
                                                          ? AppColors.gradientPurpleStart
                                                          : AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Podcast List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: isTablet ? 20 : 12,
                    right: isTablet ? 20 : 12,
                    bottom: isSmallScreen ? 12 : 16,
                  ),
                  itemCount: podcasts.length,
                  itemBuilder: (context, index) {
                    final podcast = podcasts[index];
                    final isSelected = index == _selectedPodcastIndex;
                    return GestureDetector(
                      onTap: () => _selectPodcast(index),
                      child: Container(
                        margin: EdgeInsets.only(
                          bottom: isSmallScreen ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.gradientPurpleStart.withValues(alpha: 0.15),
                                    AppColors.gradientPurpleEnd.withValues(alpha: 0.1),
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.gradientPurpleStart.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.gradientPurpleStart.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.08),
                              blurRadius: isSelected ? 12 : 8,
                              offset: Offset(0, isSelected ? 4 : 2),
                              spreadRadius: isSelected ? 1 : 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                          child: Row(
                            children: [
                              // Thumbnail
                              Container(
                                width: isSmallScreen ? 48 : 56,
                                height: isSmallScreen ? 48 : 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.gradientPurpleStart,
                                      AppColors.gradientPurpleEnd,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gradientPurpleStart
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.podcasts_rounded,
                                      color: Colors.white,
                                      size: isSmallScreen ? 24 : 28,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding: EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.gradientPurpleStart,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 10 : 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      podcast.title,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 15,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppColors.gradientPurpleStart
                                            : AppColors.textPrimary,
                                        letterSpacing: 0.1,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: isSmallScreen ? 4 : 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: isSmallScreen ? 12 : 14,
                                          color: isSelected
                                              ? AppColors.gradientPurpleStart
                                              : AppColors.textSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${podcast.durationMinutes} dk',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 11 : 12,
                                              color: isSelected
                                                  ? AppColors.gradientPurpleStart
                                                  : AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 10),
                              // Play Icon
                              Container(
                                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.gradientPurpleStart
                                      : AppColors.gradientPurpleStart
                                          .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSelected
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.gradientPurpleStart,
                                  size: isSmallScreen ? 18 : 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isSmallScreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen ? 18 : 20,
          ),
        ),
      ),
    );
  }
}

// Waveform Painter
class WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final double animationValue;

  WaveformPainter({
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final barWidth = 2.5;
    final barSpacing = 3.5;
    final maxHeight = size.height;
    final minHeight = maxHeight * 0.3;

    final barCount = ((size.width - barSpacing) / (barWidth + barSpacing)).floor();

    for (int i = 0; i < barCount; i++) {
      final normalizedIndex = i / barCount;
      double height;

      if (isPlaying) {
        final wave = math.sin((normalizedIndex * 2 * math.pi) +
            (animationValue * 2 * math.pi));
        height = minHeight + (maxHeight - minHeight) * ((wave + 1) / 2);
      } else {
        height = minHeight + (maxHeight - minHeight) * (1 - normalizedIndex * 0.3);
      }

      final x = i * (barWidth + barSpacing);
      final rect = Rect.fromLTWH(
        x,
        (size.height - height) / 2,
        barWidth,
        height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}
