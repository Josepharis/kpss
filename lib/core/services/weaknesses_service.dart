import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weakness_question.dart';

class WeaknessesService {
  static const String _key = 'weakness_questions';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  static String? get _userId => _auth.currentUser?.uid;

  /// Get user progress document reference
  static DocumentReference get _userProgressDoc =>
      _firestore.collection('userProgress').doc(_userId ?? '');

  /// Get weaknesses collection reference
  static CollectionReference get _weaknessesCollection =>
      _userProgressDoc.collection('weaknesses');

  /// Migrate old SharedPreferences data to Firestore
  static Future<void> migrateToFirestore() async {
    if (_userId == null) return;

    try {
      // Check if migration already done
      final prefs = await SharedPreferences.getInstance();
      final bool? migrated = prefs.getBool('weaknesses_migrated');
      if (migrated == true) {
        debugPrint('✅ Weaknesses already migrated to Firestore');
        return;
      }

      // Get old data from SharedPreferences
      final String? jsonString = prefs.getString(_key);
      if (jsonString == null || jsonString.isEmpty) {
        await prefs.setBool('weaknesses_migrated', true);
        return;
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final List<WeaknessQuestion> weaknesses = jsonList
          .map(
            (json) => WeaknessQuestion.fromJson(json as Map<String, dynamic>),
          )
          .toList();

      // Migrate to Firestore
      final batch = _firestore.batch();
      for (var weakness in weaknesses) {
        final docRef = _weaknessesCollection.doc(
          '${weakness.topicName}_${weakness.id}',
        );
        batch.set(docRef, {
          'id': weakness.id,
          'question': weakness.question,
          'options': weakness.options,
          'correctAnswerIndex': weakness.correctAnswerIndex,
          'explanation': weakness.explanation,
          'lessonId': weakness.lessonId,
          'topicName': weakness.topicName,
          'addedAt': Timestamp.fromDate(weakness.addedAt),
          'isFromWrongAnswer': weakness.isFromWrongAnswer,
          'imageUrl': weakness.imageUrl,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Mark as migrated
      await prefs.setBool('weaknesses_migrated', true);
      debugPrint('✅ Migrated ${weaknesses.length} weaknesses to Firestore');
    } catch (e) {
      debugPrint('❌ Error migrating weaknesses to Firestore: $e');
    }
  }

  // Tüm eksik soruları getir
  static Future<List<WeaknessQuestion>> getAllWeaknesses() async {
    if (_userId == null) {
      // Not logged in, try to migrate old data first
      await migrateToFirestore();
      return [];
    }

    try {
      // Migrate old data if exists
      await migrateToFirestore();

      // Get from Firestore
      final snapshot = await _weaknessesCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Create an intermediate map to handle Timestamp to String conversion for fromJson if needed
        // or just map manually but including imageUrl
        return WeaknessQuestion(
          id: data['id'] ?? '',
          question: data['question'] ?? '',
          options: List<String>.from(data['options'] ?? []),
          correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
          explanation: data['explanation'] ?? '',
          lessonId: data['lessonId'] ?? '',
          topicName: data['topicName'] ?? '',
          addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isFromWrongAnswer: data['isFromWrongAnswer'] ?? false,
          imageUrl: data['imageUrl'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting weaknesses from Firestore: $e');
      return [];
    }
  }

  // Konu başlığına göre eksik soruları getir
  static Future<List<WeaknessQuestion>> getWeaknessesByTopic(
    String topicName,
  ) async {
    final allWeaknesses = await getAllWeaknesses();
    return allWeaknesses.where((w) => w.topicName == topicName).toList();
  }

  // Konu başlıklarına göre gruplanmış eksik soruları getir
  static Future<Map<String, List<WeaknessQuestion>>>
  getWeaknessesGroupedByTopic() async {
    final allWeaknesses = await getAllWeaknesses();
    final Map<String, List<WeaknessQuestion>> grouped = {};

    for (var weakness in allWeaknesses) {
      if (!grouped.containsKey(weakness.topicName)) {
        grouped[weakness.topicName] = [];
      }
      grouped[weakness.topicName]!.add(weakness);
    }

    return grouped;
  }

  // Ders ID'sine göre eksik soruları getir
  static Future<List<WeaknessQuestion>> getWeaknessesByLesson(
    String lessonId,
  ) async {
    final allWeaknesses = await getAllWeaknesses();
    return allWeaknesses.where((w) => w.lessonId == lessonId).toList();
  }

  // Ders bazında gruplanmış eksik soruları getir
  static Future<Map<String, List<WeaknessQuestion>>>
  getWeaknessesGroupedByLesson() async {
    final allWeaknesses = await getAllWeaknesses();
    final Map<String, List<WeaknessQuestion>> grouped = {};

    for (var weakness in allWeaknesses) {
      if (weakness.lessonId.isEmpty) continue; // Eski veriler için skip
      if (!grouped.containsKey(weakness.lessonId)) {
        grouped[weakness.lessonId] = [];
      }
      grouped[weakness.lessonId]!.add(weakness);
    }

    return grouped;
  }

  // Ders ve konu bazında gruplanmış eksik soruları getir
  static Future<Map<String, Map<String, List<WeaknessQuestion>>>>
  getWeaknessesGroupedByLessonAndTopic() async {
    final allWeaknesses = await getAllWeaknesses();
    final Map<String, Map<String, List<WeaknessQuestion>>> grouped = {};

    for (var weakness in allWeaknesses) {
      if (weakness.lessonId.isEmpty) continue; // Eski veriler için skip

      if (!grouped.containsKey(weakness.lessonId)) {
        grouped[weakness.lessonId] = {};
      }

      if (!grouped[weakness.lessonId]!.containsKey(weakness.topicName)) {
        grouped[weakness.lessonId]![weakness.topicName] = [];
      }

      grouped[weakness.lessonId]![weakness.topicName]!.add(weakness);
    }

    return grouped;
  }

  // Belirli bir ders ve konuya ait eksik soruları getir
  static Future<List<WeaknessQuestion>> getWeaknessesByLessonAndTopic(
    String lessonId,
    String topicName,
  ) async {
    final allWeaknesses = await getAllWeaknesses();
    return allWeaknesses
        .where((w) => w.lessonId == lessonId && w.topicName == topicName)
        .toList();
  }

  // Eksik soru ekle
  static Future<bool> addWeakness(WeaknessQuestion weakness) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot save weakness');
      return false;
    }

    try {
      // Migrate old data first
      await migrateToFirestore();

      // Check if already exists
      final docId = '${weakness.topicName}_${weakness.id}';
      final doc = await _weaknessesCollection.doc(docId).get();
      if (doc.exists) {
        return false; // Already exists
      }

      // Add to Firestore
      await _weaknessesCollection.doc(docId).set({
        'id': weakness.id,
        'question': weakness.question,
        'options': weakness.options,
        'correctAnswerIndex': weakness.correctAnswerIndex,
        'explanation': weakness.explanation,
        'lessonId': weakness.lessonId,
        'topicName': weakness.topicName,
        'addedAt': Timestamp.fromDate(weakness.addedAt),
        'isFromWrongAnswer': weakness.isFromWrongAnswer,
        'imageUrl': weakness.imageUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Weakness added to Firestore: ${weakness.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding weakness to Firestore: $e');
      return false;
    }
  }

  // Eksik soruyu kaldır
  static Future<bool> removeWeakness(
    String questionId,
    String topicName, {
    String? lessonId,
  }) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot remove weakness');
      return false;
    }

    try {
      final docId = '${topicName}_${questionId}';
      final doc = await _weaknessesCollection.doc(docId).get();

      // If lessonId is provided, verify it matches
      if (lessonId != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data?['lessonId'] != lessonId) {
          return false; // Lesson ID doesn't match
        }
      }

      await _weaknessesCollection.doc(docId).delete();
      debugPrint('✅ Weakness removed from Firestore: $questionId');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing weakness from Firestore: $e');
      return false;
    }
  }

  // Tüm eksik soruları temizle
  static Future<bool> clearAllWeaknesses() async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot clear weaknesses');
      return false;
    }

    try {
      // Delete all from Firestore
      final snapshot = await _weaknessesCollection.get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Also clear old SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);

      debugPrint('✅ All weaknesses cleared from Firestore');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing weaknesses from Firestore: $e');
      return false;
    }
  }

  // Belirli bir konudaki tüm eksik soruları temizle
  static Future<bool> clearWeaknessesByTopic(
    String topicName, {
    String? lessonId,
  }) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot clear weaknesses');
      return false;
    }

