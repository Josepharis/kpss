package com.example.kpss_ags_2026

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat as MediaNotificationCompat
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MediaNotificationService : Service() {
    private var mediaSession: MediaSessionCompat? = null
    private val CHANNEL_ID = "kpss_podcast_channel"
    private val NOTIFICATION_ID = 1
    private var methodChannel: MethodChannel? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // Get FlutterEngine from cache for method channel (to send events to Flutter)
        val flutterEngine = FlutterEngineCache.getInstance().get(MainActivity.FLUTTER_ENGINE_ID)
        if (flutterEngine != null) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.kpss_ags_2026/media")
        }
        
        mediaSession = MediaSessionCompat(this, "KPSS Podcast").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    methodChannel?.invokeMethod("mediaAction", "PLAY_PAUSE")
                }

                override fun onPause() {
                    methodChannel?.invokeMethod("mediaAction", "PLAY_PAUSE")
                }

                override fun onStop() {
                    methodChannel?.invokeMethod("mediaAction", "STOP")
                }

                override fun onSeekTo(pos: Long) {
                    methodChannel?.invokeMethod("seek", pos.toInt())
                }

                override fun onSkipToNext() {
                    methodChannel?.invokeMethod("mediaAction", "NEXT")
                }

                override fun onSkipToPrevious() {
                    methodChannel?.invokeMethod("mediaAction", "PREVIOUS")
                }
            })
            isActive = true
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "KPSS Podcast",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Podcast oynatma bildirimleri"
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun updateNotification(title: String, artist: String, isPlaying: Boolean, position: Long, duration: Long) {
        // Ensure MediaSession is active
        if (mediaSession?.isActive != true) {
            mediaSession?.isActive = true
        }
        
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "KPSS & AGS 2026")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
            .build()
        
        mediaSession?.setMetadata(metadata)

        val playbackState = PlaybackStateCompat.Builder()
            .setState(
                if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                position,
                if (isPlaying) 1.0f else 0.0f,
                System.currentTimeMillis()
            )
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_STOP
            )
            .build()
        
        mediaSession?.setPlaybackState(playbackState)

        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(android.R.drawable.ic_media_play) // Will use app icon if available
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(isPlaying)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setShowWhen(false)
            .setStyle(
                MediaNotificationCompat.MediaStyle()
                    .setShowActionsInCompactView(0, 1, 2)
                    .setMediaSession(mediaSession?.sessionToken)
            )
            .addAction(
                android.R.drawable.ic_media_previous,
                "Önceki",
                createActionIntent("PREVIOUS")
            )
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Duraklat" else "Oynat",
                createActionIntent("PLAY_PAUSE")
            )
            .addAction(
                android.R.drawable.ic_media_next,
                "Sonraki",
                createActionIntent("NEXT")
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Durdur",
                createActionIntent("STOP")
            )
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createActionIntent(action: String): PendingIntent {
        val intent = Intent(this, MediaNotificationReceiver::class.java).apply {
            putExtra("action", action)
        }
        return PendingIntent.getBroadcast(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            when (intent.action) {
                "UPDATE_NOTIFICATION" -> {
                    val title = intent.getStringExtra("title") ?: "Podcast"
                    val artist = intent.getStringExtra("artist") ?: "KPSS & AGS 2026"
                    val isPlaying = intent.getBooleanExtra("isPlaying", false)
                    val position = intent.getLongExtra("position", 0L)
                    val duration = intent.getLongExtra("duration", 0L)
                    updateNotification(title, artist, isPlaying, position, duration)
                }
                else -> {
                    val title = intent.getStringExtra("title") ?: "Podcast"
                    val artist = intent.getStringExtra("artist") ?: "KPSS & AGS 2026"
                    val isPlaying = intent.getBooleanExtra("isPlaying", false)
                    val position = intent.getLongExtra("position", 0L)
                    val duration = intent.getLongExtra("duration", 0L)
                    updateNotification(title, artist, isPlaying, position, duration)
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        mediaSession?.release()
        stopForeground(true)
    }
}

