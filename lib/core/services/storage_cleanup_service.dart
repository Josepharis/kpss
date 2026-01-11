import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for automatic cleanup of downloaded content
class StorageCleanupService {
  static const String _prefsKeyLastAccess = 'last_access_';
  static const String _prefsKeyCleanupEnabled = 'auto_cleanup_enabled';
  static const String _prefsKeyCleanupDays = 'auto_cleanup_days';
  static const String _prefsKeyMaxStorageGB = 'max_storage_gb';
  
  // Default values
  static const bool _defaultCleanupEnabled = true;
  static const int _defaultCleanupDays = 7; // 1 hafta
  static const double _defaultMaxStorageGB = 5.0; // 5 GB limit
  
  /// Get last access time for a file
  Future<DateTime?> getLastAccessTime(String fileUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = _getFileNameFromUrl(fileUrl);
    final timestamp = prefs.getInt('$_prefsKeyLastAccess$fileName');
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }
  
  /// Update last access time for a file
  Future<void> updateLastAccessTime(String fileUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = _getFileNameFromUrl(fileUrl);
    await prefs.setInt('$_prefsKeyLastAccess$fileName', DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Generate file name from URL (same as download services)
  String _getFileNameFromUrl(String url) {
    final bytes = utf8.encode(url);
    final hash = sha256.convert(bytes);
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    String extension = '';
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        extension = '.${lastSegment.split('.').last}';
      }
    }
    return '${hash.toString()}$extension';
  }
  
