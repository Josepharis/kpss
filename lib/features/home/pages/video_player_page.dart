import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/models/video.dart';
import '../../../core/services/progress_service.dart';

class VideoPlayerPage extends StatefulWidget {
  final Video video;
  final String topicName;

  const VideoPlayerPage({
    super.key,
    required this.video,
    required this.topicName,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;
  Timer? _hideControlsTimer;
  Timer? _progressSaveTimer;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  final ProgressService _progressService = ProgressService();

  @override
  void initState() {
    super.initState();
    // Allow all orientations initially
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
      );

      _controller!.addListener(_videoListener);
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _totalDuration = _controller!.value.duration;
        });
        
        // Load saved progress and seek to that position
        final savedProgress = await _progressService.getVideoProgress(widget.video.id);
        if (savedProgress != null && savedProgress.inSeconds > 5) {
          // Only resume if saved position is more than 5 seconds
          await _controller!.seekTo(savedProgress);
          print('✅ Resuming video from saved position: ${savedProgress.inMinutes}m');
        }
        
        _startHideControlsTimer();
        _startProgressSaveTimer();
      }
    } catch (e) {
      print('❌ Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video yüklenirken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;
    
    setState(() {
      _isPlaying = _controller!.value.isPlaying;
      _isBuffering = _controller!.value.isBuffering;
      _currentPosition = _controller!.value.position;
      _totalDuration = _controller!.value.duration;
    });
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _startProgressSaveTimer() {
    _progressSaveTimer?.cancel();
    // Save progress every 5 seconds
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_controller != null && _isInitialized && _totalDuration.inSeconds > 0) {
        _saveProgress();
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_controller == null || !_isInitialized) return;
    
    await _progressService.saveVideoProgress(
      videoId: widget.video.id,
      videoTitle: widget.video.title,
      topicId: widget.video.topicId,
      topicName: widget.topicName,
      lessonId: widget.video.lessonId,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
    );
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
    
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _seekForward() {
    if (_controller == null || !_isInitialized) return;
    final newPosition = _currentPosition + const Duration(seconds: 10);
    _controller!.seekTo(newPosition > _totalDuration ? _totalDuration : newPosition);
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _seekBackward() {
    if (_controller == null || !_isInitialized) return;
    final newPosition = _currentPosition - const Duration(seconds: 10);
    _controller!.seekTo(newPosition.isNegative ? Duration.zero : newPosition);
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _changePlaybackSpeed(double speed) {
    if (_controller == null || !_isInitialized) return;
    _controller!.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _showControls = true;
    });
    _startHideControlsTimer();
    
    if (_isFullscreen) {
      // Landscape mode ve tam ekran
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      // Portrait mode - önce tüm orientation'ları aç, sonra portrait'e geç
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Kısa bir gecikme ile portrait'e geç
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _progressSaveTimer?.cancel();
    
    // Save final progress before disposing
    if (_controller != null && _isInitialized) {
      _saveProgress();
    }
    
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    
    // Reset orientation and system UI (async işlem, dispose'dan sonra çalışır)
    _resetOrientation();
    
    super.dispose();
  }

  void _resetOrientation() async {
    // Önce tüm orientation'ları aç, sonra portrait'e geç
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await Future.delayed(const Duration(milliseconds: 100));
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: _isInitialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showControls = !_showControls;
                          });
                          if (_showControls) {
                            _startHideControlsTimer();
                          }
                        },
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
            ),
            
            // Controls Overlay
            if (_showControls && _isInitialized)
              _buildControlsOverlay(isSmallScreen),
            
            // Top Bar
            if (_showControls)
              _buildTopBar(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isSmallScreen) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 8 : 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                      onTap: () async {
                        // Save progress before leaving
                        if (_controller != null && _isInitialized) {
                          await _saveProgress();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('İlerlemeniz kaydediliyor...'),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Wait for message to be visible
                            await Future.delayed(const Duration(milliseconds: 2000));
                          }
                        }
                        if (mounted) {
                          Navigator.of(context).pop(true); // Return true to indicate refresh needed
                        }
                      },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: isSmallScreen ? 16 : 18,
                  ),
                ),
              ),
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.topicName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    widget.video.title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Fullscreen Button (sağ üstte)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleFullscreen,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(bool isSmallScreen) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Bar
            _buildProgressBar(),
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Control Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rewind 10s
                    _buildControlButton(
                      icon: Icons.replay_10,
                      onTap: _seekBackward,
                      isSmallScreen: isSmallScreen,
                    ),
                    
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    
                    // Play/Pause
                    _buildControlButton(
                      icon: _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      onTap: _togglePlayPause,
                      isSmallScreen: isSmallScreen,
                      isPrimary: true,
                    ),
                    
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    
                    // Forward 10s
                    _buildControlButton(
                      icon: Icons.forward_10,
                      onTap: _seekForward,
                      isSmallScreen: isSmallScreen,
                    ),
                  ],
                ),
                
                // Right side controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed Control
                    _buildSpeedButton(isSmallScreen),
                    
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    
                    // Time Display
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: isSmallScreen ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (_controller == null || !_isInitialized) return;
            final tappedPosition = details.localPosition.dx / constraints.maxWidth;
            final newPosition = Duration(
              milliseconds: (tappedPosition * _totalDuration.inMilliseconds).round(),
            );
            _controller!.seekTo(newPosition);
            setState(() {
              _showControls = true;
            });
            _startHideControlsTimer();
          },
          child: Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE74C3C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (_isBuffering)
                  Positioned.fill(
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmallScreen,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFFE74C3C)
                : Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isPrimary ? (isSmallScreen ? 32 : 40) : (isSmallScreen ? 20 : 24),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedButton(bool isSmallScreen) {
    return PopupMenuButton<double>(
      icon: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 6 : 8,
          vertical: isSmallScreen ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      color: Colors.black.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: _changePlaybackSpeed,
      itemBuilder: (context) => [
        _buildSpeedMenuItem(0.5),
        _buildSpeedMenuItem(0.75),
        _buildSpeedMenuItem(1.0),
        _buildSpeedMenuItem(1.25),
        _buildSpeedMenuItem(1.5),
        _buildSpeedMenuItem(2.0),
      ],
    );
  }

  PopupMenuItem<double> _buildSpeedMenuItem(double speed) {
    return PopupMenuItem<double>(
      value: speed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${speed}x',
            style: TextStyle(
              color: _playbackSpeed == speed ? const Color(0xFFE74C3C) : Colors.white,
              fontWeight: _playbackSpeed == speed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (_playbackSpeed == speed)
            Icon(
              Icons.check,
              color: const Color(0xFFE74C3C),
              size: 18,
            ),
        ],
      ),
    );
  }
}

