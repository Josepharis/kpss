import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/topic.dart';

/// Service for managing user subscriptions
class SubscriptionService {
  // Singleton
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal() {
    // Uygulama açılırken cache'den son durumu yükle (UI hemen tepki versin diye)
    _initFromCache();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Real-time status
  SubscriptionStatus? currentStatus;
  final _statusController = StreamController<SubscriptionStatus>.broadcast();
  Stream<SubscriptionStatus> get statusStream => _statusController.stream;

  static const String _keySubscriptionStatus = 'subscription_status';
  static const String _keySubscriptionType = 'subscription_type';
  static const String _keySubscriptionEndDate = 'subscription_end_date';

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Get user subscription document reference
  DocumentReference? get _userSubscriptionDoc {
    if (_userId == null) return null;
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('subscription')
        .doc('current');
  }

  /// Initial load from cache (fastest)
  Future<void> _initFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final status = prefs.getString(_keySubscriptionStatus);
      final type = prefs.getString(_keySubscriptionType);
      final endDateMs = prefs.getInt(_keySubscriptionEndDate);

      if (status == 'premium' && endDateMs != null) {
        final endDate = DateTime.fromMillisecondsSinceEpoch(endDateMs);
        if (endDate.isAfter(DateTime.now())) {
          currentStatus = SubscriptionStatus.premium(
            type: type ?? 'monthly',
            endDate: endDate,
          );
          _statusController.add(currentStatus!);
          return;
        }
      }
      currentStatus = SubscriptionStatus.free();
      _statusController.add(currentStatus!);
    } catch (e) {
      currentStatus = SubscriptionStatus.free();
      _statusController.add(currentStatus!);
    }
  }

  /// Check if user has premium subscription
  Future<bool> isPremium({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh && currentStatus != null) {
        return currentStatus!.isPremium;
      }

      final prefs = await SharedPreferences.getInstance();

      if (!forceRefresh) {
        // Önce cache'den kontrol et (hızlı)
        final cachedStatus = prefs.getString(_keySubscriptionStatus);
        final cachedEndDate = prefs.getInt(_keySubscriptionEndDate);

        if (cachedStatus == 'premium' && cachedEndDate != null) {
          final endDate = DateTime.fromMillisecondsSinceEpoch(cachedEndDate);
          if (endDate.isAfter(DateTime.now())) {
            _notifyStatus(SubscriptionStatus.premium(
              type: prefs.getString(_keySubscriptionType) ?? 'monthly',
              endDate: endDate,
            ));
            return true;
          }
        }
      }

      // Firestore'dan kontrol et
      if (_userId == null) return false;

      final doc = await _userSubscriptionDoc?.get();
      if (doc == null || !doc.exists) {
        await _clearLocalCache();
        _notifyStatus(SubscriptionStatus.free());
        return false;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final statusStr = data['status'] as String? ?? 'free';
      final endDate = (data['endDate'] as Timestamp?)?.toDate();

      final isActive = statusStr == 'premium' && endDate != null && endDate.isAfter(DateTime.now());

      if (isActive) {
        final newStatus = SubscriptionStatus.premium(
          type: data['type'] as String? ?? 'monthly',
          endDate: endDate!,
        );
        await _saveToLocalCache(newStatus);
        _notifyStatus(newStatus);
        return true;
      } else {
        await _clearLocalCache();
        _notifyStatus(SubscriptionStatus.free());
        return false;
      }
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return currentStatus?.isPremium ?? false;
    }
  }

  /// Sync from Firestore and push to stream
  Future<SubscriptionStatus> getSubscriptionStatus({
    bool forceRefresh = false,
  }) async {
    try {
      if (_userId == null) {
        final free = SubscriptionStatus.free();
        _notifyStatus(free);
        return free;
      }

      // Eğer force değilse ve currentStatus zaten varsa bekletme yapmadan dönebiliriz (UI için stream zaten akıyor)
      if (!forceRefresh && currentStatus != null) {
        return currentStatus!;
      }

      final prefs = await SharedPreferences.getInstance();

      // Firestore'dan taze veriyi çek
      final doc = await _userSubscriptionDoc?.get();
      if (doc == null || !doc.exists) {
        await _clearLocalCache();
        final free = SubscriptionStatus.free();
        _notifyStatus(free);
        return free;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) {
        final free = SubscriptionStatus.free();
        _notifyStatus(free);
        return free;
      }

      final statusStr = data['status'] as String? ?? 'free';
      final type = data['type'] as String?;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();

      final isActive = statusStr == 'premium' && endDate != null && endDate.isAfter(DateTime.now());

      if (isActive) {
        final newStatus = SubscriptionStatus.premium(
          type: type ?? 'monthly',
          endDate: endDate!,
        );
        await _saveToLocalCache(newStatus);
        _notifyStatus(newStatus);
        return newStatus;
      } else {
        await _clearLocalCache();
        final free = SubscriptionStatus.free();
        _notifyStatus(free);
        return free;
      }
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      return currentStatus ?? SubscriptionStatus.free();
    }
  }

  Future<void> _saveToLocalCache(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySubscriptionStatus, status.isPremium ? 'premium' : 'free');
    if (status.type != null) {
      await prefs.setString(_keySubscriptionType, status.type!);
    }
    if (status.endDate != null) {
      await prefs.setInt(_keySubscriptionEndDate, status.endDate!.millisecondsSinceEpoch);
    }
  }

  Future<void> _clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySubscriptionStatus);
    await prefs.remove(_keySubscriptionType);
    await prefs.remove(_keySubscriptionEndDate);
  }

  void _notifyStatus(SubscriptionStatus status) {
    if (currentStatus?.isPremium != status.isPremium || 
        currentStatus?.type != status.type ||
        currentStatus?.endDate != status.endDate) {
      currentStatus = status;
      _statusController.add(status);
    }
  }

  /// Set subscription status (for testing or admin use)
  Future<bool> setSubscriptionStatus({
    required String status,
    String? type,
    DateTime? endDate,
  }) async {
    try {
      if (_userId == null) return false;

      final doc = _userSubscriptionDoc;
      if (doc == null) return false;

      await doc.set({
        'status': status,
        'type': type,
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final isActive = status == 'premium' && endDate != null && endDate.isAfter(DateTime.now());
      final newStatus = isActive 
          ? SubscriptionStatus.premium(type: type ?? 'monthly', endDate: endDate!)
          : SubscriptionStatus.free();
      
      await _saveToLocalCache(newStatus);
      _notifyStatus(newStatus);

      return true;
    } catch (e) {
      debugPrint('Error setting subscription status: $e');
      return false;
    }
  }

  /// Stream subscription status (real-time updates)
  Stream<SubscriptionStatus> streamSubscriptionStatus() {
    if (_userId == null) {
      return Stream.value(SubscriptionStatus.free());
    }

    final doc = _userSubscriptionDoc;
    if (doc == null) {
      return Stream.value(SubscriptionStatus.free());
    }

    return doc.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return SubscriptionStatus.free();
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return SubscriptionStatus.free();

      final status = data['status'] as String? ?? 'free';
      final type = data['type'] as String?;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();

      final active = status == 'premium' && endDate != null && endDate.isAfter(DateTime.now());
      
      final resolvedStatus = active
          ? SubscriptionStatus.premium(type: type ?? 'monthly', endDate: endDate!)
          : SubscriptionStatus.free();
      
      _notifyStatus(resolvedStatus);
      return resolvedStatus;
    });
  }

  /// Check if topic is free (order == 1)
  bool isTopicFree(Topic topic) {
    return topic.order == 1;
  }

  /// Check if user can access topic
  Future<bool> canAccessTopic(Topic topic, {bool forceRefresh = false}) async {
    if (isTopicFree(topic)) return true;
    return await isPremium(forceRefresh: forceRefresh);
  }
}

/// Subscription status model
class SubscriptionStatus {
  final bool isPremium;
  final String? type; // 'monthly', '6monthly', or 'yearly'
  final DateTime? endDate;

  SubscriptionStatus.free() : isPremium = false, type = null, endDate = null;

  SubscriptionStatus.premium({required String type, required DateTime endDate})
    : isPremium = true,
      type = type,
      endDate = endDate;

  bool get isActive =>
      isPremium && endDate != null && endDate!.isAfter(DateTime.now());

  String get displayText {
    if (!isPremium) return 'Ücretsiz';
    if (type == 'yearly') return 'Premium (Yıllık)';
    if (type == '6monthly') return 'Premium (6 Aylık)';
    return 'Premium (Aylık)';
  }
}
