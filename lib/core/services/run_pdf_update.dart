import 'update_topic_pdf_urls.dart';

/// Script to run PDF URL update
/// 
/// Usage: Call this function from your app (e.g., in an admin page or main.dart)
/// 
/// Example:
/// ```dart
/// import 'package:kpss_ags_2026/core/services/run_pdf_update.dart';
/// 
/// // In your admin page or main.dart
/// await runPdfUpdate();
/// ```
Future<void> runPdfUpdate() async {
  print('🚀 Starting PDF URL update process...');
  print('=' * 50);
  
  final updater = UpdateTopicPdfUrls();
  await updater.updateAllTopicPdfUrls();
  
  print('=' * 50);
  print('✅ PDF URL update process completed!');
}

/// Update PDF URL for a specific topic
/// 
/// Example:
/// ```dart
/// await updateSingleTopicPdf(
///   topicId: 'islamiyet_oncesi_turk_tarihi',
///   storagePath: 'topics/tarih/islamiyet_oncesi_turk_tarihi.pdf',
/// );
/// ```
Future<bool> updateSingleTopicPdf({
  required String topicId,
  required String storagePath,
}) async {
  print('🚀 Updating PDF URL for topic: $topicId');
  print('📁 Storage path: $storagePath');
  
  final updater = UpdateTopicPdfUrls();
  return await updater.updateTopicPdfUrl(
    topicId: topicId,
    storagePath: storagePath,
  );
}

