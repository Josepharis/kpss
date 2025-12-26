import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Audio player service with native media notification
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  final MethodChannel _channel = const MethodChannel('com.example.kpss_ags_2026/media');
  bool _isInitialized = false;
  String? _currentTitle;
  String? _currentArtist;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  Timer? _updateTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Listen to media actions from notification
    _channel.setMethodCallHandler((call) async {
      print('📱 Received native media action: ${call.method} - ${call.arguments}');
      switch (call.method) {
        case 'mediaAction':
          final action = call.arguments as String;
          print('🎮 Media action: $action');
          switch (action) {
            case 'PLAY_PAUSE':
              if (_player.playing) {
                await pause();
              } else {
                await resume();
              }
              break;
            case 'STOP':
              print('🛑 Stop requested from native');
              await stop();
              break;
            case 'NEXT':
              print('⏭️ Next requested from native');
              // Implement next logic
              break;
            case 'PREVIOUS':
              print('⏮️ Previous requested from native');
              // Seek to beginning
              await seek(Duration.zero);
              break;
          }
          break;
        case 'seek':
          final positionMillis = call.arguments as int;
          print('⏩ Seek requested from native: ${_formatDuration(Duration(milliseconds: positionMillis))}');
          await seek(Duration(milliseconds: positionMillis));
          break;
      }
    });
    
    // Listen to position and playing state to update notification
    _playingSubscription = _player.playingStream.listen((playing) {
      _updateNotification();
    });
    
    // Listen to duration changes
    _durationSubscription = _player.durationStream.listen((duration) {
      _updateNotification();
    });
    
    // Update notification periodically when playing (every second for smooth updates)
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTitle != null) {
        _updateNotification();
      }
    });
    
    _isInitialized = true;
    print('✅ Audio service initialized with native notification');
  }

  Future<void> _updateNotification() async {
    if (_currentTitle == null) return;
    
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': _currentTitle ?? 'Podcast',
        'artist': _currentArtist ?? 'KPSS & AGS 2026',
        'isPlaying': _player.playing,
        'position': _player.position.inMilliseconds,
        'duration': (_player.duration?.inMilliseconds ?? 0),
      });
      // Log only occasionally to avoid spam (every 5 seconds)
      if (_player.position.inMilliseconds % 5000 < 1000) {
        print('📱 Notification updated: ${_currentTitle} - ${_formatDuration(_player.position)}/${_formatDuration(_player.duration)} - ${_player.playing ? "▶️" : "⏸️"}');
      }
    } on MissingPluginException {
      // Native code not available - this is expected if app wasn't rebuilt
      // Audio playback will continue without notifications
    } catch (e) {
      print('❌ Error updating notification: $e');
    }
  }
  
  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> play(String url, {String? title, String? artist, Duration? duration}) async {
    if (!_isInitialized) await initialize();
    
    _currentTitle = title;
    _currentArtist = artist;
    
    try {
      await _player.setUrl(url);
      await _player.play();
      
      // Start notification service (non-blocking - audio will play even if this fails)
      try {
        await _channel.invokeMethod('startService', {
          'title': title ?? 'Podcast',
          'artist': artist ?? 'KPSS & AGS 2026',
          'isPlaying': true,
          'position': 0,
          'duration': duration?.inMilliseconds ?? 0,
        });
        print('✅ Native notification service started successfully');
      } on MissingPluginException {
        // Native code not available - audio will play without notifications
        print('⚠️ Native notification service not available. Audio will play without notifications.');
        print('⚠️ Please rebuild the app (flutter clean && flutter run) to enable notifications.');
      } catch (e) {
        print('⚠️ Error starting notification service: $e');
        // Continue with audio playback
      }
      
      print('✅ Playing: $title');
    } catch (e) {
      print('❌ Error playing audio: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    print('⏸️ Audio paused');
    await _updateNotification();
  }

  Future<void> resume() async {
    await _player.play();
    print('▶️ Audio resumed');
    await _updateNotification();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentTitle = null;
    _currentArtist = null;
    try {
      await _channel.invokeMethod('stopService');
    } on MissingPluginException {
      // Native code not available - ignore
    } catch (e) {
      print('❌ Error stopping service: $e');
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    await _updateNotification();
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;

  Duration? get duration => _player.duration;
  Duration get position => _player.position;
  bool get playing => _player.playing;
  double get speed => _player.speed;
  ProcessingState get processingState => _player.processingState;

  Future<void> dispose() async {
    _updateTimer?.cancel();
    _playingSubscription?.cancel();
    _durationSubscription?.cancel();
    await stop();
    await _player.dispose();
  }
}
