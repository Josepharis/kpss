import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_card.dart';

class SavedCard {
  final String id;
  final String frontText;
  final String backText;
  final String topicId;
  final String topicName;
  final String lessonId;
  final DateTime savedAt;

  SavedCard({
    required this.id,
    required this.frontText,
    required this.backText,
    required this.topicId,
    required this.topicName,
    required this.lessonId,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'frontText': frontText,
      'backText': backText,
      'topicId': topicId,
      'topicName': topicName,
      'lessonId': lessonId,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] ?? '',
      frontText: json['frontText'] ?? '',
      backText: json['backText'] ?? '',
      topicId: json['topicId'] ?? '',
      topicName: json['topicName'] ?? '',
      lessonId: json['lessonId'] ?? '',
      savedAt: json['savedAt'] != null
          ? DateTime.parse(json['savedAt'])
          : DateTime.now(),
    );
  }

  factory SavedCard.fromFlashCard(
    FlashCard card,
    String topicId,
    String topicName,
    String lessonId,
  ) {
    return SavedCard(
      id: card.id,
      frontText: card.frontText,
      backText: card.backText,
      topicId: topicId,
      topicName: topicName,
      lessonId: lessonId,
      savedAt: DateTime.now(),
    );
  }
}

class SavedCardsService {
  static const String _key = 'saved_cards';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Get user progress document reference
  static DocumentReference get _userProgressDoc => 
      _firestore.collection('userProgress').doc(_userId ?? '');

  /// Get saved cards collection reference
  static CollectionReference get _savedCardsCollection => 
      _userProgressDoc.collection('savedCards');

