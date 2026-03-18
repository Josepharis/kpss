import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/test_question.dart';
import 'storage_service.dart';
import 'lessons_service.dart';

/// Service for managing questions from Firestore and Storage
class QuestionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();
  final LessonsService _lessonsService = LessonsService();

  // Collection reference
  CollectionReference get _questionsCollection =>
      _firestore.collection('questions');

  Future<List<TestQuestion>> getQuestionsByTopicId(
    String topicId, {
    required String lessonId,
    String? testFileName,
  }) async {
    try {
      // 1. Try Cache first
      final cachedQuestions = await _loadQuestionsFromCache(
        topicId,
        testFileName: testFileName,
      );
      if (cachedQuestions.isNotEmpty) {
        debugPrint(
          '📦 Questions loaded from cache for topic: $topicId, file: $testFileName',
        );
        // Arka planda güncelle (non-blocking) - background update logic should be refined for specific files if needed
        return cachedQuestions;
      }

      // 2. Load from Storage
      final storageQuestions = await _loadQuestionsFromStorage(
        topicId,
        lessonId,
        testFileName: testFileName,
      );

      if (storageQuestions.isNotEmpty) {
        debugPrint(
          '✅ Loaded ${storageQuestions.length} questions from Storage (topic: $topicId, file: $testFileName)',
        );
        // Cache storage questions
        await _saveQuestionsToCache(
          topicId,
          storageQuestions,
          testFileName: testFileName,
        );
        return storageQuestions;
      }

      // 3. Fallback to Firestore (Yedek olarak)
      if (testFileName == null) {
        final snapshot = await _questionsCollection
            .where('topicId', isEqualTo: topicId)
            .get();
        final firestoreQuestions = snapshot.docs
            .map(
              (doc) => TestQuestion.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();

        if (firestoreQuestions.isNotEmpty) {
          debugPrint('🔥 Questions loaded from Firestore for topic: $topicId');
          await _saveQuestionsToCache(topicId, firestoreQuestions);
          return firestoreQuestions;
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error fetching questions for topic $topicId: $e');
      return [];
    }
  }

  /// Load questions from local cache
  Future<List<TestQuestion>> _loadQuestionsFromCache(
    String topicId, {
    String? testFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = testFileName != null
          ? 'questions_${topicId}_$testFileName'
          : 'questions_$topicId';
      final cachedJson = prefs.getString(cacheKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        final questions = cachedList
            .map(
              (json) => TestQuestion.fromMap(
                json as Map<String, dynamic>,
                json['id'] ?? '',
              ),
            )
            .toList();
        debugPrint(
          '✅ Loaded ${questions.length} questions from cache ($cacheKey)',
        );
        return questions;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Save questions to local cache
  Future<void> _saveQuestionsToCache(
    String topicId,
    List<TestQuestion> questions, {
    String? testFileName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = testFileName != null
          ? 'questions_${topicId}_$testFileName'
          : 'questions_$topicId';
      final jsonList = questions.map((q) => q.toMap()..['id'] = q.id).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(cacheKey, jsonString);

      // Soru sayısını da ayrı bir key ile kaydet (hızlı erişim için)
      final countKey = testFileName != null
          ? 'questions_count_${topicId}_$testFileName'
          : 'questions_count_$topicId';
      await prefs.setInt(countKey, questions.length);

      debugPrint('✅ Saved ${questions.length} questions to cache ($cacheKey)');
    } catch (e) {
      debugPrint('⚠️ Error saving questions to cache: $e');
    }
  }

  /// Sadece soru sayısını hesaplar/çeker, tüm soruları (Test objelerini) cache'e KAYDETMEZ.
  /// Initial sync gibi uygulamayı yormaması gereken yerlerde kullanılır.
  Future<int> syncQuestionCount(String topicId, String lessonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countKey = 'questions_count_$topicId';

      // 1. Önce cache'de soru sayısı var mı kontrol et
      final cachedCount = prefs.getInt(countKey);
      if (cachedCount != null && cachedCount > 0) {
        return cachedCount;
      }

      // 2. Cache'de yoksa Storage'dan JSON indirip sadece boyutuna bakarak sayıyı hesapla
      final storageQuestions = await _loadQuestionsFromStorage(
        topicId,
        lessonId,
      );
      final count = storageQuestions.length;

      // 3. Sadece sayıyı cache'e yaz. Tüm soruları JSON dizi string'i olarak YAZMA.
      if (count > 0) {
        await prefs.setInt(countKey, count);

        // Firestore update
        await _firestore
            .collection('topics')
            .doc(topicId)
            .update({'averageQuestionCount': count})
            .catchError((_) => null);

        debugPrint(
          '✅ Sadece soru sayısı tespit edildi ve sayı cache\'lendi: $count for topic $topicId (Sorular cache edilmedi)',
        );
      }

      return count;
    } catch (e) {
      debugPrint('⚠️ Error syncing question count for $topicId: $e');
      return 0;
    }
  }

  void _updateTestsListInBackground(String topicId, String lessonId) {
    _fetchAndCacheAvailableTests(topicId, lessonId)
        .then((_) {
          debugPrint('✅ Background update finished for tests list: $topicId');
        })
        .catchError((e) {
          debugPrint('⚠️ Background update failed for tests list: $e');
        });
  }

  /// Load questions from Storage (soru folder)
  /// If testFileName is provided, load only that file.
  /// Otherwise, load and merge all JSON files (legacy behavior).
  Future<List<TestQuestion>> _loadQuestionsFromStorage(
    String topicId,
    String lessonId, {
    String? testFileName,
  }) async {
    try {
      // Get lesson to construct path
      final lesson = await _lessonsService.getLessonById(lessonId);
      if (lesson == null) {
        debugPrint('⚠️ Lesson not found: $lessonId');
        return [];
      }

      // Convert lesson name to path format
      final lessonNameForPath = lesson.name
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');

      // Get topic base path
      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: lessonId,
        topicId: topicId,
        lessonNameForPath: lessonNameForPath,
      );

      // Check for soru folder
      final soruPath = '$basePath/soru';

      List<String> jsonUrls = [];
      if (testFileName != null) {
        // Construct URL for specific file or just use the name if StorageService supports it
        // Actually, let's list them and find the matching one to be safe
        final allJsonFiles = await _storageService.listFilesWithPaths(soruPath);
        final matchingFile = allJsonFiles.firstWhere(
          (f) => f['name'] == testFileName,
          orElse: () => {},
        );
        if (matchingFile.isNotEmpty && matchingFile['url'] != null) {
          jsonUrls = [matchingFile['url']!];
        }
      } else {
        // List all JSON files in soru folder
        jsonUrls = await _storageService.listJsonFiles(soruPath);
      }

      if (jsonUrls.isEmpty) {
        return [];
      }

      // Coğrafya dersi için görselleri kontrol et
      Map<String, String> imageUrls = {};
      final isGeography = lesson.name
          .toLowerCase()
          .replaceAll('ğ', 'g')
          .contains('cografya');

      if (isGeography) {
        final gorselPath = '$soruPath/gorsel';
        debugPrint('🔍 Görsel klasörü kontrol ediliyor: $gorselPath');
        try {
          final imageFiles = await _storageService.listFilesWithPaths(
            gorselPath,
          );
          debugPrint('📸 Klasörde ${imageFiles.length} adet görsel bulundu.');
          for (final file in imageFiles) {
            // "1.jpg" veya "1.PNG" -> "1" (küçük harf duyarlı eşleşme için)
            final rawName = file['name'];
            if (rawName == null) continue;

            final fileName = rawName.toLowerCase().split('.').first;
            if (file['url'] != null) {
              imageUrls[fileName] = file['url']!;
              debugPrint('🔗 Görsel bulundu: $fileName');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Görseller yüklenirken hata oluştu: $e');
        }
      }

      // Parse all JSON files and combine questions
      final List<TestQuestion> allQuestions = [];

      for (final jsonUrl in jsonUrls) {
        try {
          // Extract storage path from URL or use URL directly
          String? storagePath;
          try {
            // Try to extract path from Storage URL
            final uri = Uri.parse(jsonUrl);
            if (uri.path.contains('/o/')) {
              // Firebase Storage URL format: .../o/path%2Fto%2Ffile.json?alt=media&token=...
              final pathPart = uri.path.split('/o/').last.split('?').first;
              storagePath = Uri.decodeComponent(pathPart);
            } else {
              // Try to get path from URL using StorageService helper
              storagePath = _storageService.getPathFromUrl(jsonUrl);
            }
          } catch (e) {
            debugPrint(
              '⚠️ Could not extract path from URL, trying direct download: $e',
            );
            // Try to download directly from URL
            final jsonData = await _storageService.downloadAndParseJsonFromUrl(
              jsonUrl,
            );
            if (jsonData != null) {
              final questions = _parseJsonQuestions(
                jsonData,
                topicId,
                lessonId,
                imageUrls: imageUrls,
              );
              allQuestions.addAll(questions);
              continue;
            }
          }

          if (storagePath != null) {
            final jsonData = await _storageService.downloadAndParseJson(
              storagePath,
            );
            if (jsonData != null) {
              final questions = _parseJsonQuestions(
                jsonData,
                topicId,
                lessonId,
                imageUrls: imageUrls,
              );
              allQuestions.addAll(questions);
            }
          }
        } catch (e) {
          // Error parsing JSON file
        }
      }

      // Sort by order (id)
      allQuestions.sort((a, b) {
        // Extract numeric id from question id
        final aId = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final bId = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        return aId.compareTo(bId);
      });

      return allQuestions;
    } catch (e) {
      return [];
    }
  }

  /// Get available tests (metadata only) for a topic
  Future<List<Map<String, dynamic>>> getAvailableTestsByTopic(
    String topicId,
    String lessonId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listCacheKey = 'tests_list_cache_$topicId';

      // 1. Check for cached list first for instant UI response
      final cachedListJson = prefs.getString(listCacheKey);
      if (cachedListJson != null && cachedListJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(cachedListJson);
          final List<Map<String, dynamic>> cachedList = decoded
              .where((e) => e is Map)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          // Return cached list immediately
          debugPrint('📦 Returning cached tests list for topic: $topicId');

          // Trigger background update to keep data fresh if it's been more than 1 hour
          final lastSync = prefs.getInt('${listCacheKey}_time') ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastSync > 1000 * 60 * 60) {
            _updateTestsListInBackground(topicId, lessonId);
          }

          return cachedList;
        } catch (e) {
          debugPrint('⚠️ Error decoding cached tests list: $e');
        }
      }

      // 2. No cache or error, perform full fetch
      return await _fetchAndCacheAvailableTests(topicId, lessonId);
    } catch (e) {
      debugPrint('Error getting available tests: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAndCacheAvailableTests(
    String topicId,
    String lessonId,
  ) async {
    try {
      final lesson = await _lessonsService.getLessonById(lessonId);
      if (lesson == null) return [];

      final lessonNameForPath = _lessonsService.normalizeForStoragePath(
        lesson.name,
      );
      final basePath = await _lessonsService.getTopicBasePath(
        lessonId: lessonId,
        topicId: topicId,
        lessonNameForPath: lessonNameForPath,
      );

      final soruPath = '$basePath/soru';
      final files = await _storageService.listFilesWithPaths(soruPath);

      final List<Map<String, dynamic>> tests = [];
      final prefs = await SharedPreferences.getInstance();

      for (final file in files) {
        final fileName = file['name'];
        final url = file['url'];

        if (fileName != null &&
            url != null &&
            fileName.toLowerCase().endsWith('.json')) {
          String displayName = fileName.replaceAll('.json', '');
          int testNumber = 1;

          final dashMatch = RegExp(r'-(\d+)$').firstMatch(displayName);
          if (dashMatch != null) {
            testNumber = int.parse(dashMatch.group(1)!);
          } else {
            final numMatch = RegExp(r'(\d+)$').firstMatch(displayName);
            if (numMatch != null) {
              final n = int.parse(numMatch.group(1)!);
              if (n > 50) {
                testNumber = 1;
              } else {
                testNumber = n;
              }
            }
          }

          final cacheKey = 'qcount_${topicId}_$fileName';
          int? qCount = prefs.getInt(cacheKey);

          // Soru sayısını sadece cache'de yoksa çekelim, hız için toplu yüklemede çekmeyebiliriz
          // Ama burada listenin doğru görünmesi önemli. Yine de her birini indirmek çok yavaşlatır.
          // Eğer cache'de yoksa ve dosya sayısı çoksa (örn > 5), paralel indirmeyi sınırlayalım veya erteleyelim.
          
          tests.add({
            'name': 'Test $testNumber',
            'testNumber': testNumber,
            'fileName': fileName,
            'url': url,
            'questionCount': qCount ?? 0, // Cache'de yoksa şimdilik 0, sonra yüklenir
          });
        }
      }

      // Eğer soru sayıları eksikse ve dosya sayısı azsa (örn <= 5), arka planda tamamla
      if (tests.any((t) => t['questionCount'] == 0) && tests.length <= 10) {
        // İndirme işlemini asenkron başlat ama bekleme
        _updateQuestionCountsInBackground(topicId, tests);
      }

      // Sort tests numerically
      tests.sort((a, b) => a['testNumber'].compareTo(b['testNumber']));

      // Save to cache
      final listCacheKey = 'tests_list_cache_$topicId';
      await prefs.setString(listCacheKey, jsonEncode(tests));
      await prefs.setInt(
        '${listCacheKey}_time',
        DateTime.now().millisecondsSinceEpoch,
      );

      return tests;
    } catch (e) {
      debugPrint('Error fetching tests: $e');
      return [];
    }
  }

  // Method removed as caching is now handled differently

  /// Get questions for a specific test file
  Future<List<TestQuestion>> getQuestionsFromTestFile(
    String topicId,
    String lessonId,
    String fileName,
  ) async {
    return _loadQuestionsFromStorage(topicId, lessonId, testFileName: fileName);
  }

  Future<void> _updateQuestionCountsInBackground(
    String topicId,
    List<Map<String, dynamic>> tests,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final test in tests) {
        if (test['questionCount'] == 0) {
          final fileName = test['fileName'];
          final url = test['url'];
          final cacheKey = 'qcount_${topicId}_$fileName';

          final jsonData =
              await _storageService.downloadAndParseJsonFromUrl(url);
          if (jsonData != null && jsonData['questions'] is List) {
            final count = (jsonData['questions'] as List).length;
            if (count > 0) {
              await prefs.setInt(cacheKey, count);
              debugPrint('✅ Lazy updated qCount for $fileName: $count');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error in background qCount update: $e');
    }
  }

  /// Parse JSON questions into TestQuestion objects
  List<TestQuestion> _parseJsonQuestions(
    Map<String, dynamic> jsonData,
    String topicId,
    String lessonId, {
    Map<String, String>? imageUrls,
  }) {
    try {
      final List<TestQuestion> questions = [];

      // Get questions array
      final questionsList = jsonData['questions'] as List<dynamic>?;
      if (questionsList == null) {
        return [];
      }

      for (final questionData in questionsList) {
        try {
          if (questionData is! Map) {
            debugPrint('⚠️ Skipping invalid question data: $questionData');
            continue;
          }
          final questionMap = Map<String, dynamic>.from(questionData);

          // Extract question fields
          final id = questionMap['id']?.toString() ?? '';
          final questionText = questionMap['question']?.toString() ?? '';
          final correctAnswer = questionMap['correctAnswer']?.toString() ?? 'A';
          final explanation = questionMap['explanation']?.toString() ?? '';
          final difficulty = questionMap['difficulty']?.toString() ?? 'easy';

          // Extract options (ve varsa altı çizili kelime: underlinedWord)
          final optionsList = questionMap['options'] as List<dynamic>? ?? [];
          final List<String> options = [];
          final List<String> underlinedWords = [];
          int correctAnswerIndex = 0;

          for (int i = 0; i < optionsList.length; i++) {
            final optionMap = optionsList[i] as Map<String, dynamic>;
            final optionText = optionMap['text']?.toString() ?? '';
            final optionKey = optionMap['key']?.toString() ?? '';
            final underlined = optionMap['underlinedWord']?.toString().trim();

            options.add(optionText);
            underlinedWords.add(underlined ?? '');

            // Find correct answer index
            if (optionKey.toUpperCase() == correctAnswer.toUpperCase()) {
              correctAnswerIndex = i;
            }
          }

          // Calculate time limit based on difficulty
          int timeLimitSeconds = 60; // default
          switch (difficulty.toLowerCase()) {
            case 'easy':
              timeLimitSeconds = 45;
              break;
            case 'medium':
              timeLimitSeconds = 60;
              break;
            case 'hard':
              timeLimitSeconds = 90;
              break;
          }

          // underlinedWords en az bir seçenekte doluysa kullan
          final hasAnyUnderlined = underlinedWords.any((w) => w.isNotEmpty);
          final List<String>? questionUnderlined = hasAnyUnderlined
              ? underlinedWords
              : null;

          // Create TestQuestion
          final question = TestQuestion(
            id: '${topicId}_q_$id',
            question: questionText,
            options: options,
            underlinedWords: questionUnderlined,
            correctAnswerIndex: correctAnswerIndex,
            explanation: explanation,
            timeLimitSeconds: timeLimitSeconds,
            topicId: topicId,
            lessonId: lessonId,
            imageUrl:
                imageUrls?[id
                    .toLowerCase()], // ID ile görsel URL'sini eşle (normalleştirilmiş)
            source: 'Storage JSON',
            order: int.tryParse(id) ?? 0,
          );

          questions.add(question);
        } catch (e) {
          debugPrint('⚠️ Error parsing question: $e');
        }
      }

      return questions;
    } catch (e) {
      return [];
    }
  }

  /// Get all questions for a lesson
  Future<List<TestQuestion>> getQuestionsByLessonId(String lessonId) async {
    try {
      final snapshot = await _questionsCollection
          .where('lessonId', isEqualTo: lessonId)
          .orderBy('order', descending: false)
          .get();
      return snapshot.docs
          .map(
            (doc) => TestQuestion.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching questions: $e');
      return [];
    }
  }

  /// Stream questions for a topic (real-time updates)
  Stream<List<TestQuestion>> streamQuestionsByTopicId(String topicId) {
    return _questionsCollection
        .where('topicId', isEqualTo: topicId)
        .snapshots()
        .map((snapshot) {
          final questions = snapshot.docs
              .map(
                (doc) => TestQuestion.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
          // Sort by order on client side
          questions.sort((a, b) => a.order.compareTo(b.order));
          return questions;
        });
  }

  /// Add a new question (admin function)
  Future<bool> addQuestion(TestQuestion question) async {
    try {
      await _questionsCollection.doc(question.id).set(question.toMap());
      return true;
    } catch (e) {
      debugPrint('Error adding question: $e');
      return false;
    }
  }

  /// Add multiple questions (admin function)
  /// Firestore batch limit is 500, so we split into chunks
  Future<bool> addQuestions(List<TestQuestion> questions) async {
    try {
      const batchSize = 20; // Firestore batch limit is 500, using 20 for safety
      int successCount = 0;

      for (int i = 0; i < questions.length; i += batchSize) {
        final batch = _firestore.batch();
        final end = (i + batchSize < questions.length)
            ? i + batchSize
            : questions.length;
        final batchQuestions = questions.sublist(i, end);

        for (final question in batchQuestions) {
          final docRef = _questionsCollection.doc(question.id);
          batch.set(docRef, question.toMap());
        }

        try {
          await batch.commit();
          successCount += batchQuestions.length;
          debugPrint(
            '✅ Uploaded ${successCount}/${questions.length} questions...',
          );
        } catch (e) {
          debugPrint('❌ Error in batch ${i ~/ batchSize + 1}: $e');
          // Continue with next batch even if one fails
        }
      }

      if (successCount == questions.length) {
        debugPrint(
          '✅ All ${questions.length} questions uploaded successfully!',
        );
        return true;
      } else {
        debugPrint(
          '⚠️ Uploaded $successCount/${questions.length} questions (some may have failed)',
        );
        return successCount > 0; // Return true if at least some were uploaded
      }
    } catch (e) {
      debugPrint('❌ Error adding questions: $e');
      debugPrint('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Add a single question
  Future<bool> addSingleQuestion(TestQuestion question) async {
    try {
      await _questionsCollection.add(question.toMap());
      return true;
    } catch (e) {
      debugPrint('Error adding single question: $e');
      return false;
    }
  }

  /// Update an existing question
  Future<bool> updateQuestion(TestQuestion question) async {
    try {
      if (question.id.isEmpty) return false;
      await _questionsCollection.doc(question.id).update(question.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating question: $e');
      return false;
    }
  }

  /// Delete a question
  Future<bool> deleteQuestion(String questionId) async {
    try {
      await _questionsCollection.doc(questionId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting question: $e');
      return false;
    }
  }
}
