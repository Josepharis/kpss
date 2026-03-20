import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/lessons_service.dart';

class GlobalAdminSyncService {
  static final GlobalAdminSyncService _instance = GlobalAdminSyncService._internal();
  factory GlobalAdminSyncService() => _instance;
  GlobalAdminSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LessonsService _lessonsService = LessonsService();

  /// Belirli bir dersin tüm konularını senkronize eder.
  Future<void> syncLesson(
    String lessonId, {
    bool syncTests = true,
    bool syncPdfs = true,
    bool syncPodcasts = true,
    bool syncNotes = true,
    bool syncFlashCards = true,
  }) async {
    try {
      final lesson = await _lessonsService.getLessonById(lessonId);
      if (lesson == null) return;
      
      debugPrint('📖 Ders senkronizasyonu başladı: ${lesson.name}');
      
      // Cache'i bypass etmek için Storage'dan tekrar tara
      final topics = await _lessonsService.getTopicsByLessonId(lessonId);
      
      for (var topic in topics) {
        await syncTopic(
          lessonId, 
          topic.id,
          syncTests: syncTests,
          syncPdfs: syncPdfs,
          syncPodcasts: syncPodcasts,
          syncNotes: syncNotes,
          syncFlashCards: syncFlashCards,
        );
      }
      
      debugPrint('✅ Ders "${lesson.name}" senkronize edildi.');
    } catch (e) {
      debugPrint('❌ Ders Sync Hatası: $e');
      rethrow;
    }
  }

  /// Belirli bir konuyu ve içindeki verileri senkronize eder.
  Future<void> syncTopic(
    String lessonId, 
    String topicId, {
    bool syncTests = true,
    bool syncPdfs = true,
    bool syncPodcasts = true,
    bool syncNotes = true,
    bool syncFlashCards = true,
  }) async {
    try {
      // 1. Topic nesnesini bul
      final topics = await _lessonsService.getTopicsByLessonId(lessonId);
      final topic = topics.firstWhere((t) => t.id == topicId);
      
      debugPrint('   📝 Konu senkronize ediliyor: ${topic.name}');
      
      // 2. İçerik ve Soru Sayıları
      await _lessonsService.getTopicContentCounts(
        topic,
        syncTests: syncTests,
        syncPdfs: syncPdfs,
        syncPodcasts: syncPodcasts,
        syncNotes: syncNotes,
        syncFlashCards: syncFlashCards,
      );
      
      // 3. Firestore Ana Bilgiler
      await _firestore.collection('topics').doc(topicId).set({
        'lessonId': lessonId,
        'name': topic.name,
        'subtitle': topic.subtitle,
        'order': topic.order,
        'duration': topic.duration,
        'lastGlobalSync': FieldValue.serverTimestamp(), // Artık global sync kabul edelim
      }, SetOptions(merge: true));
      
    } catch (e) {
      debugPrint('❌ Konu Sync Hatası: $e');
      rethrow;
    }
  }

  /// Tüm dersleri ve konuları gezip Storage'daki verileri sayar ve Firestore'a yazar.
  Future<void> syncAllDataToFirestore() async {
    try {
      debugPrint('🚀 GLOBAL SYNC BAŞLATILIYOR...');
      final lessons = await _lessonsService.getAllLessons();
      
      for (var lesson in lessons) {
        await syncLesson(lesson.id);
      }

      debugPrint('✅ GLOBAL SYNC TAMAMLANDI!');
    } catch (e) {
      debugPrint('❌ Global Sync Hatası: $e');
      rethrow;
    }
  }
}
