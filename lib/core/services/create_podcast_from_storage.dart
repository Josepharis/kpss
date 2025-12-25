import 'package:firebase_storage/firebase_storage.dart';
import '../models/podcast.dart';
import 'podcasts_service.dart';

/// Script to create a podcast document in Firestore from an existing file in Storage
/// 
/// This is useful when you've already uploaded the audio file to Storage
/// and just need to create the Firestore document.
/// 
/// Usage:
/// ```dart
/// await createPodcastFromStorage(
///   storagePath: 'podcasts/islamiyet_oncesi_turk_tarihi/islamiyet_oncesi_turk_tarihi.m4a',
///   title: 'İslamiyet Öncesi Türk Tarihi - Bölüm 1',
///   description: 'Devlet yapısı ve yönetim anlayışı hakkında detaylı bilgiler',
///   topicId: 'islamiyet_oncesi_turk_tarihi',
///   lessonId: 'tarih_lesson',
///   durationMinutes: 25,
///   podcastId: 'islamiyet_oncesi_turk_tarihi_podcast_1',
///   order: 1,
/// );
/// ```
Future<bool> createPodcastFromStorage({
  required String storagePath, // e.g., 'podcasts/islamiyet_oncesi_turk_tarihi/islamiyet_oncesi_turk_tarihi.m4a'
  required String title,
  required String description,
  required String topicId,
  required String lessonId,
  required int durationMinutes,
  String? podcastId,
  int order = 0,
}) async {
  try {
    print('🎙️ Creating podcast from existing Storage file...');
    print('📁 Storage path: $storagePath');
    
    final storage = FirebaseStorage.instance;
    final podcastsService = PodcastsService();
    
    // 1. Get download URL from Storage
    print('🔗 Getting download URL from Storage...');
    final storageRef = storage.ref().child(storagePath);
    
    String audioUrl;
    try {
      audioUrl = await storageRef.getDownloadURL();
      print('✅ Got download URL: $audioUrl');
    } catch (e) {
      print('❌ Error getting download URL: $e');
      print('💡 Make sure the file exists at: $storagePath');
      return false;
    }
    
    // 2. Create podcast document in Firestore
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