  /// Check if auto cleanup is enabled
  Future<bool> isAutoCleanupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKeyCleanupEnabled) ?? _defaultCleanupEnabled;
  }
  
  /// Set auto cleanup enabled/disabled
  Future<void> setAutoCleanupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyCleanupEnabled, enabled);
  }
  
  /// Get cleanup days (how many days before deleting)
  Future<int> getCleanupDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefsKeyCleanupDays) ?? _defaultCleanupDays;
  }
  
  /// Set cleanup days
  Future<void> setCleanupDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKeyCleanupDays, days);
  }
  
  /// Get max storage limit in GB
  Future<double> getMaxStorageGB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_prefsKeyMaxStorageGB) ?? _defaultMaxStorageGB;
  }
  
  /// Set max storage limit in GB
  Future<void> setMaxStorageGB(double gb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyMaxStorageGB, gb);
  }
  
  /// Get total storage used by all downloads in GB
  Future<double> getTotalStorageUsed() async {
    try {
      double totalSize = 0.0;
      
      // Videos
      final videoDir = Directory('${(await getApplicationDocumentsDirectory()).path}/videos');
      if (await videoDir.exists()) {
        await for (final entity in videoDir.list()) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      // Podcasts
      final podcastDir = Directory('${(await getApplicationDocumentsDirectory()).path}/podcasts');
      if (await podcastDir.exists()) {
        await for (final entity in podcastDir.list()) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      // PDFs
      final pdfDir = Directory('${(await getApplicationDocumentsDirectory()).path}/pdfs');
      if (await pdfDir.exists()) {
        await for (final entity in pdfDir.list()) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      return totalSize / 1024 / 1024 / 1024; // Convert to GB
    } catch (e) {
      print('❌ Error calculating total storage: $e');
      return 0.0;
    }
  }
  
  /// Clean up old files based on last access time
  /// Returns number of files deleted
  Future<int> cleanupOldFiles() async {
    if (!await isAutoCleanupEnabled()) {
      print('⚠️ Auto cleanup is disabled');
      return 0;
    }
    
    final cleanupDays = await getCleanupDays();
    final cutoffDate = DateTime.now().subtract(Duration(days: cleanupDays));
    int deletedCount = 0;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final directory = await getApplicationDocumentsDirectory();
      
      // Clean up videos
      deletedCount += await _cleanupDirectory(
        Directory('${directory.path}/videos'),
        cutoffDate,
        prefs,
      );
      
      // Clean up podcasts
      deletedCount += await _cleanupDirectory(
        Directory('${directory.path}/podcasts'),
        cutoffDate,
        prefs,
      );
      
      // Clean up PDFs
      deletedCount += await _cleanupDirectory(
        Directory('${directory.path}/pdfs'),
        cutoffDate,
        prefs,
      );
      
      print('✅ Cleanup completed: $deletedCount files deleted');
      return deletedCount;
    } catch (e) {
      print('❌ Error during cleanup: $e');
      return deletedCount;
    }
  }
  
  /// Clean up files in a directory based on last access time
  Future<int> _cleanupDirectory(
    Directory dir,
    DateTime cutoffDate,
    SharedPreferences prefs,
  ) async {
    if (!await dir.exists()) {
      return 0;
    }
    
    int deletedCount = 0;
    final keys = prefs.getKeys();
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          // Find last access time for this file
          DateTime? lastAccess;
          for (final key in keys) {
            if (key.startsWith(_prefsKeyLastAccess) && 
                key.endsWith(entity.path.split('/').last)) {
              final timestamp = prefs.getInt(key);
              if (timestamp != null) {
                lastAccess = DateTime.fromMillisecondsSinceEpoch(timestamp);
                break;
              }
            }
          }
          
          // If no access time found, use file modification time
          if (lastAccess == null) {
            final stat = await entity.stat();
            lastAccess = stat.modified;
          }
          
          // Delete if older than cutoff date
          if (lastAccess.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
            print('🗑️ Deleted old file: ${entity.path} (last accessed: $lastAccess)');
            
            // Remove from preferences
            for (final key in keys) {
              if (key.startsWith(_prefsKeyLastAccess) && 
                  key.endsWith(entity.path.split('/').last)) {
                await prefs.remove(key);
              }
            }
          }
        } catch (e) {
          print('⚠️ Error deleting file ${entity.path}: $e');
        }
      }
    }
    
    return deletedCount;
  }
  
  /// Clean up files when storage limit is exceeded (LRU strategy)
  /// Returns number of files deleted
  Future<int> cleanupByStorageLimit() async {
    final maxStorageGB = await getMaxStorageGB();
    final currentStorageGB = await getTotalStorageUsed();
    
    if (currentStorageGB <= maxStorageGB) {
      print('✅ Storage within limit: ${currentStorageGB.toStringAsFixed(2)} GB / $maxStorageGB GB');
      return 0;
    }
    
    print('⚠️ Storage limit exceeded: ${currentStorageGB.toStringAsFixed(2)} GB / $maxStorageGB GB');
    print('🗑️ Starting LRU cleanup...');
    
    // Get all files with their last access times
    final files = <_FileInfo>[];
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Collect all files
      for (final dirPath in [
        '${directory.path}/videos',
        '${directory.path}/podcasts',
        '${directory.path}/pdfs',
      ]) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final entity in dir.list()) {
            if (entity is File) {
              DateTime? lastAccess;
              String? accessKey;
              
              // Find last access time
              for (final key in keys) {
                if (key.startsWith(_prefsKeyLastAccess) && 
                    key.endsWith(entity.path.split('/').last)) {
                  final timestamp = prefs.getInt(key);
                  if (timestamp != null) {
                    lastAccess = DateTime.fromMillisecondsSinceEpoch(timestamp);
                    accessKey = key;
                    break;
                  }
                }
              }
              
              // If no access time, use file modification time
              if (lastAccess == null) {
                final stat = await entity.stat();
                lastAccess = stat.modified;
              }
              
              final size = await entity.length();
              files.add(_FileInfo(
                file: entity,
                lastAccess: lastAccess,
                size: size,
                accessKey: accessKey,
              ));
            }
          }
        }
      }
      
      // Sort by last access time (oldest first - LRU)
      files.sort((a, b) => a.lastAccess.compareTo(b.lastAccess));
      
      // Delete oldest files until under limit
      int deletedCount = 0;
      double currentSize = currentStorageGB;
      
      for (final fileInfo in files) {
        if (currentSize <= maxStorageGB) {
          break;
        }
        
        try {
          await fileInfo.file.delete();
          currentSize -= fileInfo.size / 1024 / 1024 / 1024;
          deletedCount++;
          
          // Remove from preferences
          if (fileInfo.accessKey != null) {
            await prefs.remove(fileInfo.accessKey!);
          }
          
          print('🗑️ Deleted: ${fileInfo.file.path} (${(fileInfo.size / 1024 / 1024).toStringAsFixed(2)} MB)');
        } catch (e) {
          print('⚠️ Error deleting ${fileInfo.file.path}: $e');
        }
      }
      
      print('✅ LRU cleanup completed: $deletedCount files deleted');
      print('📊 New storage: ${currentSize.toStringAsFixed(2)} GB / $maxStorageGB GB');
      
      return deletedCount;
    } catch (e) {
      print('❌ Error during LRU cleanup: $e');
      return 0;
    }
  }
  
  /// Run cleanup (both time-based and storage limit)
  Future<int> runCleanup() async {
    int totalDeleted = 0;
    
    // First, cleanup by storage limit (LRU)
    totalDeleted += await cleanupByStorageLimit();
    
    // Then, cleanup old files (time-based)
    totalDeleted += await cleanupOldFiles();
    
    return totalDeleted;
  }
}

/// Helper class for file information
class _FileInfo {
  final File file;
  final DateTime lastAccess;
  final int size;
  final String? accessKey;
  
  _FileInfo({
    required this.file,
    required this.lastAccess,
    required this.size,
    this.accessKey,
  });
}

