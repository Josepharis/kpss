import 'firebase_data_uploader.dart';

/// Script to upload Vatandaşlık lesson to Firestore
/// 
/// Usage:
/// 1. Uncomment the code in main.dart temporarily
/// 2. Run the app once
/// 3. Comment it back
/// 
/// OR run this script directly:
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp(
///     options: DefaultFirebaseOptions.currentPlatform,
///   );
///   
///   final uploader = FirebaseDataUploader();
///   await uploader.uploadVatandaslikLessonData();
/// }
/// ```
/// 
/// Note: Topics will be automatically loaded from Storage
/// Storage path should be: dersler/vatandaslik/konular/
Future<void> uploadVatandaslikLesson() async {
  try {
    print('🚀 Starting Vatandaşlık lesson upload...');
    final uploader = FirebaseDataUploader();
    final result = await uploader.uploadVatandaslikLessonData();
    
    if (result) {
      print('✅ Vatandaşlık lesson uploaded successfully!');
      print('💡 Konular otomatik olarak Storage\'dan çekilecek');
      print('📂 Storage path: dersler/vatandaslik/konular/');
    } else {
      print('❌ Failed to upload Vatandaşlık lesson');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
