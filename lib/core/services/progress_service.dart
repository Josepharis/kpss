import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ongoing_video.dart';
import '../models/ongoing_podcast.dart';
import '../models/ongoing_test.dart';
import '../models/ongoing_flash_card.dart';
import 'storage_service.dart';
import 'lessons_service.dart';
import 'pomodoro_storage_service.dart';

/// Service for managing user progress (videos, podcasts, tests, flash cards)
class ProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user statistics to avoid redundant Firestore reads
  static Map<String, int>? _cachedStats;
  static bool _statsDirty = true;
  static String? _lastUserId;

  /// Mark statistics as dirty so they are re-fetched next time
  static void markStatsDirty() {
    _statsDirty = true;
  }

  /// Collection reference for user progress summary
  DocumentReference get _userStatsDoc =>
      _userProgressDoc.collection('metadata').doc('statistics');

  /// Clear the statistics cache (e.g., on logout)
  static void clearStatsCache() {
    _cachedStats = null;
    _statsDirty = true;
    _lastUserId = null;
  }

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

      debugPrint(
        '✅ Video progress saved: $videoTitle - ${currentMinute}m/${totalMinutes}m',
      );
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

      debugPrint(
        '✅ Podcast progress saved: $podcastTitle - ${currentMinute}m/${totalMinutes}m',
      );
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
    int? score,
    int? correctAnswers,
    int? wrongAnswers,
    int attemptCount = 1,
    List<int?>? answers,
  }) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot save progress');
      debugPrint('⚠️ Current user: ${_auth.currentUser?.uid ?? "null"}');
      return false;
    }

    try {
      final progress = (currentQuestionIndex + 1) / totalQuestions;

      // Eğer test bittiyse (tüm sorular cevaplandıysa), devam edenlerden sil
      if (progress >= 1.0) {
        debugPrint('🏁 Test completed, removing from ongoing: $topicId');
        await deleteTestProgress(topicId, lessonId);

        // Save test result to testResults collection for permanent history
        await _userProgressDoc.collection('testResults').doc(topicId).set({
          'topicId': topicId,
          'topicName': topicName,
          'lessonId': lessonId,
          'totalQuestions': totalQuestions,
          'correctAnswers': correctAnswers ?? 0,
          'wrongAnswers': wrongAnswers ?? 0,
          'score': score ?? 0,
          'attemptCount': attemptCount,
          'lastCompleted': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update aggregated stats
        await _updateAggregatedStats(
          correctToAdd: correctAnswers ?? 0,
          wrongToAdd: wrongAnswers ?? 0,
          testCompleted: true,
        );

        return true;
      }

      final data = {
        'topicId': topicId,
        'topicName': topicName,
        'lessonId': lessonId,
        'currentQuestionIndex': currentQuestionIndex,
        'totalQuestions': totalQuestions,
        'progress': progress,
        'attemptCount': attemptCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        if (answers != null) 'answers': answers,
      };

      // Puan, doğru ve yanlış sayılarını ekle
      if (score != null) data['score'] = score;
      if (correctAnswers != null) data['correctAnswers'] = correctAnswers;
      if (wrongAnswers != null) data['wrongAnswers'] = wrongAnswers;

      final docRef = _userProgressDoc.collection('tests').doc(topicId);
      await docRef.set(data, SetOptions(merge: true));

      // Mark stats as dirty because we updated ongoing test progress
      markStatsDirty();

      // Verify it was saved
      final savedDoc = await docRef.get();
      if (savedDoc.exists) {
        debugPrint(
          '✅ Test progress saved successfully: $topicName - ${currentQuestionIndex + 1}/$totalQuestions${score != null ? ' (score: $score)' : ''}',
        );
        // Update lesson progress in background (non-blocking)
        _updateLessonProgress(lessonId);
      } else {
        debugPrint(
          '❌ Failed to save test progress - document does not exist after save',
        );
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving test progress: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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

      debugPrint(
        '✅ Flash card progress saved: $topicName - ${currentCardIndex + 1}/$totalCards',
      );
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
      final doc = await _userProgressDoc
          .collection('videos')
          .doc(videoId)
          .get();
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
      final doc = await _userProgressDoc
          .collection('podcasts')
          .doc(podcastId)
          .get();
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
  Future<Map<String, dynamic>?> getTestProgress(String topicId) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot get test progress');
      return null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'test_progress_cache_${_userId}_$topicId';

      // 1. Try Cache First
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        return data;
      }

      // 2. Fallback to Firestore
      final doc = await _userProgressDoc.collection('tests').doc(topicId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final result = {
            ...data,
            'index': data['currentQuestionIndex'] ?? 0,
            'score': data['score'] ?? 0,
            'answers': data['answers'] as List<dynamic>?,
          };
          // Save to cache
          await prefs.setString(cacheKey, jsonEncode(result));
          return result;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get test score for a topic
  Future<int?> getTestScore(String topicId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc.collection('tests').doc(topicId).get();
      if (doc.exists) {
        final data = doc.data();
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

  /// Get completed test result for a topic
  Future<Map<String, int>?> getTestResult(String topicId) async {
    if (_userId == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'test_result_cache_${_userId}_$topicId';

      // Try Cache First
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final Map<String, dynamic> data = jsonDecode(cachedData);
        return data.cast<String, int>();
      }

      final doc = await _userProgressDoc
          .collection('testResults')
          .doc(topicId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final result = {
            'totalQuestions': data['totalQuestions'] as int? ?? 0,
            'correctAnswers': data['correctAnswers'] as int? ?? 0,
            'wrongAnswers': data['wrongAnswers'] as int? ?? 0,
            'attemptCount': data['attemptCount'] as int? ?? 1,
          };
          // Save to Cache
          await prefs.setString(cacheKey, jsonEncode(result));
          return result;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting test result: $e');
      return null;
    }
  }

  /// Get flash card progress
  Future<int?> getFlashCardProgress(String topicId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc
          .collection('flashCards')
          .doc(topicId)
          .get();
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
      final snapshot = await _userProgressDoc
          .collection('videos')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      final videos = <OngoingVideo>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final progress = data['progress'] as double? ?? 0.0;

        // Tamamlanmış (progress >= 0.95) olanları dısla
        if (progress >= 0.95) continue;

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
                String storagePath =
                    'dersler/$lessonNameForPath/konular/$topicFolderName/video';
                final videoUrls = await storageService.listVideoFiles(
                  storagePath,
                );

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

        videos.add(
          OngoingVideo(
            id: videoId,
            title: data['videoTitle'] ?? 'Video',
            topic: data['topicName'] ?? '',
            currentMinute: data['currentMinute'] ?? 0,
            totalMinutes: data['totalMinutes'] ?? 1,
            progressColor: 'red',
            icon: 'play',
            topicId: topicId,
            lessonId: lessonId,
            videoUrl: videoUrl,
          ),
        );
      }

      return videos
          .where((v) => (v.currentMinute / v.totalMinutes) < 0.95)
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting ongoing videos: $e');
      return [];
    }
  }

  /// Get all ongoing podcasts
  Future<List<OngoingPodcast>> getOngoingPodcasts() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc
          .collection('podcasts')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      final podcasts = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final progress = data['progress'] as double? ?? 0.0;
            return progress < 0.95;
          })
          .map((doc) {
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
          })
          .toList();

      return podcasts;
    } catch (e) {
      debugPrint('❌ Error getting ongoing podcasts: $e');
      return [];
    }
  }

  /// Get all ongoing tests
  Future<List<OngoingTest>> getOngoingTests() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc
          .collection('tests')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      final tests = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final progress = data['progress'] as double? ?? 0.0;
            return progress < 1.0;
          })
          .map((doc) {
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
              score: data['score'] ?? 0,
              attemptCount: data['attemptCount'] ?? 1,
            );
          })
          .toList();

      return tests;
    } catch (e) {
      debugPrint('❌ Error getting ongoing tests: $e');
      return [];
    }
  }

  /// Delete video progress (when video is completed)
  Future<void> deleteVideoProgress(String videoId, [String? lessonId]) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('videos').doc(videoId).delete();
      if (lessonId != null) {
        _updateLessonProgress(lessonId);
      }
    } catch (e) {
      debugPrint('❌ Error deleting video progress: $e');
    }
  }

  /// Delete podcast progress (when podcast is completed)
  Future<void> deletePodcastProgress(
    String podcastId, [
    String? lessonId,
  ]) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('podcasts').doc(podcastId).delete();
      if (lessonId != null) {
        _updateLessonProgress(lessonId);
      }
    } catch (e) {
      debugPrint('❌ Error deleting podcast progress: $e');
    }
  }

  /// Delete test progress (when test is completed)
  Future<void> deleteTestProgress(String topicId, [String? lessonId]) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('tests').doc(topicId).delete();
      if (lessonId != null) {
        _updateLessonProgress(lessonId);
      }
    } catch (e) {
      debugPrint('❌ Error deleting test progress: $e');
    }
  }

  /// Get all ongoing flash cards
  Future<List<OngoingFlashCard>> getOngoingFlashCards() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _userProgressDoc
          .collection('flashCards')
          .orderBy('lastUpdated', descending: true)
          .limit(10)
          .get();

      final flashCards = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final progress = data['progress'] as double? ?? 0.0;
            return progress < 1.0;
          })
          .map((doc) {
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
          })
          .toList();

      return flashCards;
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

      // Mark stats as dirty as totalScore might affect correct count
      markStatsDirty();

      debugPrint('✅ Score added: +$scoreToAdd (Total: $newScore)');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding score: $e');
      return false;
    }
  }

  /// Delete flash card progress (when completed)
  Future<void> deleteFlashCardProgress(
    String topicId, [
    String? lessonId,
  ]) async {
    if (_userId == null) return;
    try {
      await _userProgressDoc.collection('flashCards').doc(topicId).delete();
      if (lessonId != null) {
        _updateLessonProgress(lessonId);
      }
    } catch (e) {
      debugPrint('❌ Error deleting flash card progress: $e');
    }
  }

  /// Get user statistics (solved questions, correct, wrong, total)
  Future<Map<String, int>> getUserStatistics() async {
    if (_userId == null) {
      return {
        'solvedQuestions': 0,
        'correctAnswers': 0,
        'wrongAnswers': 0,
        'totalQuestions': 0,
      };
    }

    // Check cache first
    if (!_statsDirty && _cachedStats != null && _lastUserId == _userId) {
      debugPrint('ℹ️ Returning cached user statistics');
      return _cachedStats!;
    }

    try {
      // Try to get from aggregated metadata first (Professional way)
      final statsDoc = await _userStatsDoc.get();
      if (statsDoc.exists) {
        final data = statsDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          final stats = {
            'solvedQuestions': data['solvedQuestions'] as int? ?? 0,
            'correctAnswers': data['correctAnswers'] as int? ?? 0,
            'wrongAnswers': data['wrongAnswers'] as int? ?? 0,
            'totalQuestions': data['totalQuestions'] as int? ?? 0,
          };
          _cachedStats = stats;
          _statsDirty = false;
          _lastUserId = _userId;
          return stats;
        }
      }

      // Fallback: Calculate from scratch (and then save to aggregated doc)
      int totalCorrect = 0;
      int totalWrong = 0;
      int totalSolved = 0;

      // 1. Get completed test results
      try {
        final resultsSnapshot = await _userProgressDoc
            .collection('testResults')
            .get();

        for (var doc in resultsSnapshot.docs) {
          final data = doc.data();
          final correct = data['correctAnswers'] as int? ?? 0;
          final wrong = data['wrongAnswers'] as int? ?? 0;
          totalCorrect += correct;
          totalWrong += wrong;
        }
      } catch (e) {
        debugPrint('⚠️ Error reading test results: $e');
      }

      // 2. Get ongoing test progress
      try {
        final ongoingSnapshot = await _userProgressDoc
            .collection('tests')
            .get();

        for (var doc in ongoingSnapshot.docs) {
          final data = doc.data();
          // Yeni eklediğimiz alanları kullan, yoksa score'dan tahmin et
          int correct = data['correctAnswers'] as int? ?? 0;
          if (correct == 0 && data['score'] != null) {
            correct = (data['score'] as int) ~/ 10;
          }

          int wrong = data['wrongAnswers'] as int? ?? 0;

          totalCorrect += correct;
          totalWrong += wrong;
        }
      } catch (e) {
        debugPrint('⚠️ Error reading ongoing tests: $e');
      }

      // 3. Get Pomodoro session statistics
      try {
        final pomodoroService = PomodoroStorageService();
        final sessions = await pomodoroService.getAllSessions();
        for (var session in sessions) {
          totalCorrect += session.correctAnswers ?? 0;
          totalWrong += session.wrongAnswers ?? 0;
        }
      } catch (e) {
        debugPrint('⚠️ Error reading pomodoro sessions: $e');
      }

      // Solved questions is the sum of correct and wrong
      totalSolved = totalCorrect + totalWrong;

      // 4. Sync with global totalScore if needed
      // totalScore should ideally be exactly totalCorrect * 10
      // Note: Pomodoro corrects might not be added to totalScore automatically depending on app logic.
      final totalScore = await getUserTotalScore();
      final scoreCorrects = totalScore ~/ 10;

      // If score-based corrects are higher, use that (it's updated instantly)
      if (scoreCorrects > totalCorrect) {
        totalCorrect = scoreCorrects;
        totalSolved = totalCorrect + totalWrong;
      }

      final statsResult = {
        'solvedQuestions': totalSolved,
        'correctAnswers': totalCorrect,
        'wrongAnswers': totalWrong,
        'totalQuestions': totalSolved,
      };

      // Update cache
      _cachedStats = statsResult;
      _statsDirty = false;
      _lastUserId = _userId;

      // Save to aggregated doc for next time
      await _userStatsDoc.set({
        ...statsResult,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return statsResult;
    } catch (e) {
      debugPrint('❌ Error getting user statistics: $e');
      return {
        'solvedQuestions': 0,
        'correctAnswers': 0,
        'wrongAnswers': 0,
        'totalQuestions': 0,
      };
    }
  }

  /// Save test result (when test is completed)
  Future<bool> saveTestResult({
    required String topicId,
    required String topicName,
    required String lessonId,
    required int totalQuestions,
    required int correctAnswers,
    required int wrongAnswers,
    required int score,
  }) async {
    if (_userId == null) {
      debugPrint('⚠️ User not logged in, cannot save test result');
      return false;
    }

    try {
      // 1. Check existing result to increment attemptCount
      final existingDoc = await _userProgressDoc
          .collection('testResults')
          .doc(topicId)
          .get();
      int attemptCount = 1;

      if (existingDoc.exists) {
        final existingData = existingDoc.data();
        if (existingData != null) {
          attemptCount = (existingData['attemptCount'] as int? ?? 1) + 1;
        }
      }

      // 1. Save to Firestore
      await _userProgressDoc.collection('testResults').doc(topicId).set({
        'topicId': topicId,
        'topicName': topicName,
        'lessonId': lessonId,
        'totalQuestions': totalQuestions,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'score': score,
        'attemptCount': attemptCount,
        'lastCompleted': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Save to local cache for instant retrieval
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'test_result_cache_${_userId}_$topicId';
      await prefs.setString(
        cacheKey,
        jsonEncode({
          'totalQuestions': totalQuestions,
          'correctAnswers': correctAnswers,
          'wrongAnswers': wrongAnswers,
          'attemptCount': attemptCount,
        }),
      );

      debugPrint(
        '✅ Test result saved: $topicName - $correctAnswers/$totalQuestions',
      );

      // Update aggregated stats
      await _updateAggregatedStats(
        correctToAdd: correctAnswers,
        wrongToAdd: wrongAnswers,
        testCompleted: true,
      );

      // Mark stats as dirty
      markStatsDirty();
      // Update lesson progress in background
      _updateLessonProgress(lessonId);
      return true;
    } catch (e) {
      debugPrint('❌ Error saving test result: $e');
      return false;
    }
  }

  Future<void> _updateLessonProgress(String lessonId) async {
    if (_userId == null) return;

    try {
      // Get all topics for this lesson
      final lessonsService = LessonsService();
      final topics = await lessonsService.getTopicsByLessonId(lessonId);
      if (topics.isEmpty) return;

      // 1. Fetch all test results for THIS lesson in one go
      final resultsSnapshot = await _userProgressDoc
          .collection('testResults')
          .where('lessonId', isEqualTo: lessonId)
          .get();

      // 2. Fetch all ongoing test progress for THIS lesson in one go
      final progressSnapshot = await _userProgressDoc
          .collection('tests')
          .where('lessonId', isEqualTo: lessonId)
          .get();

      // Create maps for quick lookup
      final Map<String, Map<String, dynamic>> resultsMap = {
        for (var doc in resultsSnapshot.docs) doc.id: doc.data(),
      };
      final Map<String, Map<String, dynamic>> progressMap = {
        for (var doc in progressSnapshot.docs) doc.id: doc.data(),
      };

      int totalSolvedQuestions = 0;
      int totalQuestions = 0;

      for (var topic in topics) {
        int topicQuestionCount = topic.averageQuestionCount;

        // Get from cache if available (synchronous preference)
        if (topicQuestionCount <= 0) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final cacheKey = 'content_counts_${topic.id}';
            final cachedJson = prefs.getString(cacheKey);
            if (cachedJson != null) {
              final Map<String, dynamic> counts = jsonDecode(cachedJson);
              topicQuestionCount = counts['testQuestionCount'] as int? ?? 0;
            }
          } catch (_) {}
        }

        if (topicQuestionCount > 0) {
          totalQuestions += topicQuestionCount;

          // Check bulk maps instead of making individual Firestore calls
          if (resultsMap.containsKey(topic.id)) {
            final result = resultsMap[topic.id]!;
            totalSolvedQuestions += result['totalQuestions'] as int? ?? 0;
          } else if (progressMap.containsKey(topic.id)) {
            final progress = progressMap[topic.id]!;
            if (progress['currentQuestionIndex'] != null) {
              totalSolvedQuestions +=
                  (progress['currentQuestionIndex'] as int) + 1;
            }
          }
        }
      }

      // Calculate and save lesson progress
      double progress = 0.0;
      if (totalQuestions > 0) {
        progress = (totalSolvedQuestions / totalQuestions).clamp(0.0, 1.0);
      }

      await _userProgressDoc.collection('lessons').doc(lessonId).set({
        'lessonId': lessonId,
        'progress': progress,
        'solvedQuestions': totalSolvedQuestions,
        'totalQuestions': totalQuestions,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error updating lesson progress: $e');
    }
  }

  /// Get lesson progress (from cache)
  Future<double?> getLessonProgress(String lessonId) async {
    if (_userId == null) return null;

    try {
      final doc = await _userProgressDoc
          .collection('lessons')
          .doc(lessonId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['progress'] != null) {
          return (data['progress'] as num).toDouble();
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream lesson progress (real-time updates)
  Stream<double?> streamLessonProgress(String lessonId) {
    if (_userId == null) {
      return Stream.value(null);
    }

    return _userProgressDoc.collection('lessons').doc(lessonId).snapshots().map(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data['progress'] != null) {
            return (data['progress'] as num).toDouble();
          }
        }
        return null;
      },
    );
  }

  /// Update aggregated statistics in Firestore
  Future<void> _updateAggregatedStats({
    int correctToAdd = 0,
    int wrongToAdd = 0,
    bool testCompleted = false,
  }) async {
    if (_userId == null) return;

    try {
      final doc = await _userStatsDoc.get();
      if (!doc.exists) {
        // Initial create - trigger a full recalculation to be sure
        await getUserStatistics();
        return;
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};
      int solved = data['solvedQuestions'] as int? ?? 0;
      int correct = data['correctAnswers'] as int? ?? 0;
      int wrong = data['wrongAnswers'] as int? ?? 0;
      int completedTests = data['completedTestsCount'] as int? ?? 0;

      solved += (correctToAdd + wrongToAdd);
      correct += correctToAdd;
      wrong += wrongToAdd;
      if (testCompleted) completedTests += 1;

      await _userStatsDoc.set({
        'solvedQuestions': solved,
        'correctAnswers': correct,
        'wrongAnswers': wrong,
        'totalQuestions': solved, // In this app totalSolved = totalQuestions
        'completedTestsCount': completedTests,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Refresh cache
      _statsDirty = true;
    } catch (e) {
      debugPrint('⚠️ Error updating aggregated stats: $e');
    }
  }
}
