import 'firebase_data_uploader.dart';

/// Script to upload initial data to Firebase
/// Run this once to populate Firebase with Tarih lesson data
/// 
/// Usage: Call uploadData() from your app initialization or admin panel
Future<void> uploadData() async {
  final uploader = FirebaseDataUploader();
  
  print('🚀 Starting data upload to Firebase...');
  print('');
  
  final success = await uploader.uploadAllData();
  
  if (success) {
    print('');
    print('✅ All data uploaded successfully!');
    print('📚 Tarih lesson created');
    print('📖 İslamiyet Öncesi Türk Tarihi topic created');
    print('❓ 25 questions uploaded');
  } else {
    print('');
    print('❌ Error uploading data. Please check the console for details.');
  }
}

