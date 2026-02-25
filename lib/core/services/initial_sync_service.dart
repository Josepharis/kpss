import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/lessons_service.dart';
import '../../core/services/questions_service.dart';

class InitialSyncService {
  static final InitialSyncService _instance = InitialSyncService._internal();

  factory InitialSyncService() {
    return _instance;
  }

  InitialSyncService._internal();

  /// Sadece haftada bir kez çalışıp tüm topics için verileri Storage/Firestore'dan çeker
  /// ve SharedPreferences (content_counts_) içine kaydeder.
  Future<void> runInitialSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncKey = 'initial_sync_timestamp';
      final lastSync = prefs.getInt(lastSyncKey);

      const cacheValidDuration = Duration(days: 7);
      final now = DateTime.now().millisecondsSinceEpoch;

      // Eğer son sync 7 günden önce yapılmışsa VEYA hiç yapılmamışsa sync et
      if (lastSync == null ||
          (now - lastSync) > cacheValidDuration.inMilliseconds) {
        debugPrint('🔄 Haftalık initial sync başlatılıyor...');

        final lessonsService = LessonsService();
        final questionsService = QuestionsService();
        final lessons = await lessonsService.getAllLessons();

        for (var lesson in lessons) {
          final topics = await lessonsService.getTopicsByLessonId(lesson.id);
          for (var topic in topics) {
            // initial sync çalıştığı an (haftada bir) tüm cache'i zorla günceller.
            // Soru sayılarını çekmek ve SADECE sayıyı cache'e yazmak için QuestionsService'i çağırıyoruz.
            await questionsService.syncQuestionCount(topic.id, lesson.id);
            // Burada içerik sayılarını (dosyalarını) Firebase Storage'dan öğrenip cache'liyoruz.
            await lessonsService.getTopicContentCounts(topic);
          }
        }

        await prefs.setInt(lastSyncKey, now);
        debugPrint('✅ Haftalık initial sync tamamlandı ve güncellendi!');
      } else {
        debugPrint('⚡ Haftalık initial sync zaten güncel.');
      }
    } catch (e) {
      debugPrint('❌ Initial sync hatası: $e');
    }
  }
}
