import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ongoing_video.dart';
import '../models/ongoing_podcast.dart';
import '../models/ongoing_test.dart';

/// Service for managing user progress (videos, podcasts, tests, flash cards)
class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Collection reference for user progress
  CollectionReference get _progressCollection => 
      _firestore.collection('userProgress');

  /// Get user progress document reference
  DocumentReference get _userProgressDoc => 
      _progressCollection.doc(_userId ?? '');

  /// Save video progress
  Future<bool> saveVideoProgress({
    required String videoId,
    required String videoTitle,
    required String topicId,
    required String topicName,
    required String lessonId,
    required Duration currentPosition,
    required Duration totalDuration,
  }) async {
    if (_userId == null) {
      print('⚠️ User not logged in, cannot save progress');
      return false;
    }

    try {
      final progress = currentPosition.inSeconds / totalDuration.inSeconds;
      final currentMinute = currentPosition.inMinutes;
      final totalMinutes = totalDuration.inMinutes;

      // Only save if progress is less than 95% (not completed)
      if (progress >= 0.95) {
        // Video completed, remove from ongoing
        await _userProgressDoc.collection('videos').doc(videoId).delete();
        return true;
      }

      await _userProgressDoc.collection('videos').doc(videoId).set({
        'videoId': videoId,
        'videoTitle': videoTitle,
        'topicId': topicId,
        'topicName': topicName,
        'lessonId': lessonId,
        'currentPosition': currentPosition.inSeconds,
        'totalDuration': totalDuration.inSeconds,
        'currentMinute': currentMinute,
        'totalMinutes': totalMinutes,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Video progress saved: $videoTitle - ${currentMinute}m/${totalMinutes}m');
      return true;
    } catch (e) {
      print('❌ Error saving video progress: $e');
      return false;
    }
  }

  /// Save podcast progress
  Future<bool> savePodcastProgress({
    required String podcastId,
    required String podcastTitle,
    required String? topicId,
    required String? lessonId,
    required Duration currentPosition,
    required Duration totalDuration,
  }) async {
    if (_userId == null) {
      print('⚠️ User not logged in, cannot save progress');
      return false;
    }

    try {
      final progress = currentPosition.inSeconds / totalDuration.inSeconds;
      final currentMinute = currentPosition.inMinutes;
      final totalMinutes = totalDuration.inMinutes;

      // Only save if progress is less than 95% (not completed)
      if (progress >= 0.95) {
        // Podcast completed, remove from ongoing
        await _userProgressDoc.collection('podcasts').doc(podcastId).delete();
        return true;
      }

      await _userProgressDoc.collection('podcasts').doc(podcastId).set({
        'podcastId': podcastId,
        'podcastTitle': podcastTitle,
        'topicId': topicId,
        'lessonId': lessonId,
        'currentPosition': currentPosition.inSeconds,
        'totalDuration': totalDuration.inSeconds,
        'currentMinute': currentMinute,
        'totalMinutes': totalMinutes,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Podcast progress saved: $podcastTitle - ${currentMinute}m/${totalMinutes}m');
      return true;
    } catch (e) {
      print('❌ Error saving podcast progress: $e');
      return false;
    }
  }

  /// Save test progress
  Future<bool> saveTestProgress({
    required String topicId,
    required String topicName,
    required String lessonId,
    required int currentQuestionIndex,
    required int totalQuestions,
  }) async {
    if (_userId == null) {
      print('⚠️ User not logged in, cannot save progress');
      return false;
    }

    try {
      final progress = (currentQuestionIndex + 1) / totalQuestions;

      // Only save if test is not completed
      if (progress >= 1.0) {
        // Test completed, remove from ongoing
        await _userProgressDoc.collection('tests').doc(topicId).delete();
        return true;
      }

      await _userProgressDoc.collection('tests').doc(topicId).set({
        'topicId': topicId,
        'topicName': topicName,
        'lessonId': lessonId,
        'currentQuestionIndex': currentQuestionIndex,
        'totalQuestions': totalQuestions,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Test progress saved: $topicName - ${currentQuestionIndex + 1}/$totalQuestions');
      return true;
    } catch (e) {
      print('❌ Error saving test progress: $e');
      return false;
    }
  }

  /// Save flash card progress
  Future<bool> saveFlashCardProgress({
    required String topicId,
    required String topicName,
    required String lessonId,
    required int currentCardIndex,
    required int totalCards,
  }) async {
    if (_userId == null) {
      print('⚠️ User not logged in, cannot save progress');
      return false;
    }

    try {
      final progress = (currentCardIndex + 1) / totalCards;

      // Only save if not completed
      if (progress >= 1.0) {
        // Completed, remove from ongoing
        await _userProgressDoc.collection('flashCards').doc(topicId).delete();
        return true;
      }

      await _userProgressDoc.collection('flashCards').doc(topicId).set({
        'topicId': topicId,
        'topicName': topicName,
        'lessonId': lessonId,
        'currentCardIndex': currentCardIndex,
        'totalCards': totalCards,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Flash card progress saved: $topicName - ${currentCardIndex + 1}/$totalCards');
      return true;
    } catch (e) {
      print('❌ Error saving flash card progress: $e');
      return false;
    }
  }

  /// Get video progress
  Future<Duration?> getVideoProgress(String videoId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('videos').doc(videoId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['currentPosition'] != null) {
          return Duration(seconds: data['currentPosition'] as int);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting video progress: $e');
      return null;
    }
  }

  /// Get podcast progress
  Future<Duration?> getPodcastProgress(String podcastId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('podcasts').doc(podcastId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['currentPosition'] != null) {
          return Duration(seconds: data['currentPosition'] as int);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting podcast progress: $e');
      return null;
    }
  }

  /// Get test progress
  Future<int?> getTestProgress(String topicId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('tests').doc(topicId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['currentQuestionIndex'] != null) {
          return data['currentQuestionIndex'] as int;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting test progress: $e');
      return null;
    }
  }

  /// Get flash card progress
  Future<int?> getFlashCardProgress(String topicId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('flashCards').doc(topicId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['currentCardIndex'] != null) {
          return data['currentCardIndex'] as int;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting flash card progress: $e');
      return null;
    }
  }

  /// Get all ongoing videos
  Future<List<OngoingVideo>> getOngoingVideos() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc.collection('videos')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OngoingVideo(
          id: data['videoId'] ?? doc.id,
          title: data['videoTitle'] ?? 'Video',
          topic: data['topicName'] ?? '',
          currentMinute: data['currentMinute'] ?? 0,
          totalMinutes: data['totalMinutes'] ?? 1,
          progressColor: 'blue',
          icon: 'play',
          topicId: data['topicId'] ?? '',
          lessonId: data['lessonId'] ?? '',
          videoUrl: '', // Will be loaded from video service
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting ongoing videos: $e');
      return [];
    }
  }

  /// Get all ongoing podcasts
  Future<List<OngoingPodcast>> getOngoingPodcasts() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc.collection('podcasts')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OngoingPodcast(
          id: data['podcastId'] ?? doc.id,
          title: data['podcastTitle'] ?? 'Podcast',
          currentMinute: data['currentMinute'] ?? 0,
          totalMinutes: data['totalMinutes'] ?? 1,
          progressColor: 'blue',
          icon: 'atom',
          topicId: data['topicId'],
          lessonId: data['lessonId'],
          audioUrl: '', // Will be loaded from podcast service
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting ongoing podcasts: $e');
      return [];
    }
  }

  /// Get all ongoing tests
  Future<List<OngoingTest>> getOngoingTests() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc.collection('tests')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OngoingTest(
          id: data['topicId'] ?? doc.id,
          title: '${data['topicName'] ?? 'Test'} Testi',
          topic: data['topicName'] ?? '',
          currentQuestion: (data['currentQuestionIndex'] ?? 0) + 1,
          totalQuestions: data['totalQuestions'] ?? 1,
          progressColor: 'blue',
          icon: 'atom',
          topicId: data['topicId'] ?? doc.id,
          lessonId: data['lessonId'] ?? '',
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting ongoing tests: $e');
      return [];
    }
  }

  /// Delete video progress (when video is completed)
  Future<void> deleteVideoProgress(String videoId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('videos').doc(videoId).delete();
    } catch (e) {
      print('❌ Error deleting video progress: $e');
    }
  }

  /// Delete podcast progress (when podcast is completed)
  Future<void> deletePodcastProgress(String podcastId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('podcasts').doc(podcastId).delete();
    } catch (e) {
      print('❌ Error deleting podcast progress: $e');
    }
  }

  /// Delete test progress (when test is completed)
  Future<void> deleteTestProgress(String topicId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('tests').doc(topicId).delete();
    } catch (e) {
      print('❌ Error deleting test progress: $e');
    }
  }

  /// Delete flash card progress (when completed)
  Future<void> deleteFlashCardProgress(String topicId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('flashCards').doc(topicId).delete();
    } catch (e) {
      print('❌ Error deleting flash card progress: $e');
    }
  }
}

