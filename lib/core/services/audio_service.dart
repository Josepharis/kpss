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
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Listen to media actions from notification
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'mediaAction':
          final action = call.arguments as String;
          switch (action) {
            case 'PLAY_PAUSE':
              if (_player.playing) {
                await pause();
              } else {
                await resume();
              }
              break;
            case 'STOP':
              await stop();
              break;
            case 'NEXT':
              // Implement next logic
              break;
            case 'PREVIOUS':
              // Implement previous logic
              break;
          }
          break;
      }
    });
    
    // Listen to position and playing state to update notification
    _positionSubscription = _player.positionStream.listen((position) {
      _updateNotification();
    });
    
    _playingSubscription = _player.playingStream.listen((playing) {
      _updateNotification();
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
    } catch (e) {
      print('❌ Error updating notification: $e');
    }
  }

  Future<void> play(String url, {String? title, String? artist, Duration? duration}) async {
    if (!_isInitialized) await initialize();
    
    _currentTitle = title;
    _currentArtist = artist;
    
    try {
      await _player.setUrl(url);
      await _player.play();
      
      // Start notification service
      await _channel.invokeMethod('startService', {
        'title': title ?? 'Podcast',
        'artist': artist ?? 'KPSS & AGS 2026',
        'isPlaying': true,
        'position': 0,
        'duration': duration?.inMilliseconds ?? 0,
      });
      
      print('✅ Playing: $title');
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    await _updateNotification();
  }

  Future<void> resume() async {
    await _player.play();
    await _updateNotification();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentTitle = null;
    _currentArtist = null;
    try {
      await _channel.invokeMethod('stopService');
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
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    await stop();
    await _player.dispose();
  }
}
