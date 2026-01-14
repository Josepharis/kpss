import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
      
      
      final uploadTask = storageRef.putFile(
        audioFile,
        SettableMetadata(
          contentType: 'audio/mpeg', // MP3 için
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Upload progress (silent)

      await uploadTask;
      
      final downloadUrl = await storageRef.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading audio file: $e');
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
      
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image file: $e');
      return null;
    }
  }

  /// Delete file from Firebase Storage
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      return false;
    }
  }

  /// Get storage path from URL
  /// Returns the full path if URL is a Firebase Storage URL, null otherwise
  String? getPathFromUrl(String url) {
    try {
      final ref = _storage.refFromURL(url);
      return ref.fullPath;
    } catch (e) {
      return null;
    }
  }

  /// List video files in a folder and get their download URLs
  /// Returns list of download URLs
  Future<List<String>> listVideoFiles(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        
        // Alt klasörleri de listele
        for (var prefix in result.prefixes) {
          try {
            await prefix.listAll();
          } catch (e) {
            // Silent error handling
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
            } catch (e) {
              // Silent error handling
            }
          }
        }
        return urls;
      } catch (e) {
        debugPrint('⚠️ Error listing folder: $e');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error listing video files: $e');
      return [];
    }
  }

  /// List folders (subdirectories) in a folder
  /// Returns list of folder names
  Future<List<String>> listFolders(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        
        final List<String> folderNames = [];
        for (var prefix in result.prefixes) {
          folderNames.add(prefix.name);
        }
        
        // Klasörleri sırala (sayısal prefix varsa ona göre)
        folderNames.sort((a, b) {
          // Sayısal prefix'i çıkar ve karşılaştır
          final aMatch = RegExp(r'^(\d+)[-.]?\s*(.*)').firstMatch(a);
          final bMatch = RegExp(r'^(\d+)[-.]?\s*(.*)').firstMatch(b);
          
          if (aMatch != null && bMatch != null) {
            final aNum = int.tryParse(aMatch.group(1) ?? '') ?? 0;
            final bNum = int.tryParse(bMatch.group(1) ?? '') ?? 0;
            if (aNum != bNum) return aNum.compareTo(bNum);
          }
          
          return a.compareTo(b);
        });
        return folderNames;
      } catch (e) {
        debugPrint('⚠️ Error listing folders: $e');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error listing folders: $e');
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
      debugPrint('⚠️ Error counting files in $folderPath: $e');
      return 0;
    }
  }

  /// List file names in a folder (fast - no download URLs, just names)
  /// Returns list of file names (sorted alphabetically)
  Future<List<String>> listFileNames(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      final result = await folderRef.listAll();
      final fileNames = result.items.map((item) => item.name).toList();
      
      // Alt klasörlerdeki dosyaları da kontrol et
      for (var prefix in result.prefixes) {
        try {
          final subResult = await prefix.listAll();
          for (var item in subResult.items) {
            fileNames.add(item.name);
          }
        } catch (e) {
          debugPrint('   ⚠️ Error listing subfolder ${prefix.name}: $e');
        }
      }
      
      // Alfabetik olarak sırala (aynı içerik sorununu çözmek için)
      fileNames.sort();
      return fileNames;
    } catch (e) {
      debugPrint('⚠️ Error listing file names in $folderPath: $e');
      return [];
    }
  }

  /// List files in a folder and get their download URLs (for any file type)
  /// Returns list of maps with 'url' and 'fullPath' keys for cache support
  Future<List<Map<String, String>>> listFilesWithPaths(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        
        final List<Map<String, String>> files = [];
        for (var item in result.items) {
          try {
            final url = await item.getDownloadURL();
            files.add({
              'url': url,
              'fullPath': item.fullPath,
              'name': item.name,
            });
          } catch (e) {
            // Silent error handling
          }
        }
        return files;
      } catch (e) {
        debugPrint('⚠️ Error listing folder: $e');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error listing files: $e');
      return [];
    }
  }

  /// List files in a folder and get their download URLs (for any file type)
  /// Returns list of download URLs
  /// DEPRECATED: Use listFilesWithPaths() for cache support
  Future<List<String>> listFiles(String folderPath) async {
    final filesWithPaths = await listFilesWithPaths(folderPath);
    return filesWithPaths.map((f) => f['url']!).toList();
  }

  /// List JSON files in a folder and get their download URLs
  /// Returns list of download URLs for JSON files
  Future<List<String>> listJsonFiles(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      
      try {
        final result = await folderRef.listAll();
        
        // Filter only JSON files
        final jsonItems = result.items.where((item) {
          final fileName = item.name.toLowerCase();
          return fileName.endsWith('.json');
        }).toList();
        
        // Sort alphabetically
        jsonItems.sort((a, b) => a.name.compareTo(b.name));
        
        final List<String> urls = [];
        for (var item in jsonItems) {
          try {
            final url = await item.getDownloadURL();
            urls.add(url);
          } catch (e) {
            // Silent error handling
          }
        }
        return urls;
      } catch (e) {
        debugPrint('⚠️ Error listing folder: $e');
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Download and parse JSON file from Storage path
  /// Returns parsed JSON as Map
  /// Handles common JSON formatting issues (trailing commas, missing commas)
  Future<Map<String, dynamic>?> downloadAndParseJson(String storagePath) async {
    try {
      final storageRef = _storage.ref().child(storagePath);
      
      // Download as bytes and convert to string
      final bytes = await storageRef.getData();
      if (bytes == null) {
        return null;
      }
      
      String jsonString = utf8.decode(bytes);
      
      
      // Try to fix common JSON issues before parsing (always use aggressive mode for Storage files)
      jsonString = _fixJsonString(jsonString, aggressive: true);
      
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonData;
    } catch (e) {
      
      // Try one more time with line-by-line fixes
      try {
        final storageRef = _storage.ref().child(storagePath);
        final bytes = await storageRef.getData();
        if (bytes != null) {
          String jsonString = utf8.decode(bytes);
          
          // Line-by-line fix for trailing commas
          final lines = jsonString.split('\n');
          final fixedLines = <String>[];
          
          for (int i = 0; i < lines.length; i++) {
            String line = lines[i];
            
            // Check if next line starts with } or ]
            if (i < lines.length - 1) {
              final nextLine = lines[i + 1].trim();
              if (nextLine.startsWith('}') || nextLine.startsWith(']')) {
                // Remove trailing comma from current line
                line = line.replaceAll(RegExp(r',\s*$'), '');
              }
            }
            
            // Also check if current line ends with , and next non-empty line is } or ]
            if (line.trim().endsWith(',')) {
              bool shouldRemoveComma = false;
              for (int j = i + 1; j < lines.length; j++) {
                final futureLine = lines[j].trim();
                if (futureLine.isEmpty) continue;
                if (futureLine.startsWith('}') || futureLine.startsWith(']')) {
                  shouldRemoveComma = true;
                }
                break;
              }
              if (shouldRemoveComma) {
                line = line.replaceAll(RegExp(r',\s*$'), '');
              }
            }
            
            fixedLines.add(line);
          }
          
          jsonString = fixedLines.join('\n');
          jsonString = _fixJsonString(jsonString, aggressive: true);
          
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          return jsonData;
        }
      } catch (e2) {
        debugPrint('❌ Still failed after fixes: $e2');
        debugPrint('Error details: ${e2.toString()}');
      }
      
      return null;
    }
  }

  /// Fix common JSON formatting issues
  String _fixJsonString(String jsonString, {bool aggressive = false}) {
    
    // Step 1: Remove trailing commas before closing braces/brackets
    // Pattern: ,\s*} or ,\s*] (with any whitespace, including newlines)
    // This is the most common issue - trailing comma before closing brace
    jsonString = jsonString.replaceAll(RegExp(r',\s*\}'), '}');
    jsonString = jsonString.replaceAll(RegExp(r',\s*\]'), ']');
    // Also handle cases where comma is on previous line
    jsonString = jsonString.replaceAll(RegExp(r',\s*\n\s*\}'), '\n  }');
    jsonString = jsonString.replaceAll(RegExp(r',\s*\n\s*\]'), '\n  ]');
    
    // Step 2: Fix missing commas between objects in arrays
    // Pattern: }\s*\n\s*{ should become },\n    {
    // This handles the case where objects are on separate lines
    final beforeFix = jsonString;
    jsonString = jsonString.replaceAll(RegExp(r'\}\s*\n\s*\{'), '},\n    {');
    if (jsonString != beforeFix) {
    }
    
    if (aggressive) {
      // Step 3: More aggressive fixes
      
      // Fix any } followed by { (even without newline)
      // But be careful: only if there's whitespace and no comma before
      jsonString = jsonString.replaceAllMapped(
        RegExp(r'\}\s+\{'),
        (match) {
          final startPos = match.start;
          if (startPos > 0) {
            final beforeChar = jsonString[startPos - 1];
            // If there's already a comma or it's an array start, don't add another
            if (beforeChar == ',' || beforeChar == '[') {
              return match.group(0)!;
            }
          }
          return '}, {';
        },
      );
      
      // Fix missing commas between array elements
      // Pattern: ]\s*[ should become ],\s*[
      jsonString = jsonString.replaceAll(RegExp(r'\]\s*\['), '], [');
    }
    
    return jsonString;
  }

  /// Download and parse JSON file from URL (for external URLs)
  /// Returns parsed JSON as Map
  Future<Map<String, dynamic>?> downloadAndParseJsonFromUrl(String jsonUrl) async {
    try {
      // If it's a Firebase Storage URL, extract the path
      if (jsonUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = _storage.refFromURL(jsonUrl);
          final bytes = await ref.getData();
          if (bytes == null) {
            return null;
          }
          final jsonString = utf8.decode(bytes);
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          return jsonData;
        } catch (e) {
          // Silent error handling
        }
      }
      
      // Fallback to HTTP (requires http package)
      // For now, return null if not a Storage URL
      // Silent error handling
      return null;
    } catch (e) {
      return null;
    }
  }

  /// List audio files in a folder and get their download URLs
  /// Returns list of download URLs
  Future<List<String>> listAudioFiles(String folderPath) async {
    try {
      final folderRef = _storage.ref().child(folderPath);
      
      // Önce klasörün var olup olmadığını kontrol et
      try {
        final result = await folderRef.listAll();
        
        // Önce sadece audio dosyalarını filtrele ve sırala
        final audioItems = result.items.where((item) {
          final fileName = item.name.toLowerCase();
          return fileName.endsWith('.mp3') || 
                 fileName.endsWith('.m4a') || 
                 fileName.endsWith('.wav') ||
                 fileName.endsWith('.aac');
        }).toList();
        
        // Alt klasörlerdeki dosyaları da kontrol et
        for (var prefix in result.prefixes) {
          try {
            final subResult = await prefix.listAll();
            for (var item in subResult.items) {
              final fileName = item.name.toLowerCase();
              if (fileName.endsWith('.mp3') || 
                  fileName.endsWith('.m4a') || 
                  fileName.endsWith('.wav') ||
                  fileName.endsWith('.aac')) {
                audioItems.add(item);
              }
            }
          } catch (e) {
            // Silent error handling
          }
        }
        
        // Dosyaları alfabetik olarak sırala (aynı içerik sorununu çözmek için)
        audioItems.sort((a, b) => a.name.compareTo(b.name));
        
        final List<String> urls = [];
        for (var item in audioItems) {
          try {
            final url = await item.getDownloadURL();
            urls.add(url);
          } catch (e) {
            // Silent error handling
          }
        }
        return urls;
      } catch (e) {
        debugPrint('❌ Error listing folder: $e');
        
        // Eğer klasör yoksa, root'tan podcasts klasörünü kontrol et
        try {
          final rootRef = _storage.ref().child('podcasts');
          await rootRef.listAll();
        } catch (rootError) {
          debugPrint('❌ Error listing root: $rootError');
        }
        
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error listing files: $e');
      debugPrint('Error type: ${e.runtimeType}');
      return [];
    }
  }
}

