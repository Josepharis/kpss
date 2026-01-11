import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for downloading and managing podcasts locally
class PodcastDownloadService {
  static const String _prefsKey = 'downloaded_podcasts';
  
  /// Get local directory for storing podcasts
  Future<Directory> _getPodcastDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final podcastDir = Directory('${directory.path}/podcasts');
    if (!await podcastDir.exists()) {
      await podcastDir.create(recursive: true);
    }
    return podcastDir;
  }
  
  /// Get local directory for storing podcasts (public)
  Future<Directory> getPodcastDirectory() async {
    return _getPodcastDirectory();
  }
  
  /// Generate a unique file name from podcast URL
  String _getFileNameFromUrl(String audioUrl) {
    final bytes = utf8.encode(audioUrl);
    final hash = sha256.convert(bytes);
    // Get file extension from URL
    final uri = Uri.parse(audioUrl);
    final pathSegments = uri.pathSegments;
    String extension = '.mp3'; // default
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        extension = '.${lastSegment.split('.').last}';
      }
    }
    return '${hash.toString()}$extension';
  }
  
  /// Get local file path for a podcast URL
  Future<String?> getLocalFilePath(String audioUrl) async {
    final podcastDir = await _getPodcastDirectory();
    final fileName = _getFileNameFromUrl(audioUrl);
    final filePath = '${podcastDir.path}/$fileName';
    final file = File(filePath);
    
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }
  
  /// Check if podcast is downloaded
  Future<bool> isPodcastDownloaded(String audioUrl) async {
    final localPath = await getLocalFilePath(audioUrl);
    return localPath != null;
  }
  
  /// Get download progress (0.0 to 1.0)
  Future<double> getDownloadProgress(String audioUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedPodcasts = prefs.getStringList(_prefsKey) ?? [];
    final fileName = _getFileNameFromUrl(audioUrl);
    
    // Check if download is in progress
    final progressKey = 'download_progress_$fileName';
    final progress = prefs.getDouble(progressKey);
    
    if (progress != null) {
      return progress;
    }
    
    // If downloaded, return 1.0
    if (downloadedPodcasts.contains(fileName)) {
      return 1.0;
    }
    
    return 0.0;
  }
  
  /// Download podcast from URL
  /// Returns local file path on success, null on failure
  Future<String?> downloadPodcast({
    required String audioUrl,
    required String podcastId,
    Function(double progress)? onProgress,
  }) async {
    try {
      print('📥 Starting podcast download: $podcastId');
      
      final podcastDir = await _getPodcastDirectory();
      final fileName = _getFileNameFromUrl(audioUrl);
      final filePath = '${podcastDir.path}/$fileName';
      final file = File(filePath);
      
      // Check if already downloaded
      if (await file.exists()) {
        print('✅ Podcast already downloaded: $filePath');
        await _markAsDownloaded(fileName);
        return filePath;
      }
      
      // Start download
      final request = http.Request('GET', Uri.parse(audioUrl));
      final response = await http.Client().send(request);
      
      if (response.statusCode != 200) {
        print('❌ Download failed: ${response.statusCode}');
        return null;
      }
      
      final contentLength = response.contentLength ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final progressKey = 'download_progress_$fileName';
      
      // Save file
      final bytes = <int>[];
      int downloadedBytes = 0;
      
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        
        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          await prefs.setDouble(progressKey, progress);
          
          if (onProgress != null) {
            onProgress(progress);
          }
        }
      }
      
      // Write file
      await file.writeAsBytes(bytes);
      
      // Mark as downloaded
      await _markAsDownloaded(fileName);
      
      // Remove progress key
      await prefs.remove(progressKey);
      
      print('✅ Podcast downloaded successfully: $filePath');
      print('📊 File size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      
      return filePath;
    } catch (e) {
      print('❌ Error downloading podcast: $e');
      return null;
    }
  }
  
  /// Mark podcast as downloaded
  Future<void> _markAsDownloaded(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedPodcasts = prefs.getStringList(_prefsKey) ?? [];
    if (!downloadedPodcasts.contains(fileName)) {
      downloadedPodcasts.add(fileName);
      await prefs.setStringList(_prefsKey, downloadedPodcasts);
    }
  }
  
  /// Delete downloaded podcast
  Future<bool> deletePodcast(String audioUrl) async {
    try {
      final localPath = await getLocalFilePath(audioUrl);
      if (localPath == null) {
        return false;
      }
      
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from downloaded list
      final prefs = await SharedPreferences.getInstance();
      final downloadedPodcasts = prefs.getStringList(_prefsKey) ?? [];
      final fileName = _getFileNameFromUrl(audioUrl);
      downloadedPodcasts.remove(fileName);
      await prefs.setStringList(_prefsKey, downloadedPodcasts);
      
      // Remove progress key if exists
      final progressKey = 'download_progress_$fileName';
      await prefs.remove(progressKey);
      
      print('✅ Podcast deleted: $localPath');
      return true;
    } catch (e) {
      print('❌ Error deleting podcast: $e');
      return false;
    }
  }
  
  /// Get all downloaded podcasts
  Future<List<String>> getDownloadedPodcasts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }
  
  /// Get total size of downloaded podcasts in MB
  Future<double> getTotalDownloadSize() async {
    try {
      final podcastDir = await _getPodcastDirectory();
      if (!await podcastDir.exists()) {
        return 0.0;
      }
      
      double totalSize = 0.0;
      await for (final entity in podcastDir.list()) {
        if (entity is File) {
          final size = await entity.length();
          totalSize += size;
        }
      }
      
      return totalSize / 1024 / 1024; // Convert to MB
    } catch (e) {
      print('❌ Error calculating total size: $e');
      return 0.0;
    }
  }
  
  /// Clear all downloaded podcasts
  Future<bool> clearAllDownloads() async {
    try {
      final podcastDir = await _getPodcastDirectory();
      if (await podcastDir.exists()) {
        await for (final entity in podcastDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      
      // Clear all progress keys
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('download_progress_')) {
          await prefs.remove(key);
        }
      }
      
      print('✅ All downloaded podcasts cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing downloads: $e');
      return false;
    }
  }
}

