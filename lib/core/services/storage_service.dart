import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

/// Service for uploading files to Firebase Storage
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload audio file to Firebase Storage
  /// Returns the download URL
  Future<String?> uploadAudioFile({
    required File audioFile,
    required String folderPath, // e.g., 'podcasts/islamiyet_oncesi_turk_tarihi'
    String? fileName, // Optional custom filename
  }) async {
    try {
      final fileNameToUse = fileName ?? path.basename(audioFile.path);
      final storageRef = _storage.ref().child('$folderPath/$fileNameToUse');
      
      print('📤 Uploading audio file: $fileNameToUse');
      
      final uploadTask = storageRef.putFile(
        audioFile,
        SettableMetadata(
          contentType: 'audio/mpeg', // MP3 için
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📊 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      await uploadTask;
      
      final downloadUrl = await storageRef.getDownloadURL();
      print('✅ Audio uploaded successfully: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading audio file: $e');
      return null;
    }
  }

  /// Upload image file to Firebase Storage
  /// Returns the download URL
  Future<String?> uploadImageFile({
    required File imageFile,
    required String folderPath,
    String? fileName,
  }) async {
    try {
      final fileNameToUse = fileName ?? path.basename(imageFile.path);
      final storageRef = _storage.ref().child('$folderPath/$fileNameToUse');
      
      print('📤 Uploading image file: $fileNameToUse');
      
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      await uploadTask;
      
      final downloadUrl = await storageRef.getDownloadURL();
      print('✅ Image uploaded successfully: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image file: $e');
      return null;
    }
  }

  /// Delete file from Firebase Storage
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      print('✅ File deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting file: $e');
      return false;
    }
  }

  /// List video files in a folder and get their download URLs
  /// Returns list of download URLs
  Future<List<String>> listVideoFiles(String folderPath) async {
    try {
      print('📂 Listing video files in: $folderPath');
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        print('📊 Found ${result.items.length} items in folder');
        
        // Alt klasörleri de listele
        for (var prefix in result.prefixes) {
          print('📁 Subfolder: ${prefix.name}');
          try {
            final subResult = await prefix.listAll();
            print('   📊 Found ${subResult.items.length} items in subfolder');
          } catch (e) {
            print('   ⚠️ Error listing subfolder: $e');
          }
        }
        
        final List<String> urls = [];
        for (var item in result.items) {
          // Video dosyalarını filtrele
          final fileName = item.name.toLowerCase();
          if (fileName.endsWith('.mp4') || 
              fileName.endsWith('.mov') || 
              fileName.endsWith('.avi') ||
              fileName.endsWith('.mkv') ||
              fileName.endsWith('.webm')) {
            try {
              final url = await item.getDownloadURL();
              urls.add(url);
              print('✅ Found video: ${item.name} (${item.fullPath})');
            } catch (e) {
              print('⚠️ Error getting URL for ${item.name}: $e');
            }
          }
        }
        
        print('✅ Found ${urls.length} video files');
        return urls;
      } catch (e) {
        print('⚠️ Error listing folder: $e');
        return [];
      }
    } catch (e) {
      print('❌ Error listing video files: $e');
      return [];
    }
  }

  /// List folders (subdirectories) in a folder
  /// Returns list of folder names
  Future<List<String>> listFolders(String folderPath) async {
    try {
      print('📂 Listing folders in: $folderPath');
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        print('📊 Found ${result.prefixes.length} subfolders');
        
        final List<String> folderNames = [];
        for (var prefix in result.prefixes) {
          folderNames.add(prefix.name);
          print('📁 Found folder: ${prefix.name}');
        }
        
        print('✅ Found ${folderNames.length} folders');
        return folderNames;
      } catch (e) {
        print('⚠️ Error listing folders: $e');
        return [];
      }
    } catch (e) {
      print('❌ Error listing folders: $e');
      return [];
    }
  }

  /// Count files in a folder (for video, podcast, bilgikarti)
  /// Returns count of files
  Future<int> countFilesInFolder(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      final result = await folderRef.listAll();
      return result.items.length;
    } catch (e) {
      print('⚠️ Error counting files in $folderPath: $e');
      return 0;
    }
  }

  /// List files in a folder and get their download URLs (for any file type)
  /// Returns list of download URLs
  Future<List<String>> listFiles(String folderPath) async {
    try {
      print('📂 Listing files in: $folderPath');
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        print('📊 Found ${result.items.length} items in folder');
        
        final List<String> urls = [];
        for (var item in result.items) {
          try {
            final url = await item.getDownloadURL();
            urls.add(url);
            print('✅ Found: ${item.name} (${item.fullPath})');
          } catch (e) {
            print('⚠️ Error getting URL for ${item.name}: $e');
          }
        }
        
        print('✅ Found ${urls.length} files');
        return urls;
      } catch (e) {
        print('⚠️ Error listing folder: $e');
        return [];
      }
    } catch (e) {
      print('❌ Error listing files: $e');
      return [];
    }
  }

  /// List audio files in a folder and get their download URLs
  /// Returns list of download URLs
  Future<List<String>> listAudioFiles(String folderPath) async {
    try {
      print('📂 Listing files in: $folderPath');
      final folderRef = _storage.ref().child(folderPath);
      
      // Önce klasörün var olup olmadığını kontrol et
      try {
        final result = await folderRef.listAll();
        print('📊 Found ${result.items.length} items in folder');
        print('📊 Found ${result.prefixes.length} subfolders');
        
        // Alt klasörleri de listele
        for (var prefix in result.prefixes) {
          print('📁 Subfolder: ${prefix.name}');
          try {
            final subResult = await prefix.listAll();
            print('   📊 Found ${subResult.items.length} items in subfolder');
            for (var item in subResult.items) {
              print('   📄 File: ${item.name}');
            }
          } catch (e) {
            print('   ⚠️ Error listing subfolder: $e');
          }
        }
        
        final List<String> urls = [];
        for (var item in result.items) {
          try {
            final url = await item.getDownloadURL();
            urls.add(url);
            print('✅ Found: ${item.name} (${item.fullPath})');
          } catch (e) {
            print('⚠️ Error getting URL for ${item.name}: $e');
          }
        }
        
        print('✅ Found ${urls.length} audio files');
        return urls;
      } catch (e) {
        print('❌ Error listing folder: $e');
        print('💡 Trying to list root podcasts folder...');
        
        // Eğer klasör yoksa, root'tan podcasts klasörünü kontrol et
        try {
          final rootRef = _storage.ref().child('podcasts');
          final rootResult = await rootRef.listAll();
          print('📊 Found ${rootResult.items.length} items in root podcasts folder');
          print('📊 Found ${rootResult.prefixes.length} subfolders in root');
          
          for (var prefix in rootResult.prefixes) {
            print('📁 Root subfolder: ${prefix.name}');
          }
          
          for (var item in rootResult.items) {
            print('📄 Root file: ${item.name} (${item.fullPath})');
          }
        } catch (rootError) {
          print('❌ Error listing root: $rootError');
        }
        
        return [];
      }
    } catch (e) {
      print('❌ Error listing files: $e');
      print('Error type: ${e.runtimeType}');
      return [];
    }
  }
}

