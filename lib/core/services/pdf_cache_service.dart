import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service to cache PDF files locally to save Firebase Storage bandwidth
class PdfCacheService {
  static const String _cacheDirName = 'pdf_cache';
  static Directory? _cacheDir;

  /// Initialize cache directory
  static Future<void> _initCacheDir() async {
    if (_cacheDir != null) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(appDir.path, _cacheDirName));
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
        print('📁 PDF cache directory created: ${_cacheDir!.path}');
      }
    } catch (e) {
      print('❌ Error initializing PDF cache directory: $e');
    }
  }

  /// Get cache file path for a PDF URL
  static String _getCacheFileName(String pdfUrl) {
    // Create a hash of the URL to use as filename
    final bytes = utf8.encode(pdfUrl);
    final digest = sha256.convert(bytes);
    return '${digest.toString()}.pdf';
  }

  /// Check if PDF is cached locally
  static Future<bool> isCached(String pdfUrl) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) return false;
      
      final fileName = _getCacheFileName(pdfUrl);
      final file = File(path.join(_cacheDir!.path, fileName));
      return await file.exists();
    } catch (e) {
      print('⚠️ Error checking PDF cache: $e');
      return false;
    }
  }

  /// Get cached PDF file path
  /// Returns null if not cached
  static Future<String?> getCachedPath(String pdfUrl) async {
    try {
      if (!await isCached(pdfUrl)) return null;
      
      final fileName = _getCacheFileName(pdfUrl);
      return path.join(_cacheDir!.path, fileName);
    } catch (e) {
      print('⚠️ Error getting cached PDF path: $e');
      return null;
    }
  }

  /// Download and cache PDF from URL
  /// Returns local file path if successful, null otherwise
  static Future<String?> cachePdf(String pdfUrl) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) {
        print('❌ Cache directory not initialized');
        return null;
      }

      // Check if already cached
      if (await isCached(pdfUrl)) {
        print('✅ PDF already cached');
        return await getCachedPath(pdfUrl);
      }

      print('📥 Downloading PDF from: $pdfUrl');
      
      // Download PDF
      final response = await http.get(Uri.parse(pdfUrl));
      
      if (response.statusCode != 200) {
        print('❌ Failed to download PDF: ${response.statusCode}');
        return null;
      }

      // Save to cache
      final fileName = _getCacheFileName(pdfUrl);
      final file = File(path.join(_cacheDir!.path, fileName));
      await file.writeAsBytes(response.bodyBytes);
      
      print('✅ PDF cached successfully: ${file.path}');
      print('📊 File size: ${(response.bodyBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      
      return file.path;
    } catch (e) {
      print('❌ Error caching PDF: $e');
      return null;
    }
  }

  /// Get PDF path (cached or download)
  /// This is the main method to use - it handles caching automatically
  static Future<String?> getPdfPath(String pdfUrl) async {
    try {
      // First check cache
      if (await isCached(pdfUrl)) {
        print('📂 Using cached PDF');
        return await getCachedPath(pdfUrl);
      }

      // Not cached, download and cache
      print('🌐 PDF not cached, downloading...');
      return await cachePdf(pdfUrl);
    } catch (e) {
      print('❌ Error getting PDF path: $e');
      return null;
    }
  }

  /// Clear all cached PDFs
  static Future<void> clearCache() async {
    try {
      await _initCacheDir();
      if (_cacheDir == null) return;
      
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
        print('🗑️ PDF cache cleared');
      }
    } catch (e) {
      print('❌ Error clearing PDF cache: $e');
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

  /// Delete old cached PDFs (older than specified days)
  static Future<void> deleteOldCache({int daysOld = 30}) async {
    try {
      await _initCacheDir();
      if (_cacheDir == null || !await _cacheDir!.exists()) return;
      
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int deletedCount = 0;
      
      await for (var entity in _cacheDir!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      if (deletedCount > 0) {
        print('🗑️ Deleted $deletedCount old cached PDFs');
      }
    } catch (e) {
      print('❌ Error deleting old cache: $e');
    }
  }
}

