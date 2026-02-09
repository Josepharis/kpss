package com.kadrox.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MediaNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.getStringExtra("action") ?: return
        
        val flutterEngine = FlutterEngineCache.getInstance().get(MainActivity.FLUTTER_ENGINE_ID)
        if (flutterEngine != null) {
            val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.kadrox.app/media")
            methodChannel.invokeMethod("mediaAction", action)
        }
    }
}

