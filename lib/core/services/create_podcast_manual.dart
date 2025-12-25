import '../models/podcast.dart';
import 'podcasts_service.dart';

/// Script to create a podcast document in Firestore with a direct audio URL
/// 
/// Use this when you have the download URL from Firebase Console
/// 
/// Usage:
/// ```dart
/// await createPodcastManual(
///   audioUrl: 'https://firebasestorage.googleapis.com/...',
///   title: 'İslamiyet Öncesi Türk Tarihi - Bölüm 1',
///   description: 'Devlet yapısı ve yönetim anlayışı',
///   topicId: 'islamiyet_oncesi_turk_tarihi',
///   lessonId: 'tarih_lesson',
///   durationMinutes: 25,
///   podcastId: 'islamiyet_oncesi_turk_tarihi_podcast_1',
///   order: 1,
/// );
/// ```
Future<bool> createPodcastManual({
  required String audioUrl, // Firebase Storage'dan kopyaladığınız download URL
  required String title,
  required String description,
  required String topicId,
  required String lessonId,
  required int durationMinutes,
  String? podcastId,
  int order = 0,
}) async {
  try {
    print('🎙️ Creating podcast document manually...');
    print('🔗 Audio URL: $audioUrl');
    
    final podcastsService = PodcastsService();
    
    // Create podcast document in Firestore
    final podcastIdToUse = podcastId ?? 'podcast_${DateTime.now().millisecondsSinceEpoch}';
    final podcast = Podcast(
      id: podcastIdToUse,
      title: title,
      description: description,
      audioUrl: audioUrl,
      durationMinutes: durationMinutes,
      topicId: topicId,
      lessonId: lessonId,
      order: order,
    );
    
    print('📝 Creating podcast document in Firestore...');
    print('   ID: $podcastIdToUse');
    print('   Title: $title');
    print('   Topic ID: $topicId');
    
    final success = await podcastsService.addPodcast(podcast);
    
    if (success) {
      print('✅ Podcast document created successfully!');
      print('📋 Podcast ID: $podcastIdToUse');
      print('🔗 Audio URL: $audioUrl');
      return true;
    } else {
      print('❌ Failed to create podcast document');
      return false;
    }
  } catch (e) {
    print('❌ Error creating podcast: $e');
    print('Error type: ${e.runtimeType}');
    return false;
  }
}

