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
  }

  Future<String?> getToken() async {
    try {
      // In iOS, we need to wait for APNS token to be available
      // or Firebase will throw a 'apns-token-not-set' error.
      if (Platform.isIOS) {
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('NotificationService: APNS token not ready yet, waiting...');
          // Give it a little delay or it will fail in next step
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _fcm.getAPNSToken();
        }
      }

      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('NotificationService: Error getting token: $e');
      return null;
    }
  }
}
