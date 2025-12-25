import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'podcast_audio_handler.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  PodcastAudioHandler? _audioHandler;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _audioHandler = await AudioService.init(
      builder: () => PodcastAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.kpssags2026.audio',
        androidNotificationChannelName: 'KPSS Podcast',
        androidNotificationChannelDescription: 'Podcast oynatma bildirimleri',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );
    
    _isInitialized = true;
  }

  Future<void> play(String url, {String? title, String? artist, Duration? duration}) async {
    if (!_isInitialized) await initialize();
    
    try {
      final mediaItem = MediaItem(
        id: url,
        title: title ?? 'Podcast',
        artist: artist ?? 'KPSS & AGS 2026',
        duration: duration,
        artUri: null,
        album: 'KPSS & AGS 2026',
      );
      
      await _audioHandler?.setMediaItem(mediaItem);
      await _audioHandler?.play();
    } catch (e) {
      print('Error playing audio: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    if (!_isInitialized) return;
    await _audioHandler?.pause();
  }

  Future<void> resume() async {
    if (!_isInitialized) return;
    await _audioHandler?.play();
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _audioHandler?.stop();
  }

  Future<void> seek(Duration position) async {
    if (!_isInitialized) return;
    await _audioHandler?.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    if (!_isInitialized) return;
    await _audioHandler?.setSpeed(speed);
  }

  Stream<Duration> get positionStream {
    if (!_isInitialized || _audioHandler == null) return Stream.value(Duration.zero);
    return _audioHandler!.playbackState.stream
        .map((state) => state.updatePosition ?? Duration.zero)
        .distinct();
  }
  
  Stream<Duration?> get durationStream {
    if (!_isInitialized || _audioHandler == null) return Stream.value(null);
    // Duration comes from media item, approximate from position
    return _audioHandler!.playbackState.stream
        .map((state) => state.bufferedPosition)
        .distinct();
  }
  
  Stream<bool> get playingStream {
    if (!_isInitialized || _audioHandler == null) return Stream.value(false);
    return _audioHandler!.playbackState.stream
        .map((state) => state.playing)
        .distinct();
  }

  Duration? get duration {
    if (!_isInitialized || _audioHandler == null) return null;
    final state = _audioHandler!.playbackState.value;
    return state.bufferedPosition;
  }
  
  Duration get position {
    if (!_isInitialized || _audioHandler == null) return Duration.zero;
    final state = _audioHandler!.playbackState.value;
    return state.updatePosition ?? Duration.zero;
  }
  
  bool get playing {
    if (!_isInitialized || _audioHandler == null) return false;
    final state = _audioHandler!.playbackState.value;
    return state.playing;
  }
  
  double get speed {
    if (!_isInitialized || _audioHandler == null) return 1.0;
    final state = _audioHandler!.playbackState.value;
    return state.speed;
  }
  
  ProcessingState get processingState {
    if (!_isInitialized || _audioHandler == null) return ProcessingState.idle;
    final state = _audioHandler!.playbackState.value;
    return _convertProcessingState(state.processingState);
  }

  ProcessingState _convertProcessingState(AudioProcessingState state) {
    switch (state) {
      case AudioProcessingState.idle:
        return ProcessingState.idle;
      case AudioProcessingState.loading:
        return ProcessingState.loading;
      case AudioProcessingState.buffering:
        return ProcessingState.buffering;
      case AudioProcessingState.ready:
        return ProcessingState.ready;
      case AudioProcessingState.completed:
        return ProcessingState.completed;
      case AudioProcessingState.error:
        return ProcessingState.idle;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      try {
        await _audioHandler?.disposePlayer();
        await AudioService.stop();
        _isInitialized = false;
      } catch (e) {
        print('Error disposing audio service: $e');
        _isInitialized = false;
      }
    }
  }
}
