import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

class PodcastAudioHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  PodcastAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    if (_initialized) return;
    
    try {
      // Configure audio session for iOS/Android
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      
      // Set audio session active
      await session.setActive(true);
      _initialized = true;
    } catch (e) {
      print('Error initializing audio session: $e');
    }
    
    // Listen to player state changes
    _player.playbackEventStream.listen(_updatePlaybackState);
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
    _player.durationStream.listen((duration) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ));
    });
    _player.playerStateStream.listen((state) {
      playbackState.add(playbackState.value.copyWith(
        playing: state.playing,
        processingState: _getProcessingState(state.processingState),
      ));
    });
  }

  void _updatePlaybackState(PlaybackEvent event) {
    final playing = _player.playing;
    final queueIndex = event.currentIndex;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(event.processingState),
      playing: playing,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
      speed: _player.speed,
      queueIndex: queueIndex,
    ));
  }

  AudioProcessingState _getProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() async {
    print('PodcastAudioHandler: play() called');
    await _player.play();
    // Force update playback state to show notification/Control Center
    final currentState = playbackState.value;
    playbackState.add(currentState.copyWith(
      playing: true,
      processingState: AudioProcessingState.ready,
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
    ));
    print('PodcastAudioHandler: Playback state updated - playing: true');
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    // Implement next podcast logic if needed
  }

  @override
  Future<void> skipToPrevious() async {
    // Implement previous podcast logic if needed
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setMediaItem(MediaItem mediaItem) async {
    try {
      // Ensure audio session is initialized
      if (!_initialized) {
        await _init();
      }
      
      // Use provided duration or wait for it
      Duration? finalDuration = mediaItem.duration;
      
      // Update media item FIRST - this is critical for iOS Control Center
      // Set it even before loading the URL
      final initialMediaItem = mediaItem.copyWith(
        duration: finalDuration,
      );
      this.mediaItem.add(initialMediaItem);
      queue.add([initialMediaItem]);
      
      // Now load the audio
      await _player.setUrl(mediaItem.id);
      
      // Try to get actual duration from player if not provided
      if (finalDuration == null) {
        try {
          final durationValue = await _player.durationStream.firstWhere((d) => d != null).timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
          finalDuration = durationValue ?? _player.duration;
          
          // Update media item with actual duration
          if (finalDuration != null) {
            final updatedMediaItem = mediaItem.copyWith(duration: finalDuration);
            this.mediaItem.add(updatedMediaItem);
            queue.add([updatedMediaItem]);
          }
        } catch (e) {
          print('Could not get duration: $e');
          finalDuration = _player.duration;
        }
      }
      
      // Wait a bit for the URL to load
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Update playback state to trigger notification/Control Center
      // This is critical for iOS to show in Control Center
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.ready,
        playing: _player.playing,
        updatePosition: Duration.zero,
        bufferedPosition: finalDuration ?? Duration.zero,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
      ));
      
      print('PodcastAudioHandler: MediaItem set - ${mediaItem.title}, Duration: $finalDuration, Playing: ${_player.playing}');
    } catch (e) {
      print('Error setting media item: $e');
      rethrow;
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }

  Future<void> disposePlayer() async {
    await _player.dispose();
  }
}
