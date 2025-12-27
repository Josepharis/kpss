import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lessons_service.dart';

/// Service to update topic PDF URLs from Firebase Storage to Firestore
/// 
/// This script will:
/// 1. List all PDF files in Firebase Storage (under topics/ folder)
/// 2. Match them with topics in Firestore
/// 3. Update the pdfUrl field in Firestore topics
class UpdateTopicPdfUrls {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LessonsService _lessonsService = LessonsService();

  /// Update PDF URLs for all topics
  /// 
  /// Storage structure expected:
  /// - topics/{lessonName}/{topicFolderName}/{anyPdfFile}.pdf
  /// Topic folder name should match topic name (normalized)
  Future<void> updateAllTopicPdfUrls() async {
    try {
      print('📚 Starting PDF URL update process...');
      
      // Get all topics from Firestore
      final topics = await _lessonsService.getAllTopics();
      print('📋 Found ${topics.length} topics in Firestore');
      
      // Debug: Print all topics
      if (topics.isNotEmpty) {
        print('\n📋 All topics in Firestore:');
        for (var topic in topics) {
          final lesson = await _lessonsService.getLessonById(topic.lessonId);
          print('   📚 ${topic.name} (ID: ${topic.id}, Lesson: ${lesson?.name ?? topic.lessonId})');
        }
        print('');
      }
      
      // List all PDFs in Storage with their folder structure
      print('📂 Scanning Firebase Storage for PDF files...');
      final pdfFilesByPath = await _listAllPdfFilesWithStructure();
      print('📄 Found ${pdfFilesByPath.length} PDF files in Storage');
      
      // Debug: Print all found PDFs
      if (pdfFilesByPath.isNotEmpty) {
        print('\n📋 All PDF files found in Storage:');
        for (var entry in pdfFilesByPath.entries) {
          print('   📄 ${entry.key}');
        }
        print('');
      }
      
      // Match and update
      int updatedCount = 0;
      int notFoundCount = 0;
      
      for (final topic in topics) {
        // Try to find matching PDF by topic name (folder name)
        String? pdfUrl;
        
        // Normalize topic name for matching
        final normalizedTopicName = _normalizeTopicName(topic.name);
        print('\n🔍 Looking for topic: "${topic.name}"');
        print('   Topic ID: ${topic.id}');
        print('   Normalized topic name: "$normalizedTopicName"');
        
        // Get lesson name
        final lesson = await _lessonsService.getLessonById(topic.lessonId);
        if (lesson != null) {
          final normalizedLessonName = _normalizeTopicName(lesson.name);
          print('   Lesson: "${lesson.name}" (normalized: "$normalizedLessonName")');
          
          // Method 1: Look for topics/{lessonName}/{topicFolderName}/{anyPdf}.pdf
          // Check if any PDF path contains both lesson name and topic name
          print('   🔎 Method 1: Looking for path with both lesson and topic name...');
          for (var entry in pdfFilesByPath.entries) {
            final path = entry.key.toLowerCase();
            final normalizedPath = _normalizePath(path);
            
            print('      Checking: ${entry.key}');
            print('         Normalized path: "$normalizedPath"');
            print('         Contains lesson? ${normalizedPath.contains(normalizedLessonName)}');
            print('         Contains topic? ${normalizedPath.contains(normalizedTopicName)}');
            
            // Check if path contains lesson name and topic name
            if (normalizedPath.contains(normalizedLessonName) && 
                normalizedPath.contains(normalizedTopicName)) {
              pdfUrl = entry.value;
              print('   ✅ Found match: ${entry.key}');
              break;
            } else {
              print('         ❌ No match');
            }
          }
          
          // Method 2: Look for topics/{topicFolderName}/{anyPdf}.pdf (without lesson folder)
          if (pdfUrl == null) {
            print('   🔎 Method 2: Looking for path with topic name only...');
            for (var entry in pdfFilesByPath.entries) {
              final path = entry.key.toLowerCase();
              final normalizedPath = _normalizePath(path);
              
              print('      Checking: ${entry.key}');
              print('         Normalized path: "$normalizedPath"');
              print('         Contains topic? ${normalizedPath.contains(normalizedTopicName)}');
              print('         Contains lesson? ${normalizedPath.contains(normalizedLessonName)}');
              
              // Check if path contains topic name (might be directly under topics/)
              if (normalizedPath.contains(normalizedTopicName) && 
                  !normalizedPath.contains(normalizedLessonName)) {
                // Make sure it's not in another lesson's folder
                final pathParts = normalizedPath.split('/');
                if (pathParts.length >= 2 && pathParts[0] == 'topics') {
                  pdfUrl = entry.value;
                  print('   ✅ Found match (without lesson folder): ${entry.key}');
                  break;
                } else {
                  print('         ❌ Path structure not valid');
                }
              } else {
                print('         ❌ No match');
              }
            }
          }
          
          // Method 3: Try partial matching (topic name contains or is contained by folder name)
          if (pdfUrl == null) {
            print('   🔎 Method 3: Trying partial matching...');
            for (var entry in pdfFilesByPath.entries) {
              final path = entry.key.toLowerCase();
              final pathParts = path.split('/');
              
              // Check each folder name in the path
              for (var part in pathParts) {
                final normalizedPart = _normalizePath(part);
                print('      Checking folder part: "$part" (normalized: "$normalizedPart")');
                
                // Check if this part is similar to topic name
                if ((normalizedPart.contains(normalizedTopicName) && normalizedTopicName.length > 5) ||
                    (normalizedTopicName.contains(normalizedPart) && normalizedPart.length > 5)) {
                  pdfUrl = entry.value;
                  print('   ✅ Found match (partial): ${entry.key}');
                  break;
                }
              }
              if (pdfUrl != null) break;
            }
          }
        } else {
          print('   ⚠️  Lesson not found for lessonId: ${topic.lessonId}');
        }
        
        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          // Update Firestore
          await _firestore.collection('topics').doc(topic.id).update({
            'pdfUrl': pdfUrl,
          });
          print('✅ Updated: ${topic.name} -> ${pdfUrl.substring(0, pdfUrl.length > 50 ? 50 : pdfUrl.length)}...');
          updatedCount++;
        } else {
          print('⚠️  No PDF found for: ${topic.name} (ID: ${topic.id})');
          notFoundCount++;
        }
      }
      
      print('\n📊 Summary:');
      print('   ✅ Updated: $updatedCount topics');
      print('   ⚠️  Not found: $notFoundCount topics');
      print('✅ PDF URL update process completed!');
    } catch (e) {
      print('❌ Error updating PDF URLs: $e');
      print('Error type: ${e.runtimeType}');
    }
  }

  /// Normalize topic name for matching (lowercase, remove special chars, handle Turkish chars)
  String _normalizeTopicName(String name) {
    return name
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  /// Normalize path for matching
  String _normalizePath(String path) {
    return path
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }

  /// Update PDF URL for a specific topic
  /// 
  /// [storagePath] should be the full path in Storage, e.g., 'topics/tarih/islamiyet_oncesi_turk_tarihi.pdf'
  Future<bool> updateTopicPdfUrl({
    required String topicId,
    required String storagePath,
  }) async {
    try {
      print('📝 Updating PDF URL for topic: $topicId');
      print('📁 Storage path: $storagePath');
      
      // Get download URL from Storage
      final storageRef = _storage.ref().child(storagePath);
      final pdfUrl = await storageRef.getDownloadURL();
      
      print('🔗 PDF URL: $pdfUrl');
      
      // Update Firestore
      await _firestore.collection('topics').doc(topicId).update({
        'pdfUrl': pdfUrl,
      });
      
      print('✅ PDF URL updated successfully!');
      return true;
    } catch (e) {
      print('❌ Error updating PDF URL: $e');
      return false;
    }
  }

  /// List all PDF files in Firebase Storage with recursive folder scanning
  /// Returns a map of storage path -> download URL
  /// This method scans all subfolders recursively to find PDFs
  Future<Map<String, String>> _listAllPdfFilesWithStructure() async {
    final Map<String, String> pdfFiles = {};
    
    try {
      // Start from topics/ folder
      final topicsRef = _storage.ref().child('topics');
      
      try {
        await _scanFolderRecursively(topicsRef, pdfFiles);
      } catch (e) {
        print('⚠️  Error listing topics folder: $e');
        print('💡 Trying alternative paths...');
        
        // Try alternative: pdfs/ folder
        try {
          final pdfsRef = _storage.ref().child('pdfs');
          await _scanFolderRecursively(pdfsRef, pdfFiles);
        } catch (e2) {
          print('⚠️  Error listing pdfs folder: $e2');
        }
      }
    } catch (e) {
      print('❌ Error listing PDF files: $e');
    }
    
    return pdfFiles;
  }

  /// Recursively scan a folder and all its subfolders for PDF files
  Future<void> _scanFolderRecursively(
    Reference folderRef,
    Map<String, String> pdfFiles,
  ) async {
    try {
      final result = await folderRef.listAll();
      
      // List PDF files in current folder
      for (var item in result.items) {
        if (item.name.toLowerCase().endsWith('.pdf')) {
          try {
            final url = await item.getDownloadURL();
            pdfFiles[item.fullPath] = url;
            print('📄 Found PDF: ${item.fullPath}');
          } catch (e) {
            print('⚠️  Error getting URL for ${item.name}: $e');
          }
        }
      }
      
      // Recursively scan subfolders
      for (var prefix in result.prefixes) {
        print('📁 Scanning subfolder: ${prefix.fullPath}');
        await _scanFolderRecursively(prefix, pdfFiles);
      }
    } catch (e) {
      print('⚠️  Error scanning folder ${folderRef.fullPath}: $e');
    }
  }

  /// Get all topics (helper method)
  Future<List<Map<String, dynamic>>> getAllTopics() async {
    try {
      final snapshot = await _firestore.collection('topics').get();
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('❌ Error getting topics: $e');
      return [];
    }
  }
}

