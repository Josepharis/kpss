import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../models/flash_card.dart';

/// Service to cache flash card files locally to avoid re-downloading on every access
class FlashCardCacheService {
  static const String _cacheDirName = 'flash_card_cache';
  static Directory? _cacheDir;

  /// Initialize cache directory
  static Future<void> _initCacheDir() async {
    if (_cacheDir != null) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(appDir.path, _cacheDirName));
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        print('📁 Flash card cache directory created: ${_cacheDir!.path}');
      }
    } catch (e) {
      print('❌ Error initializing flash card cache directory: $e');
    }
  }

  /// Extract file path from Firebase Storage URL
  /// Firebase Storage URL format: https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encodedPath}?alt=media&token={token}
  static String? _extractFilePathFromUrl(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      
      // Firebase Storage URL formatını parse et
      // Örnek: https://firebasestorage.googleapis.com/v0/b/bucket/o/path%2Fto%2Ffile.csv?alt=media&token=xxx
      final path = uri.path;
      
      // /o/ kısmından sonrasını al
      if (path.contains('/o/')) {
        final parts = path.split('/o/');
        if (parts.length > 1) {
          // Query parametrelerini temizle
          var encodedPath = parts[1].split('?').first;
          // URL decode (Firebase Storage path'leri %2F ile encode edilmiş olabilir)
          final decodedPath = Uri.decodeComponent(encodedPath);
          return decodedPath;
        }
      }
      
      // Alternatif: Path segmentlerinden al
      final segments = uri.pathSegments;
      if (segments.length >= 4 && segments[0] == 'v0' && segments[1] == 'b' && segments[3] == 'o') {
        // {encodedPath} kısmını al (4. segment'ten itibaren)
        final encodedPath = segments.sublist(4).join('/');
        final decodedPath = Uri.decodeComponent(encodedPath);
        return decodedPath;
      }
      
      return null;
    } catch (e) {
      print('⚠️ Error extracting file path from URL: $e');
      return null;
    }
  }

  /// Get cache file path for a flash card file
  /// Uses file path (not URL with tokens) for consistent caching
  static String _getCacheFileName(String filePath) {
    // Path'ten hash oluştur (token'lar değişse bile aynı dosya için aynı hash)
    final bytes = utf8.encode(filePath);
    final digest = sha256.convert(bytes);
    return '${digest.toString()}.json';
  }
  
  /// Get cache file name from URL (extracts path first)
  static String _getCacheFileNameFromUrl(String fileUrl) {
    // Önce dosya path'ini çıkar
    final filePath = _extractFilePathFromUrl(fileUrl);
    if (filePath != null && filePath.isNotEmpty) {
      return _getCacheFileName(filePath);
    }
    // Fallback: URL'den hash oluştur (ama token'lar değişirse cache çalışmaz)
    return _getCacheFileName(fileUrl);
  }

  /// Check if flash card file is cached locally (by file path)
  static Future<bool> isCachedByPath(String filePath) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) return false;
      
      final fileName = _getCacheFileName(filePath);
      final file = File(path.join(_cacheDir!.path, fileName));
      final exists = await file.exists();
      if (exists) {
        print('✅ Cache hit for: $filePath');
      } else {
        print('❌ Cache miss for: $filePath');
      }
      return exists;
    } catch (e) {
      print('⚠️ Error checking flash card cache: $e');
      return false;
    }
  }

  /// Check if flash card file is cached locally (by URL)
  static Future<bool> isCached(String fileUrl) async {
    final filePath = _extractFilePathFromUrl(fileUrl);
    if (filePath != null && filePath.isNotEmpty) {
      return isCachedByPath(filePath);
    }
    // Fallback: URL'den cache key oluştur
    try {
      await _initCacheDir();
      if (_cacheDir == null) return false;
      
      final fileName = _getCacheFileNameFromUrl(fileUrl);
      final file = File(path.join(_cacheDir!.path, fileName));
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get cached flash card file path (by file path)
  /// Returns null if not cached
  static Future<String?> getCachedPathByPath(String filePath) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) return null;
      
      if (!await isCachedByPath(filePath)) return null;
      
      final fileName = _getCacheFileName(filePath);
      return path.join(_cacheDir!.path, fileName);
    } catch (e) {
      print('⚠️ Error getting cached flash card path: $e');
      return null;
    }
  }

  /// Get cached flash card file path (by URL)
  /// Returns null if not cached
  static Future<String?> getCachedPath(String fileUrl) async {
    final filePath = _extractFilePathFromUrl(fileUrl);
    if (filePath != null && filePath.isNotEmpty) {
      return getCachedPathByPath(filePath);
    }
    // Fallback
    try {
      if (!await isCached(fileUrl)) return null;
      
      final fileName = _getCacheFileNameFromUrl(fileUrl);
      return path.join(_cacheDir!.path, fileName);
    } catch (e) {
      print('⚠️ Error getting cached flash card path: $e');
      return null;
    }
  }

  /// Get cached flash cards from file (by file path)
  static Future<List<FlashCard>> getCachedCardsByPath(String filePath) async {
    try {
      final cachedPath = await getCachedPathByPath(filePath);
      if (cachedPath == null) return [];

      final file = File(cachedPath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final jsonData = json.decode(content);
      
      if (jsonData is List) {
        return jsonData.map((cardData) => FlashCard(
          id: cardData['id'] ?? '',
          frontText: cardData['frontText'] ?? cardData['front'] ?? '',
          backText: cardData['backText'] ?? cardData['back'] ?? '',
          isLearned: cardData['isLearned'] ?? false,
        )).toList();
      }
      
      return [];
    } catch (e) {
      print('⚠️ Error reading cached flash cards: $e');
      return [];
    }
  }

  /// Get cached flash cards from file (by URL)
  static Future<List<FlashCard>> getCachedCards(String fileUrl) async {
    final filePath = _extractFilePathFromUrl(fileUrl);
    if (filePath != null && filePath.isNotEmpty) {
      return getCachedCardsByPath(filePath);
    }
    // Fallback
    try {
      final cachedPath = await getCachedPath(fileUrl);
      if (cachedPath == null) return [];

      final file = File(cachedPath);
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final jsonData = json.decode(content);
      
      if (jsonData is List) {
        return jsonData.map((cardData) => FlashCard(
          id: cardData['id'] ?? '',
          frontText: cardData['frontText'] ?? cardData['front'] ?? '',
          backText: cardData['backText'] ?? cardData['back'] ?? '',
          isLearned: cardData['isLearned'] ?? false,
        )).toList();
      }
      
      return [];
    } catch (e) {
      print('⚠️ Error reading cached flash cards: $e');
      return [];
    }
  }

  /// Download and cache flash card file from URL
  /// Returns list of FlashCard objects if successful, empty list otherwise
  static Future<List<FlashCard>> cacheFlashCards(String fileUrl) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) {
        print('❌ Cache directory not initialized');
        return [];
      }

      // Check if already cached
      if (await isCached(fileUrl)) {
        print('✅ Flash cards already cached');
        return await getCachedCards(fileUrl);
      }

      print('📥 Downloading flash cards from: $fileUrl');
      
      // Download file
      final response = await http.get(Uri.parse(fileUrl));
      
      if (response.statusCode != 200) {
        print('❌ Failed to download flash cards: ${response.statusCode}');
        return [];
      }

      // Parse content
      final body = utf8.decode(response.bodyBytes);
      final contentType = response.headers['content-type'] ?? '';
      final fileName = fileUrl.toLowerCase();
      
      List<FlashCard> cards = [];
      
      // CSV formatını kontrol et
      if (fileName.endsWith('.csv') || contentType.contains('csv') || 
          body.trim().startsWith('front') || 
          body.contains(',')) {
        // CSV formatını parse et
        final lines = body.split('\n');
        if (lines.isNotEmpty) {
          final startIndex = lines[0].toLowerCase().contains('front') ? 1 : 0;
          
          for (int i = startIndex; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;
            
            List<String> parts = [];
            bool inQuotes = false;
            String currentPart = '';
            
            for (int j = 0; j < line.length; j++) {
              final char = line[j];
              if (char == '"') {
                inQuotes = !inQuotes;
              } else if (char == ',' && !inQuotes) {
                parts.add(currentPart.trim());
                currentPart = '';
              } else {
                currentPart += char;
              }
            }
            parts.add(currentPart.trim());
            
            if (parts.length >= 2) {
              final front = parts[0].replaceAll('"', '').trim();
              final back = parts[1].replaceAll('"', '').trim();
              
              if (front.isNotEmpty && back.isNotEmpty) {
                cards.add(FlashCard(
                  id: '${cards.length + 1}',
                  frontText: front,
                  backText: back,
                  isLearned: false,
                ));
              }
            }
          }
        }
      } else {
        // JSON formatını parse et
        final jsonData = json.decode(body);
        
        if (jsonData is List) {
          for (var cardData in jsonData) {
            cards.add(FlashCard(
              id: cardData['id'] ?? '${cards.length + 1}',
              frontText: cardData['frontText'] ?? cardData['front'] ?? '',
              backText: cardData['backText'] ?? cardData['back'] ?? '',
              isLearned: cardData['isLearned'] ?? false,
            ));
          }
        } else if (jsonData is Map) {
          if (jsonData['cards'] != null && jsonData['cards'] is List) {
            for (var cardData in jsonData['cards']) {
              cards.add(FlashCard(
                id: cardData['id'] ?? '${cards.length + 1}',
                frontText: cardData['frontText'] ?? cardData['front'] ?? '',
                backText: cardData['backText'] ?? cardData['back'] ?? '',
                isLearned: cardData['isLearned'] ?? false,
              ));
            }
          } else {
            cards.add(FlashCard(
              id: jsonData['id'] ?? '1',
              frontText: jsonData['frontText'] ?? jsonData['front'] ?? '',
              backText: jsonData['backText'] ?? jsonData['back'] ?? '',
              isLearned: jsonData['isLearned'] ?? false,
            ));
          }
        }
      }

      // Save to cache (use file path from URL for consistent caching)
      final filePath = _extractFilePathFromUrl(fileUrl);
      final cacheFileName = filePath != null && filePath.isNotEmpty 
          ? _getCacheFileName(filePath) 
          : _getCacheFileNameFromUrl(fileUrl);
      
      final file = File(path.join(_cacheDir!.path, cacheFileName));
      final jsonCards = cards.map((card) => {
        'id': card.id,
        'frontText': card.frontText,
        'backText': card.backText,
        'isLearned': card.isLearned,
      }).toList();
      await file.writeAsString(json.encode(jsonCards));
      
      print('✅ Flash cards cached successfully: ${file.path}');
      print('📊 Cached ${cards.length} cards (key: ${filePath ?? fileUrl})');
      
      return cards;
    } catch (e) {
      print('❌ Error caching flash cards: $e');
      return [];
    }
  }

  /// Download and cache flash card file (using explicit file path for cache key)
  /// Returns list of FlashCard objects if successful, empty list otherwise
  static Future<List<FlashCard>> cacheFlashCardsByPath(String fileUrl, String filePath) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) {
        print('❌ Cache directory not initialized');
        return [];
      }

      // Check if already cached
      if (await isCachedByPath(filePath)) {
        print('✅ Flash cards already cached');
        return await getCachedCardsByPath(filePath);
      }

      print('📥 Downloading flash cards from: $fileUrl');
      print('   Cache key: $filePath');
      
      // Download file
      final response = await http.get(Uri.parse(fileUrl));
      
      if (response.statusCode != 200) {
        print('❌ Failed to download flash cards: ${response.statusCode}');
        return [];
      }

      // Parse content
      final body = utf8.decode(response.bodyBytes);
      final contentType = response.headers['content-type'] ?? '';
      final fileName = fileUrl.toLowerCase();
      
      List<FlashCard> cards = [];
      
      // CSV formatını kontrol et
      if (fileName.endsWith('.csv') || contentType.contains('csv') || 
          body.trim().startsWith('front') || 
          body.contains(',')) {
        // CSV formatını parse et
        final lines = body.split('\n');
        if (lines.isNotEmpty) {
          final startIndex = lines[0].toLowerCase().contains('front') ? 1 : 0;
          
          for (int i = startIndex; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;
            
            List<String> parts = [];
            bool inQuotes = false;
            String currentPart = '';
            
            for (int j = 0; j < line.length; j++) {
              final char = line[j];
              if (char == '"') {
                inQuotes = !inQuotes;
              } else if (char == ',' && !inQuotes) {
                parts.add(currentPart.trim());
                currentPart = '';
              } else {
                currentPart += char;
              }
            }
            if (currentPart.isNotEmpty) {
              parts.add(currentPart.trim());
            }
            
            if (parts.length >= 2) {
              cards.add(FlashCard(
                id: '${cards.length + 1}',
                frontText: parts[0].replaceAll('"', '').trim(),
                backText: parts[1].replaceAll('"', '').trim(),
              ));
            }
          }
        }
      } else {
        // JSON formatını parse et
        final jsonData = json.decode(body);
        
        if (jsonData is List) {
          for (var cardData in jsonData) {
            cards.add(FlashCard(
              id: cardData['id'] ?? '${cards.length + 1}',
              frontText: cardData['frontText'] ?? cardData['front'] ?? '',
              backText: cardData['backText'] ?? cardData['back'] ?? '',
              isLearned: cardData['isLearned'] ?? false,
            ));
          }
        } else if (jsonData is Map) {
          if (jsonData['cards'] != null && jsonData['cards'] is List) {
            for (var cardData in jsonData['cards']) {
              cards.add(FlashCard(
                id: cardData['id'] ?? '${cards.length + 1}',
                frontText: cardData['frontText'] ?? cardData['front'] ?? '',
                backText: cardData['backText'] ?? cardData['back'] ?? '',
                isLearned: cardData['isLearned'] ?? false,
              ));
            }
          } else {
            cards.add(FlashCard(
              id: jsonData['id'] ?? '1',
              frontText: jsonData['frontText'] ?? jsonData['front'] ?? '',
              backText: jsonData['backText'] ?? jsonData['back'] ?? '',
              isLearned: jsonData['isLearned'] ?? false,
            ));
          }
        }
      }

      // Save to cache (use filePath as cache key)
      final cacheFileName = _getCacheFileName(filePath);
      final file = File(path.join(_cacheDir!.path, cacheFileName));
      final jsonCards = cards.map((card) => {
        'id': card.id,
        'frontText': card.frontText,
        'backText': card.backText,
        'isLearned': card.isLearned,
      }).toList();
      await file.writeAsString(json.encode(jsonCards));
      
      print('✅ Flash cards cached successfully: ${file.path}');
      print('📊 Cached ${cards.length} cards (key: $filePath)');
      
      return cards;
    } catch (e) {
      print('❌ Error caching flash cards: $e');
      return [];
    }
  }

  /// Get flash cards (cached or download)
  /// This is the main method to use - it handles caching automatically
  static Future<List<FlashCard>> getFlashCards(String fileUrl) async {
    try {
      // First check cache
      if (await isCached(fileUrl)) {
        print('📂 Using cached flash cards');
        return await getCachedCards(fileUrl);
      }

      // Not cached, download and cache
      print('🌐 Flash cards not cached, downloading...');
      return await cacheFlashCards(fileUrl);
    } catch (e) {
      print('❌ Error getting flash cards: $e');
      return [];
    }
  }

  /// Clear all cached flash cards
  static Future<void> clearCache() async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) return;
      
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        print('🗑️ Flash card cache cleared');
      }
    } catch (e) {
      print('❌ Error clearing flash card cache: $e');
    }
  }

  /// Get cache size in MB
  static Future<double> getCacheSize() async {
    try {
      await _initCacheDir();
      if (_cacheDir == null || !await _cacheDir!.exists()) return 0.0;
      
      int totalSize = 0;
      await for (var entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize / 1024 / 1024; // Convert to MB
    } catch (e) {
      print('⚠️ Error calculating cache size: $e');
      return 0.0;
    }
  }
}
