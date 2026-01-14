import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/ongoing_video.dart';
import '../models/ongoing_podcast.dart';
import '../models/ongoing_test.dart';
import '../models/ongoing_flash_card.dart';
import 'storage_service.dart';
import 'lessons_service.dart';

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
      debugPrint('⚠️ User not logged in, cannot save progress');
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

      debugPrint('✅ Video progress saved: $videoTitle - ${currentMinute}m/${totalMinutes}m');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving video progress: $e');
      return false;
    }
  }

  /// Save podcast progress
  Future<bool> savePodcastProgress({
    required String podcastId,
    required String podcastTitle,
    required String? topicId,
    required String? lessonId,
    required String? topicName,
    required Duration currentPosition,
    required Duration totalDuration,
  }) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot save progress');
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
        'topicName': topicName ?? '',
        'currentPosition': currentPosition.inSeconds,
        'totalDuration': totalDuration.inSeconds,
        'currentMinute': currentMinute,
        'totalMinutes': totalMinutes,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Podcast progress saved: $podcastTitle - ${currentMinute}m/${totalMinutes}m');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving podcast progress: $e');
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
    int? score, // Puan (opsiyonel)
  }) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot save progress');
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

      final data = {
        'topicId': topicId,
        'topicName': topicName,
        'lessonId': lessonId,
        'currentQuestionIndex': currentQuestionIndex,
        'totalQuestions': totalQuestions,
        'progress': progress,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Puan varsa ekle
      if (score != null) {
        data['score'] = score;
      }

      await _userProgressDoc.collection('tests').doc(topicId).set(
        data,
        SetOptions(merge: true),
      );

      debugPrint('✅ Test progress saved: $topicName - ${currentQuestionIndex + 1}/$totalQuestions${score != null ? ' (score: $score)' : ''}');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving test progress: $e');
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
      debugPrint('⚠️ User not logged in, cannot save progress');
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

      debugPrint('✅ Flash card progress saved: $topicName - ${currentCardIndex + 1}/$totalCards');
      return true;
    } catch (e) {
      debugPrint('❌ Error saving flash card progress: $e');
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
      debugPrint('❌ Error getting video progress: $e');
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
      debugPrint('❌ Error getting podcast progress: $e');
      return null;
    }
  }

  /// Get test progress
  Future<int?> getTestProgress(String topicId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('tests').doc(topicId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['currentQuestionIndex'] != null) {
          return data['currentQuestionIndex'] as int;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting test progress: $e');
      return null;
    }
  }

  /// Get test score for a topic
  Future<int?> getTestScore(String topicId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('tests').doc(topicId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['score'] != null) {
          return data['score'] as int;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting test score: $e');
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
      debugPrint('❌ Error getting flash card progress: $e');
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

      final videos = <OngoingVideo>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final videoId = data['videoId'] ?? doc.id;
        final topicId = data['topicId'] ?? '';
        final lessonId = data['lessonId'] ?? '';
        
        // Video URL'ini progress data'dan al (eğer kaydedilmişse)
        String videoUrl = data['videoUrl'] ?? '';
        
        // Eğer videoUrl boşsa, storage'dan yükle (yavaş ama gerekli)
        if (videoUrl.isEmpty && topicId.isNotEmpty && lessonId.isNotEmpty) {
          try {
            // StorageService kullanarak video URL'ini yükle
            final storageService = StorageService();
            final lessonsService = LessonsService();
            
            final lesson = await lessonsService.getLessonById(lessonId);
            if (lesson != null) {
              final lessonNameForPath = lesson.name
                  .toLowerCase()
                  .replaceAll(' ', '_')
                  .replaceAll('ı', 'i')
                  .replaceAll('ğ', 'g')
                  .replaceAll('ü', 'u')
                  .replaceAll('ş', 's')
                  .replaceAll('ö', 'o')
                  .replaceAll('ç', 'c');
              
              final topicFolderName = topicId.startsWith('${lessonId}_')
                  ? topicId.substring('${lessonId}_'.length)
                  : '';
              
              if (topicFolderName.isNotEmpty) {
                String storagePath = 'dersler/$lessonNameForPath/konular/$topicFolderName/video';
                final videoUrls = await storageService.listVideoFiles(storagePath);
                
                // Video ID'den index çıkar (video_${topicId}_$index formatından)
                if (videoId.contains('_')) {
                  final parts = videoId.split('_');
                  if (parts.length >= 3) {
                    final indexStr = parts.last;
                    final index = int.tryParse(indexStr) ?? 0;
                    if (index >= 0 && index < videoUrls.length) {
                      videoUrl = videoUrls[index];
                    }
                  }
                }
                
                // Eğer hala boşsa, ilk videoyu al
                if (videoUrl.isEmpty && videoUrls.isNotEmpty) {
                  videoUrl = videoUrls[0];
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error loading video URL for $videoId: $e');
          }
        }
        
        videos.add(OngoingVideo(
          id: videoId,
          title: data['videoTitle'] ?? 'Video',
          topic: data['topicName'] ?? '',
          currentMinute: data['currentMinute'] ?? 0,
          totalMinutes: data['totalMinutes'] ?? 1,
          progressColor: 'blue',
          icon: 'play',
          topicId: topicId,
          lessonId: lessonId,
          videoUrl: videoUrl,
        ));
      }
      
      return videos;
    } catch (e) {
      debugPrint('❌ Error getting ongoing videos: $e');
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
          topic: data['topicName'] ?? '',
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
      debugPrint('❌ Error getting ongoing podcasts: $e');
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
          score: data['score'] ?? 0, // Puanı oku
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting ongoing tests: $e');
      return [];
    }
  }

  /// Delete video progress (when video is completed)
  Future<void> deleteVideoProgress(String videoId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('videos').doc(videoId).delete();
    } catch (e) {
      debugPrint('❌ Error deleting video progress: $e');
    }
  }

  /// Delete podcast progress (when podcast is completed)
  Future<void> deletePodcastProgress(String podcastId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('podcasts').doc(podcastId).delete();
    } catch (e) {
      debugPrint('❌ Error deleting podcast progress: $e');
    }
  }

  /// Delete test progress (when test is completed)
  Future<void> deleteTestProgress(String topicId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('tests').doc(topicId).delete();
    } catch (e) {
      debugPrint('❌ Error deleting test progress: $e');
    }
  }

  /// Get all ongoing flash cards
  Future<List<OngoingFlashCard>> getOngoingFlashCards() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc.collection('flashCards')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return OngoingFlashCard(
          id: data['topicId'] ?? doc.id,
          title: '${data['topicName'] ?? 'Bilgi Kartları'}',
          topic: data['topicName'] ?? '',
          currentCard: (data['currentCardIndex'] ?? 0) + 1,
          totalCards: data['totalCards'] ?? 1,
          progressColor: 'green',
          icon: 'book',
          topicId: data['topicId'] ?? doc.id,
          lessonId: data['lessonId'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting ongoing flash cards: $e');
      return [];
    }
  }

  /// Get user total score
  Future<int> getUserTotalScore() async {
    if (_userId == null) return 0;
    
    try {
      final doc = await _userProgressDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['totalScore'] != null) {
          return data['totalScore'] as int;
        }
      }
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting user total score: $e');
      return 0;
    }
  }

  /// Add score to user total score
  Future<bool> addScore(int scoreToAdd) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot add score');
      return false;
    }

    try {
      final currentScore = await getUserTotalScore();
      final newScore = currentScore + scoreToAdd;
      
      await _userProgressDoc.set({
        'totalScore': newScore,
        'lastScoreUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Score added: +$scoreToAdd (Total: $newScore)');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding score: $e');
      return false;
    }
  }

  /// Delete flash card progress (when completed)
  Future<void> deleteFlashCardProgress(String topicId) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('flashCards').doc(topicId).delete();
    } catch (e) {
      debugPrint('❌ Error deleting flash card progress: $e');
    }
  }
}