  /// Migrate old SharedPreferences data to Firestore
  static Future<void> migrateToFirestore() async {
    if (_userId == null) return;
    
    try {
      // Check if migration already done
      final prefs = await SharedPreferences.getInstance();
      final bool? migrated = prefs.getBool('saved_cards_migrated');
      if (migrated == true) {
        debugPrint('✅ Saved cards already migrated to Firestore');
        return;
      }

      // Get old data from SharedPreferences
      final String? jsonString = prefs.getString(_key);
      if (jsonString == null || jsonString.isEmpty) {
        await prefs.setBool('saved_cards_migrated', true);
        return;
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final List<SavedCard> cards = jsonList
          .map((json) => SavedCard.fromJson(json as Map<String, dynamic>))
          .toList();

      // Migrate to Firestore
      final batch = _firestore.batch();
      for (var card in cards) {
        final docRef = _savedCardsCollection.doc('${card.topicId}_${card.id}');
        batch.set(docRef, {
          'id': card.id,
          'frontText': card.frontText,
          'backText': card.backText,
          'topicId': card.topicId,
          'topicName': card.topicName,
          'lessonId': card.lessonId,
          'savedAt': Timestamp.fromDate(card.savedAt),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Mark as migrated
      await prefs.setBool('saved_cards_migrated', true);
      debugPrint('✅ Migrated ${cards.length} saved cards to Firestore');
    } catch (e) {
      debugPrint('❌ Error migrating saved cards to Firestore: $e');
    }
  }

  // Tüm kaydedilmiş kartları getir
  static Future<List<SavedCard>> getAllSavedCards() async {
    if (_userId == null) {
      // Not logged in, try to migrate old data first
      await migrateToFirestore();
      return [];
    }

    try {
      // Migrate old data if exists
      await migrateToFirestore();

      // Get from Firestore
      final snapshot = await _savedCardsCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SavedCard(
          id: data['id'] ?? '',
          frontText: data['frontText'] ?? '',
          backText: data['backText'] ?? '',
          topicId: data['topicId'] ?? '',
          topicName: data['topicName'] ?? '',
          lessonId: data['lessonId'] ?? '',
          savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting saved cards from Firestore: $e');
      return [];
    }
  }

  // Konu başlığına göre kaydedilmiş kartları getir
  static Future<List<SavedCard>> getSavedCardsByTopic(String topicName) async {
    final allCards = await getAllSavedCards();
    return allCards.where((c) => c.topicName == topicName).toList();
  }

  // Konu başlıklarına göre gruplanmış kaydedilmiş kartları getir
  static Future<Map<String, List<SavedCard>>> getSavedCardsGroupedByTopic() async {
    final allCards = await getAllSavedCards();
    final Map<String, List<SavedCard>> grouped = {};

    for (var card in allCards) {
      if (!grouped.containsKey(card.topicName)) {
        grouped[card.topicName] = [];
      }
      grouped[card.topicName]!.add(card);
    }

    return grouped;
  }

  // Ders ID'sine göre kaydedilmiş kartları getir
  static Future<List<SavedCard>> getSavedCardsByLesson(String lessonId) async {
    final allCards = await getAllSavedCards();
    return allCards.where((c) => c.lessonId == lessonId).toList();
  }

  // Ders bazında gruplanmış kaydedilmiş kartları getir
  static Future<Map<String, List<SavedCard>>> getSavedCardsGroupedByLesson() async {
    final allCards = await getAllSavedCards();
    final Map<String, List<SavedCard>> grouped = {};

    for (var card in allCards) {
      if (!grouped.containsKey(card.lessonId)) {
        grouped[card.lessonId] = [];
      }
      grouped[card.lessonId]!.add(card);
    }

    return grouped;
  }

  // Kaydedilmiş kart ekle
  static Future<bool> addSavedCard(SavedCard card) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot save card');
      return false;
    }

    try {
      // Migrate old data first
      await migrateToFirestore();

      // Check if already exists
      final docId = '${card.topicId}_${card.id}';
      final doc = await _savedCardsCollection.doc(docId).get();
      if (doc.exists) {
        return false; // Already exists
      }

      // Add to Firestore
      await _savedCardsCollection.doc(docId).set({
        'id': card.id,
        'frontText': card.frontText,
        'backText': card.backText,
        'topicId': card.topicId,
        'topicName': card.topicName,
        'lessonId': card.lessonId,
        'savedAt': Timestamp.fromDate(card.savedAt),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Saved card added to Firestore: ${card.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding saved card to Firestore: $e');
      return false;
    }
  }

  // Kaydedilmiş kartı kaldır
  static Future<bool> removeSavedCard(String cardId, String topicId) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot remove card');
      return false;
    }

    try {
      final docId = '${topicId}_${cardId}';
      await _savedCardsCollection.doc(docId).delete();
      debugPrint('✅ Saved card removed from Firestore: $cardId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing saved card from Firestore: $e');
      return false;
    }
  }

  // Tüm kaydedilmiş kartları temizle
  static Future<bool> clearAllSavedCards() async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot clear cards');
      return false;
    }

    try {
      // Delete all from Firestore
      final snapshot = await _savedCardsCollection.get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Also clear old SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);

      debugPrint('✅ All saved cards cleared from Firestore');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing saved cards from Firestore: $e');
      return false;
    }
  }

  // Belirli bir konudaki tüm kaydedilmiş kartları temizle
  static Future<bool> clearSavedCardsByTopic(String topicName, {String? lessonId}) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot clear cards');
      return false;
    }

    try {
      Query query = _savedCardsCollection.where('topicName', isEqualTo: topicName);
      if (lessonId != null) {
        query = query.where('lessonId', isEqualTo: lessonId);
      }

      final snapshot = await query.get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Saved cards cleared for topic: $topicName');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing saved cards by topic: $e');
      return false;
    }
  }

  // Belirli bir dersteki tüm kaydedilmiş kartları temizle
  static Future<bool> clearSavedCardsByLesson(String lessonId) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot clear cards');
      return false;
    }

    try {
      final snapshot = await _savedCardsCollection
          .where('lessonId', isEqualTo: lessonId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Saved cards cleared for lesson: $lessonId');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing saved cards by lesson: $e');
      return false;
    }
  }

  // Kart zaten kaydedilmiş mi kontrol et
  static Future<bool> isCardSaved(String cardId, String topicId) async {
    if (_userId == null) {
      return false;
    }

    try {
      final docId = '${topicId}_${cardId}';
      final doc = await _savedCardsCollection.doc(docId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking if card is saved: $e');
      return false;
    }
  }
}
