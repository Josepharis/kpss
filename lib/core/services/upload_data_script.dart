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

/// Script to upload Vatandaşlık lesson to Firebase
/// Run this once to add Vatandaşlık lesson
/// 
/// Usage: Call uploadVatandaslikData() from your app initialization
Future<void> uploadVatandaslikData() async {
  final uploader = FirebaseDataUploader();
  
  print('🚀 Starting Vatandaşlık lesson upload to Firebase...');
  print('');
  
  final success = await uploader.uploadVatandaslikLessonData();
  
  if (success) {
    print('');
    print('✅ Vatandaşlık lesson uploaded successfully!');
    print('💡 Konular otomatik olarak Storage\'dan çekilecek: dersler/vatandaslik/konular/');
  } else {
    print('');
    print('❌ Error uploading Vatandaşlık lesson. Please check the console for details.');
  }
}

/// Script to upload all new lessons to Firebase
/// Uploads: Coğrafya, Güncel Bilgiler, Türkçe, Matematik
/// 
/// Usage: Call uploadAllNewLessonsData() from your app initialization
Future<void> uploadAllNewLessonsData() async {
  final uploader = FirebaseDataUploader();
  
  print('🚀 Starting all new lessons upload to Firebase...');
  print('   📚 Coğrafya (Genel Kültür)');
  print('   📚 Güncel Bilgiler (Genel Kültür)');
  print('   📚 Türkçe (Genel Yetenek)');
  print('   📚 Matematik (Genel Yetenek)');
  print('');
  
  final success = await uploader.uploadAllNewLessons();
  
  if (success) {
    print('');
    print('✅ All new lessons uploaded successfully!');
    print('');
    print('📋 Uploaded Lessons:');
    print('   Genel Kültür:');
    print('     • Tarih');
    print('     • Vatandaşlık');
    print('     • Coğrafya');
    print('     • Güncel Bilgiler');
    print('   Genel Yetenek:');
    print('     • Türkçe (Konu anlatımı ve video yok)');
    print('     • Matematik (Sadece test ve not)');
    print('');
    print('💡 Tüm derslerin konuları Storage\'dan otomatik çekilecek');
    print('📂 Storage path formatı: dersler/{ders_adi}/konular/');
  } else {
    print('');
    print('❌ Error uploading new lessons. Please check the console for details.');
  }
}