    try {
      Query query = _weaknessesCollection.where(
        'topicName',
        isEqualTo: topicName,
      );
      if (lessonId != null) {
        query = query.where('lessonId', isEqualTo: lessonId);
      }

      final snapshot = await query.get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Weaknesses cleared for topic: $topicName');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing weaknesses by topic: $e');
      return false;
    }
  }

  // Belirli bir dersteki tüm eksik soruları temizle
  static Future<bool> clearWeaknessesByLesson(String lessonId) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot clear weaknesses');
      return false;
    }

    try {
      final snapshot = await _weaknessesCollection
          .where('lessonId', isEqualTo: lessonId)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('✅ Weaknesses cleared for lesson: $lessonId');
      return true;
    } catch (e) {
      debugPrint('❌ Error clearing weaknesses by lesson: $e');
      return false;
    }
  }

  // Soru zaten eksiklerde mi kontrol et
  static Future<bool> isQuestionInWeaknesses(
    String questionId,
    String topicName, {
    String? lessonId,
  }) async {
    if (_userId == null) {
      return false;
    }

    try {
      final docId = '${topicName}_${questionId}';
      final doc = await _weaknessesCollection.doc(docId).get();

      if (!doc.exists) {
        return false;
      }

      // If lessonId is provided, verify it matches
      if (lessonId != null) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['lessonId'] == lessonId;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error checking if question is in weaknesses: $e');
      return false;
    }
  }
}
