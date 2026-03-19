import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission for iOS and Android 13+
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
      // Subscribe to general topic for mass notifications
      await _fcm.subscribeToTopic('general');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }

    // Set foreground notification presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen to messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.notification?.title}');
      // Handle the message (e.g., show a local notification or snackbar)
    });

    // Listen to messages when app is opened from a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification: ${message.notification?.title}');
      // Navigate to a specific page if needed
    });

    // Fetch token on init for logging
    await getToken();
  }

  Future<String?> getToken() async {
    try {
      print('🔔 NotificationService: Token alma süreci başlatıldı...');
      
      if (Platform.isIOS) {
        print('🔔 NotificationService: iOS algılandı, APNS kontrol ediliyor...');
        String? apnsToken = await _fcm.getAPNSToken();
        
        if (apnsToken == null) {
          print('🔔 NotificationService: ⚠️ APNS Token henüz hazır değil. 3 saniye bekleniyor...');
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _fcm.getAPNSToken();
        }

        if (apnsToken != null) {
          print('🔔 NotificationService: ✅ APNS Token başarıyla alındı: $apnsToken');
        } else {
          print('🔔 NotificationService: ❌ Kritik: APNS Token alınamadı. Simülatör kısıtlaması veya Xcode ayarı eksik olabilir.');
        }
      }

      String? token = await _fcm.getToken();
      if (token != null) {
        print('🔔 NotificationService: 🚀 FCM Token Hazır: $token');
      } else {
        print('🔔 NotificationService: ❌ FCM Token boş döndü.');
      }
      return token;
    } catch (e) {
      print('🔔 NotificationService: 💥 HATA: $e');
      return null;
    }
  }
}
