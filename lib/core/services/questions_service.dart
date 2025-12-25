import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/test_question.dart';

/// Service for managing questions from Firestore
class QuestionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _questionsCollection => _firestore.collection('questions');

  /// Get all questions for a topic
  Future<List<TestQuestion>> getQuestionsByTopicId(String topicId) async {
    try {
      final snapshot = await _questionsCollection
          .where('topicId', isEqualTo: topicId)
          .get();
      final questions = snapshot.docs
          .map((doc) => TestQuestion.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      questions.sort((a, b) => a.order.compareTo(b.order));
      return questions;
    } catch (e) {
      print('Error fetching questions: $e');
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
      print('Error fetching questions: $e');
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
      print('Error adding question: $e');
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
          print('✅ Uploaded ${successCount}/${questions.length} questions...');
        } catch (e) {
          print('❌ Error in batch ${i ~/ batchSize + 1}: $e');
          // Continue with next batch even if one fails
        }
      }
      
      if (successCount == questions.length) {
        print('✅ All ${questions.length} questions uploaded successfully!');
        return true;
      } else {
        print('⚠️ Uploaded $successCount/${questions.length} questions (some may have failed)');
        return successCount > 0; // Return true if at least some were uploaded
      }
    } catch (e) {
      print('❌ Error adding questions: $e');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Delete a question
  Future<bool> deleteQuestion(String questionId) async {
    try {
      await _questionsCollection.doc(questionId).delete();
      return true;
    } catch (e) {
      print('Error deleting question: $e');
      return false;
    }
  }
}

