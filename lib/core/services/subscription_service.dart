import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/topic.dart';

/// Service for managing user subscriptions
class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _keySubscriptionStatus = 'subscription_status';
  static const String _keySubscriptionType = 'subscription_type';
  static const String _keySubscriptionEndDate = 'subscription_end_date';
  
  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;
  
  /// Get user subscription document reference
  DocumentReference? get _userSubscriptionDoc {
    if (_userId == null) return null;
    return _firestore.collection('users').doc(_userId).collection('subscription').doc('current');
  }
  
  /// Check if user has premium subscription
  Future<bool> isPremium() async {
    try {
      // Önce cache'den kontrol et (hızlı)
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getString(_keySubscriptionStatus);
      final cachedEndDate = prefs.getInt(_keySubscriptionEndDate);
      
      if (cachedStatus == 'premium' && cachedEndDate != null) {
        final endDate = DateTime.fromMillisecondsSinceEpoch(cachedEndDate);
        if (endDate.isAfter(DateTime.now())) {
          return true; // Cache'den premium ve hala geçerli
        }
      }
      
      // Cache'den premium değilse veya süresi dolmuşsa Firestore'dan kontrol et
      if (_userId == null) return false;
      
      final doc = await _userSubscriptionDoc?.get();
      if (doc == null || !doc.exists) {
        // Firestore'da abonelik yok, cache'i temizle
        await prefs.remove(_keySubscriptionStatus);
        await prefs.remove(_keySubscriptionType);
        await prefs.remove(_keySubscriptionEndDate);
        return false;
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      
      final status = data['status'] as String? ?? 'free';
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      
      // Cache'e kaydet
      await prefs.setString(_keySubscriptionStatus, status);
      if (endDate != null) {
        await prefs.setInt(_keySubscriptionEndDate, endDate.millisecondsSinceEpoch);
      }
      
      // Premium kontrolü
      if (status == 'premium' && endDate != null) {
        return endDate.isAfter(DateTime.now());
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      // Hata durumunda cache'den kontrol et
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedStatus = prefs.getString(_keySubscriptionStatus);
        return cachedStatus == 'premium';
      } catch (_) {
        return false;
      }
    }
  }
  
  /// Check if topic is free (order == 1)
  bool isTopicFree(Topic topic) {
    return topic.order == 1;
  }
  
  /// Check if user can access topic
  Future<bool> canAccessTopic(Topic topic) async {
    // Eğer konu free ise (order == 1), herkes erişebilir
    if (isTopicFree(topic)) {
      return true;
    }
    
    // Premium konular için premium kontrolü yap
    return await isPremium();
  }
  
  /// Get subscription status
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      if (_userId == null) {
        return SubscriptionStatus.free();
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cachedStatus = prefs.getString(_keySubscriptionStatus);
      final cachedEndDate = prefs.getInt(_keySubscriptionEndDate);
      
      // Cache'den kontrol et
      if (cachedStatus == 'premium' && cachedEndDate != null) {
        final endDate = DateTime.fromMillisecondsSinceEpoch(cachedEndDate);
        if (endDate.isAfter(DateTime.now())) {
          final type = prefs.getString(_keySubscriptionType) ?? 'monthly';
          return SubscriptionStatus.premium(
            type: type,
            endDate: endDate,
          );
        }
      }
      
      // Firestore'dan kontrol et
      final doc = await _userSubscriptionDoc?.get();
      if (doc == null || !doc.exists) {
        return SubscriptionStatus.free();
      }
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return SubscriptionStatus.free();
      
      final status = data['status'] as String? ?? 'free';
      final type = data['type'] as String?;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      
      // Cache'e kaydet
      await prefs.setString(_keySubscriptionStatus, status);
      if (type != null) {
        await prefs.setString(_keySubscriptionType, type);
      }
      if (endDate != null) {
        await prefs.setInt(_keySubscriptionEndDate, endDate.millisecondsSinceEpoch);
      }
      
      if (status == 'premium' && endDate != null && endDate.isAfter(DateTime.now())) {
        return SubscriptionStatus.premium(
          type: type ?? 'monthly',
          endDate: endDate,
        );
      }
      
      return SubscriptionStatus.free();
    } catch (e) {
      debugPrint('Error getting subscription status: $e');
      return SubscriptionStatus.free();
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
      
      // Cache'e kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySubscriptionStatus, status);
      if (type != null) {
        await prefs.setString(_keySubscriptionType, type);
      }
      if (endDate != null) {
        await prefs.setInt(_keySubscriptionEndDate, endDate.millisecondsSinceEpoch);
      }
      
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
      
      if (status == 'premium' && endDate != null && endDate.isAfter(DateTime.now())) {
        return SubscriptionStatus.premium(
          type: type ?? 'monthly',
          endDate: endDate,
        );
      }
      
      return SubscriptionStatus.free();
    });
  }
}

/// Subscription status model
class SubscriptionStatus {
  final bool isPremium;
  final String? type; // 'monthly', '6monthly', or 'yearly'
  final DateTime? endDate;
  
  SubscriptionStatus.free()
      : isPremium = false,
        type = null,
        endDate = null;
  
  SubscriptionStatus.premium({
    required String type,
    required DateTime endDate,
  })  : isPremium = true,
        type = type,
        endDate = endDate;
  
  bool get isActive => isPremium && endDate != null && endDate!.isAfter(DateTime.now());
  
  String get displayText {
    if (!isPremium) return 'Ücretsiz';
    if (type == 'yearly') return 'Premium (Yıllık)';
    if (type == '6monthly') return 'Premium (6 Aylık)';
    return 'Premium (Aylık)';
  }
}
