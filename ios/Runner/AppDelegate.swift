import Flutter
import UIKit
import MediaPlayer
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var commandCenter: MPRemoteCommandCenter?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channel for media notification
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    methodChannel = FlutterMethodChannel(
      name: "com.kadrox.app/media",
      binaryMessenger: controller.binaryMessenger
    )
    
    methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      print("📱 iOS: Method called: \(call.method)")
      self?.handleMethodCall(call: call, result: result)
    }
    
    // Setup remote command center for media controls
    setupRemoteCommandCenter()
    print("✅ iOS: Media notification service initialized")
    
    // Configure audio session for background playback
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      print("✅ iOS: Audio session configured for background playback")
    } catch {
      print("❌ iOS: Failed to configure audio session: \(error)")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupRemoteCommandCenter() {
    commandCenter = MPRemoteCommandCenter.shared()
    
    // Play/Pause command
    commandCenter?.togglePlayPauseCommand.addTarget { [weak self] _ in
      print("📱 iOS: Toggle Play/Pause pressed")
      self?.methodChannel?.invokeMethod("mediaAction", arguments: "PLAY_PAUSE")
      return .success
    }
    
    // Play command
    commandCenter?.playCommand.addTarget { [weak self] _ in
      print("📱 iOS: Play pressed")
      self?.methodChannel?.invokeMethod("mediaAction", arguments: "PLAY_PAUSE")
      return .success
    }
    
    // Pause command
    commandCenter?.pauseCommand.addTarget { [weak self] _ in
      print("📱 iOS: Pause pressed")
      self?.methodChannel?.invokeMethod("mediaAction", arguments: "PLAY_PAUSE")
      return .success
    }
    
    // Stop command
    commandCenter?.stopCommand.addTarget { [weak self] _ in
      print("📱 iOS: Stop pressed")
      self?.methodChannel?.invokeMethod("mediaAction", arguments: "STOP")
      return .success
    }
    
    // Next track command
    commandCenter?.nextTrackCommand.addTarget { [weak self] _ in
      print("📱 iOS: Next pressed")
      self?.methodChannel?.invokeMethod("mediaAction", arguments: "NEXT")
      return .success
    }
    
    // Previous track command
    commandCenter?.previousTrackCommand.addTarget { [weak self] _ in
      print("📱 iOS: Previous pressed")
      self?.methodChannel?.invokeMethod("mediaAction", arguments: "PREVIOUS")
      return .success
    }
    
    // Seek command
    commandCenter?.changePlaybackPositionCommand.addTarget { [weak self] event in
      if let event = event as? MPChangePlaybackPositionCommandEvent {
        let positionMillis = Int(event.positionTime * 1000)
        print("📱 iOS: Seek to \(positionMillis)ms")
        self?.methodChannel?.invokeMethod("seek", arguments: positionMillis)
        return .success
      }
      return .commandFailed
    }
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startService":
      if let args = call.arguments as? [String: Any] {
        let title = args["title"] as? String ?? "Podcast"
        let artist = args["artist"] as? String ?? "Kadrox"
        let isPlaying = args["isPlaying"] as? Bool ?? false
        let position = args["position"] as? Int ?? 0
        let duration = args["duration"] as? Int ?? 0
        
        updateNowPlayingInfo(
          title: title,
          artist: artist,
          isPlaying: isPlaying,
          position: position,
          duration: duration
        )
      }
      result(nil)
      
    case "updateNotification":
      if let args = call.arguments as? [String: Any] {
        let title = args["title"] as? String ?? "Podcast"
        let artist = args["artist"] as? String ?? "Kadrox"
        let isPlaying = args["isPlaying"] as? Bool ?? false
        let position = args["position"] as? Int ?? 0
        let duration = args["duration"] as? Int ?? 0
        
        updateNowPlayingInfo(
          title: title,
          artist: artist,
          isPlaying: isPlaying,
          position: position,
          duration: duration
        )
      }
      result(nil)
      
    case "stopService":
      clearNowPlayingInfo()
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func updateNowPlayingInfo(
    title: String,
    artist: String,
    isPlaying: Bool,
    position: Int,
    duration: Int
  ) {
    var nowPlayingInfo = [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Kadrox"
    
    if duration > 0 {
      nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = Double(duration) / 1000.0
      nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(position) / 1000.0
    }
    
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    print("📱 iOS: Updated Now Playing - Title: \(title), Artist: \(artist), Playing: \(isPlaying), Pos: \(position)ms, Dur: \(duration)ms")
  }
  
  private func clearNowPlayingInfo() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}
