package com.kadrox.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val FLUTTER_ENGINE_ID = "kpss_ags_2026_engine"
    }
    
    private var methodChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine)
        
        // Setup method channel for media notification
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kadrox.app/media")
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    val duration = (call.argument<Number>("duration")?.toLong()) ?: 0L
                    val serviceIntent = Intent(this, MediaNotificationService::class.java).apply {
                        putExtra("title", call.argument<String>("title") ?: "Podcast")
                        putExtra("artist", call.argument<String>("artist") ?: "Kadrox")
                        putExtra("isPlaying", call.argument<Boolean>("isPlaying") ?: false)
                        putExtra("position", position)
                        putExtra("duration", duration)
                    }
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(null)
                }
                "updateNotification" -> {
                    val position = (call.argument<Number>("position")?.toLong()) ?: 0L
                    val duration = (call.argument<Number>("duration")?.toLong()) ?: 0L
                    val serviceIntent = Intent(this, MediaNotificationService::class.java).apply {
                        action = "UPDATE_NOTIFICATION"
                        putExtra("title", call.argument<String>("title") ?: "Podcast")
                        putExtra("artist", call.argument<String>("artist") ?: "Kadrox")
                        putExtra("isPlaying", call.argument<Boolean>("isPlaying") ?: false)
                        putExtra("position", position)
                        putExtra("duration", duration)
                    }
                    startService(serviceIntent)
                    result.success(null)
                }
                "stopService" -> {
                    val serviceIntent = Intent(this, MediaNotificationService::class.java)
                    stopService(serviceIntent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
