import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RankingUser {
  final String userId;
  final String name;
  final int score;
  final int rank;

  RankingUser({
    required this.userId,
    required this.name,
    required this.score,
    required this.rank,
  });
}

class RankingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get general top rankings across all users
  Future<List<RankingUser>> getGeneralRankings({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('userProgress')
          .orderBy('totalScore', descending: true)
          .orderBy(FieldPath.documentId)
          .limit(limit)
          .get();

      final userProgressDocs = snapshot.docs;
      final userIds = userProgressDocs.map((doc) => doc.id).toList();

      // Batch fetch user names (max 30 id per whereIn)
      Map<String, String> nameMap = {};
      if (userIds.isNotEmpty) {
        // Firestore's `whereIn` clause has a limit of 10 for array elements.
        // For document IDs, it's typically 10, but some sources say 30.
        // To be safe, we'll chunk it if userIds is large.
        // However, for a limit of 20, a single query is fine.
        final userSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds)
            .get();
        for (var doc in userSnapshot.docs) {
          nameMap[doc.id] = doc.data()?['name'] ?? 'Kullanıcı';
        }
      }

      final List<RankingUser> rankings = List.generate(userProgressDocs.length, (i) {
        final doc = userProgressDocs[i];
        final userId = doc.id;
        final score = (doc.data()['totalScore'] ?? 0).toInt();
        return RankingUser(
          userId: userId,
          name: nameMap[userId] ?? 'Kullanıcı',
          score: score,
          rank: i + 1,
        );
      });

      // Filtering if score is 0 and not top 5
      return rankings.where((r) => r.score > 0 || r.rank <= 5).toList();
    } catch (e) {
      debugPrint('Error getting general rankings: $e');
      return [];
    }
  }

  /// Get subject-based rankings using Collection Group query on 'lessons' subcollections
  Future<List<RankingUser>> getSubjectRankings(String subjectName, {int limit = 20}) async {
    try {
      final lessonIds = _mapSubjectToLessonIds(subjectName);
      if (lessonIds.isEmpty) return [];

      // Query all 'lessons' subcollections where lessonId matches any in the list
      // Note: This requires a composite index: CollectionGroup (lessons) -> lessonId (asc), score (desc)
      final snapshot = await _firestore
          .collectionGroup('lessons')
          .where('lessonId', whereIn: lessonIds)
          .orderBy('score', descending: true)
          .orderBy(FieldPath.documentId) // Deterministic tie-breaker
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No subject rankings found for ids: $lessonIds');
        return [];
      }

      // Fetch user ids
      final lessonDocs = snapshot.docs;
      final userIds = lessonDocs.map((doc) => doc.reference.parent?.parent?.id ?? '').where((id) => id.isNotEmpty).toList();

      // Batch fetch names
      Map<String, String> nameMap = {};
      if (userIds.isNotEmpty) {
        // Handle chunks of 30 if userIds.length > 30 (Firestore limit for whereIn)
        final userSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: userIds.take(30).toList())
            .get();
        for (var doc in userSnapshot.docs) {
          nameMap[doc.id] = doc.data()['name'] ?? 'Kullanıcı';
        }
      }

      final List<RankingUser> rankings = List.generate(lessonDocs.length, (i) {
        final doc = lessonDocs[i];
        final data = doc.data();
        final userId = doc.reference.parent?.parent?.id ?? '';
        
        int score = 0;
        if (data.containsKey('score')) {
          score = (data['score'] ?? 0).toInt();
        } else {
          final solvedQuestions = (data['solvedQuestions'] ?? 0).toInt();
          score = solvedQuestions * 10;
        }

        return RankingUser(
          userId: userId,
          name: nameMap[userId] ?? 'Kullanıcı',
          score: score,
          rank: i + 1,
        );
      });

      return rankings;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        debugPrint('❌ MISSING INDEX for subject ranking! Please create it here:');
        debugPrint(e.message);
      } else {
        debugPrint('Error getting subject rankings: $e');
      }
      return [];
    } catch (e) {
      debugPrint('Error getting subject rankings: $e');
      return [];
    }
  }

  /// Map UI subject names to potential Firestore lesson IDs (highly permissive)
  List<String> _mapSubjectToLessonIds(String subject) {
    switch (subject) {
      case 'Tarih':
        return ['tarih_lesson', 'tarih', 'Tarih', 'Tarih_lesson'];
      case 'Coğrafya':
        return ['cografya_lesson', 'cografya', 'Coğrafya', 'cografya_dersi', 'coğrafya_lesson'];
      case 'Vatandaşlık':
        return ['vatandaslik_lesson', 'vatandaslik', 'Vatandaşlık', 'vatandaslik_dersi'];
      case 'Türkçe':
        return ['turkce_lesson', 'turkce', 'Türkçe', 'turkce_dersi', 'türkçe_lesson'];
      case 'Matematik':
        return ['matematik_lesson', 'matematik', 'Matematik', 'matematik_dersi'];
      case 'Eğitim':
      case 'Eğitim Bilimleri':
        return ['egitim_bilimleri_lesson', 'egitim_bilimleri', 'egitim', 'Eğitim Bilimleri', 'egitim_bilimleri_dersi', 'Eğitim', 'eğitim_bilimleri_lesson'];
      default:
        // Try normalized version as well
        final normalized = subject.toLowerCase().replaceAll(' ', '_');
        return [subject, normalized];
    }
  }

  /// Get current user's general rank
  Future<int> getCurrentUserRank(String userId) async {
    try {
      final userDoc = await _firestore.collection('userProgress').doc(userId).get();
      if (!userDoc.exists) return 0;
      
      final score = userDoc.data()?['totalScore'] as int? ?? 0;
      if (score == 0) return 0;

      // Count users with strictly more points
      final strictlyGreater = await _firestore
          .collection('userProgress')
          .where('totalScore', isGreaterThan: score)
          .count()
          .get();
      
      // Count users with same points but "lower" ID (deterministic tie breaker)
      final tiedBetterIds = await _firestore
          .collection('userProgress')
          .where('totalScore', isEqualTo: score)
          .where(FieldPath.documentId, isLessThan: userId)
          .count()
          .get();

      return (strictlyGreater.count! + tiedBetterIds.count!) + 1;
    } catch (e) {
      debugPrint('Error getting current user rank: $e');
      return 0;
    }
  }

  Future<int> getCurrentUserSubjectScore(String userId, String subjectName) async {
    try {
      final lessonIds = _mapSubjectToLessonIds(subjectName);
      if (lessonIds.isEmpty) return 0;

      // Try each possible ID until one matches
      for (final lId in lessonIds) {
        final doc = await _firestore
            .collection('userProgress')
            .doc(userId)
            .collection('lessons')
            .doc(lId)
            .get();
        
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data.containsKey('score')) {
            return (data['score'] ?? 0).toInt();
          }
          final solved = (data?['solvedQuestions'] ?? 0).toInt();
          return solved * 10;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting current user subject score: $e');
      return 0;
    }
  }

  /// Get current user's rank in a specific subject
  Future<int> getCurrentUserSubjectRank(String userId, String subjectName) async {
    try {
      final lessonIds = _mapSubjectToLessonIds(subjectName);
      if (lessonIds.isEmpty) return 0;

      // Find the correct lesson doc and then count rank
      for (final lId in lessonIds) {
        final doc = await _firestore
            .collection('userProgress')
            .doc(userId)
            .collection('lessons')
            .doc(lId)
            .get();
        
        if (doc.exists) {
          final data = doc.data();
          int currentScore = 0;
          if (data != null && data.containsKey('score')) {
            currentScore = (data['score'] ?? 0).toInt();
          } else {
            final solved = (data?['solvedQuestions'] ?? 0).toInt();
            currentScore = solved * 10;
          }
          
          if (currentScore == 0) return 1; // At least rank 1

          // Rank is: (Strictly better scores) + (Tied scores with lower doc ID) + 1
          final strictlyBetter = await _firestore
              .collectionGroup('lessons')
              .where('lessonId', isEqualTo: lId)
              .where('score', isGreaterThan: currentScore)
              .count()
              .get();

          final tiedBetterIds = await _firestore
              .collectionGroup('lessons')
              .where('lessonId', isEqualTo: lId)
              .where('score', isEqualTo: currentScore)
              .where(FieldPath.documentId, isLessThan: doc.reference.path)
              .count()
              .get();
          
          return (strictlyBetter.count! + (tiedBetterIds.count ?? 0)) + 1;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting current user subject rank: $e');
      return 0;
    }
  }

  /// Get current user's general score
  Future<int> getCurrentUserScore(String userId) async {
    try {
      final userDoc = await _firestore.collection('userProgress').doc(userId).get();
      return userDoc.data()?['totalScore'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
