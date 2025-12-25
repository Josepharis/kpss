import 'dart:io';
import '../models/podcast.dart';
import 'podcasts_service.dart';
import 'storage_service.dart';

/// Script to upload podcast audio file and create podcast document
/// 
/// Usage:
/// ```dart
/// await uploadPodcast(
///   audioFile: File('/path/to/audio.mp3'),
///   title: 'İslamiyet Öncesi Türk Tarihi - Bölüm 1',
///   description: 'Devlet yapısı ve yönetim anlayışı',
///   topicId: 'islamiyet_oncesi_turk_tarihi',
///   lessonId: 'tarih_lesson',
///   durationMinutes: 25,
/// );
/// ```
Future<bool> uploadPodcast({
  required File audioFile,
  required String title,
  required String description,
  required String topicId,
  required String lessonId,
  required int durationMinutes,
  String? podcastId,
  int order = 0,
}) async {
  try {
    print('🎙️ Starting podcast upload...');
    print('📁 Audio file: ${audioFile.path}');
    
    final storageService = StorageService();
    final podcastsService = PodcastsService();
    
    // 1. Upload audio file to Firebase Storage
    print('📤 Uploading audio to Firebase Storage...');
    final audioUrl = await storageService.uploadAudioFile(
      audioFile: audioFile,
      folderPath: 'podcasts/$topicId',
      fileName: podcastId != null ? '$podcastId.mp3' : null,
    );
    
    if (audioUrl == null) {
      print('❌ Failed to upload audio file');
      return false;
    }
    
    print('✅ Audio uploaded: $audioUrl');
    
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
    
    print('📝 Creating podcast document...');
    final success = await podcastsService.addPodcast(podcast);
    
    if (success) {
      print('✅ Podcast uploaded successfully!');
      print('📋 Podcast ID: $podcastIdToUse');
      print('🔗 Audio URL: $audioUrl');
      return true;
    } else {
      print('❌ Failed to create podcast document');
      return false;
    }
  } catch (e) {
    print('❌ Error uploading podcast: $e');
    return false;
  }
}

