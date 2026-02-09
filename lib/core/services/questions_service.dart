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
  CollectionReference get _questionsCollection => _firestore.collection('questions');

  /// Get all questions for a topic
  /// First tries cache, then Storage, then Firestore
  Future<List<TestQuestion>> getQuestionsByTopicId(String topicId, {String? lessonId}) async {
    try {
      // Önce cache'den kontrol et (hızlı açılış için)
      final cachedQuestions = await _loadQuestionsFromCache(topicId);
      if (cachedQuestions.isNotEmpty) {
        debugPrint('✅ Loaded ${cachedQuestions.length} questions from cache');
        // Arka planda güncelle (non-blocking)
        if (lessonId != null) {
          _updateQuestionsInBackground(topicId, lessonId);
        }
        return cachedQuestions;
      }
      
      // Cache'de yoksa, Storage'dan veya Firestore'dan çek
      if (lessonId != null) {
        final storageQuestions = await _loadQuestionsFromStorage(topicId, lessonId);
        if (storageQuestions.isNotEmpty) {
          debugPrint('✅ Loaded ${storageQuestions.length} questions from Storage');
          // Cache'e kaydet
          await _saveQuestionsToCache(topicId, storageQuestions);
          return storageQuestions;
        }
      }
      
      // Fallback to Firestore
      final snapshot = await _questionsCollection
          .where('topicId', isEqualTo: topicId)
          .get();
      final questions = snapshot.docs
          .map((doc) => TestQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      questions.sort((a, b) => a.order.compareTo(b.order));
      
      // Cache'e kaydet
      if (questions.isNotEmpty) {
        await _saveQuestionsToCache(topicId, questions);
      }
      
      return questions;
    } catch (e) {
      debugPrint('Error fetching questions: $e');
      return [];
    }
  }

  /// Load questions from local cache
  Future<List<TestQuestion>> _loadQuestionsFromCache(String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'questions_$topicId';
      final cachedJson = prefs.getString(cacheKey);
      
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> cachedList = jsonDecode(cachedJson);
        final questions = cachedList
            .map((json) => TestQuestion.fromMap(json as Map<String, dynamic>, json['id'] ?? ''))
            .toList();
        debugPrint('✅ Loaded ${questions.length} questions from cache');
        return questions;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Save questions to local cache
  Future<void> _saveQuestionsToCache(String topicId, List<TestQuestion> questions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'questions_$topicId';
      final jsonList = questions.map((q) => q.toMap()..['id'] = q.id).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(cacheKey, jsonString);
      
      // Soru sayısını da ayrı bir key ile kaydet (hızlı erişim için)
      final countKey = 'questions_count_$topicId';
      await prefs.setInt(countKey, questions.length);
      
      debugPrint('✅ Saved ${questions.length} questions to cache');
    } catch (e) {
      debugPrint('⚠️ Error saving questions to cache: $e');
    }
  }

  /// Update questions in background (non-blocking)
  /// Sadece cache yoksa veya geçersizse Storage'dan çek
  /// Uygulama arka plandayken çalışmaz (Storage kullanımını önlemek için)
  void _updateQuestionsInBackground(String topicId, String lessonId) async {
    // Önce cache kontrolü yap - cache geçerliyse Storage'dan çekme
    try {
      final cachedQuestions = await _loadQuestionsFromCache(topicId);
      if (cachedQuestions.isNotEmpty) {
        // Cache'de sorular var, Storage'dan çekme (gereksiz istek önleme)
        debugPrint('✅ Questions already in cache, skipping background Storage request');
        return;
      }
    } catch (e) {
      // Cache kontrolü başarısız, devam et
    }
    
    // Cache yoksa arka planda güncelle, sayfa açılışını engelleme
    // NOT: Uygulama arka plandayken bu işlem çalışmaz (Storage kullanımını önlemek için)
    Future.microtask(() async {
      try {
        // Uygulama durumunu kontrol et (arka plandaysa çalışma)
        // Bu kontrol için WidgetsBinding.instance.lifecycleState kullanılabilir
        // Ama bu servis katmanında olduğu için, sadece cache kontrolü yeterli
        // Uygulama arka plandayken zaten bu metod çağrılmaz (sayfa açık değilse)
        
        debugPrint('🌐 Loading questions from Storage in background (cache miss)');
        debugPrint('⚠️ WARNING: This will make Storage requests!');
        final storageQuestions = await _loadQuestionsFromStorage(topicId, lessonId);
        if (storageQuestions.isNotEmpty) {
          await _saveQuestionsToCache(topicId, storageQuestions);
          debugPrint('✅ Background update: ${storageQuestions.length} questions cached');
        }
      } catch (e) {
        debugPrint('⚠️ Error in background question update: $e');
      }
    });
  }

  /// Load questions from Storage (soru folder)
  Future<List<TestQuestion>> _loadQuestionsFromStorage(String topicId, String lessonId) async {
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
      
      // List JSON files in soru folder
      final jsonUrls = await _storageService.listJsonFiles(soruPath);
      
      if (jsonUrls.isEmpty) {
        return [];
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
            debugPrint('⚠️ Could not extract path from URL, trying direct download: $e');
            // Try to download directly from URL
            final jsonData = await _storageService.downloadAndParseJsonFromUrl(jsonUrl);
            if (jsonData != null) {
              final questions = _parseJsonQuestions(jsonData, topicId, lessonId);
              allQuestions.addAll(questions);
              continue;
            }
          }
          
          if (storagePath != null) {
            final jsonData = await _storageService.downloadAndParseJson(storagePath);
            if (jsonData != null) {
              final questions = _parseJsonQuestions(jsonData, topicId, lessonId);
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

  /// Parse JSON questions into TestQuestion objects
  List<TestQuestion> _parseJsonQuestions(
    Map<String, dynamic> jsonData,
    String topicId,
    String lessonId,
  ) {
    try {
      final List<TestQuestion> questions = [];
      
      // Get questions array
      final questionsList = jsonData['questions'] as List<dynamic>?;
      if (questionsList == null) {
        return [];
      }
      
      for (final questionData in questionsList) {
        try {
          final questionMap = questionData as Map<String, dynamic>;
          
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
          final List<String>? questionUnderlined = hasAnyUnderlined ? underlinedWords : null;

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
          .map((doc) => TestQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
              .map((doc) => TestQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
        final end = (i + batchSize < questions.length) ? i + batchSize : questions.length;
        final batchQuestions = questions.sublist(i, end);
        
        for (final question in batchQuestions) {
          final docRef = _questionsCollection.doc(question.id);
          batch.set(docRef, question.toMap());
        }
        
        try {
          await batch.commit();
          successCount += batchQuestions.length;
          debugPrint('✅ Uploaded ${successCount}/${questions.length} questions...');
        } catch (e) {
          debugPrint('❌ Error in batch ${i ~/ batchSize + 1}: $e');
          // Continue with next batch even if one fails
        }
      }
      
      if (successCount == questions.length) {
        debugPrint('✅ All ${questions.length} questions uploaded successfully!');
        return true;
      } else {
        debugPrint('⚠️ Uploaded $successCount/${questions.length} questions (some may have failed)');
        return successCount > 0; // Return true if at least some were uploaded
      }
    } catch (e) {
      debugPrint('❌ Error adding questions: $e');
      debugPrint('Error details: ${e.toString()}');
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

