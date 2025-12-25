import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lesson.dart';
import '../models/topic.dart';

/// Service for managing lessons and topics from Firestore
class LessonsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _lessonsCollection => _firestore.collection('lessons');
  CollectionReference get _topicsCollection => _firestore.collection('topics');

  /// Get all lessons
  Future<List<Lesson>> getAllLessons() async {
    try {
      final snapshot = await _lessonsCollection.get();
      final lessons = snapshot.docs
          .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      lessons.sort((a, b) => a.order.compareTo(b.order));
      return lessons;
    } catch (e) {
      print('Error fetching lessons: $e');
      return [];
    }
  }

  /// Get lessons by category
  Future<List<Lesson>> getLessonsByCategory(String category) async {
    try {
      final snapshot = await _lessonsCollection
          .where('category', isEqualTo: category)
          .get();
      final lessons = snapshot.docs
          .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      lessons.sort((a, b) => a.order.compareTo(b.order));
      return lessons;
    } catch (e) {
      print('Error fetching lessons by category: $e');
      return [];
    }
  }

  /// Get a single lesson by ID
  Future<Lesson?> getLessonById(String lessonId) async {
    try {
      final doc = await _lessonsCollection.doc(lessonId).get();
      if (doc.exists) {
        return Lesson.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error fetching lesson: $e');
      return null;
    }
  }

  /// Get all topics for a lesson
  Future<List<Topic>> getTopicsByLessonId(String lessonId) async {
    try {
      final snapshot = await _topicsCollection
          .where('lessonId', isEqualTo: lessonId)
          .get();
      final topics = snapshot.docs
          .map((doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      // Sort by order on client side
      topics.sort((a, b) => a.order.compareTo(b.order));
      return topics;
    } catch (e) {
      print('Error fetching topics: $e');
      print('Error details: $e');
      return [];
    }
  }

  /// Stream all lessons (real-time updates)
  Stream<List<Lesson>> streamAllLessons() {
    return _lessonsCollection
        .snapshots()
        .map((snapshot) {
          final lessons = snapshot.docs
              .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort by order on client side
          lessons.sort((a, b) => a.order.compareTo(b.order));
          return lessons;
        });
  }

  /// Stream lessons by category (real-time updates)
  Stream<List<Lesson>> streamLessonsByCategory(String category) {
    return _lessonsCollection
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
          final lessons = snapshot.docs
              .map((doc) => Lesson.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort by order on client side
          lessons.sort((a, b) => a.order.compareTo(b.order));
          return lessons;
        });
  }

  /// Stream topics for a lesson (real-time updates)
  Stream<List<Topic>> streamTopicsByLessonId(String lessonId) {
    return _topicsCollection
        .where('lessonId', isEqualTo: lessonId)
        .snapshots()
        .map((snapshot) {
          final topics = snapshot.docs
              .map((doc) => Topic.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          // Sort by order on client side
          topics.sort((a, b) => a.order.compareTo(b.order));
          return topics;
        });
  }

  /// Add a new lesson (admin function)
  Future<bool> addLesson(Lesson lesson) async {
    try {
      await _lessonsCollection.doc(lesson.id).set(lesson.toMap(), SetOptions(merge: true));
      print('✅ Lesson "${lesson.name}" added/updated');
      return true;
    } catch (e) {
      print('❌ Error adding lesson: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Add a new topic (admin function)
  Future<bool> addTopic(Topic topic) async {
    try {
      await _topicsCollection.doc(topic.id).set(topic.toMap(), SetOptions(merge: true));
      print('✅ Topic "${topic.name}" added/updated');
      return true;
    } catch (e) {
      print('❌ Error adding topic: $e');
      print('Error type: ${e.runtimeType}');
      print('Error details: ${e.toString()}');
      return false;
    }
  }

  /// Update topic progress
  Future<bool> updateTopicProgress(String topicId, double progress) async {
    try {
      await _topicsCollection.doc(topicId).update({'progress': progress});
      return true;
    } catch (e) {
      print('Error updating topic progress: $e');
      return false;
    }
  }
}

