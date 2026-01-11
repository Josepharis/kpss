import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for downloading and managing videos locally
class VideoDownloadService {
  static const String _prefsKey = 'downloaded_videos';
  
  /// Get local directory for storing videos
  Future<Directory> _getVideoDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${directory.path}/videos');
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir;
  }
  
  /// Generate a unique file name from video URL
  String _getFileNameFromUrl(String videoUrl) {
    final bytes = utf8.encode(videoUrl);
    final hash = sha256.convert(bytes);
    // Get file extension from URL
    final uri = Uri.parse(videoUrl);
    final pathSegments = uri.pathSegments;
    String extension = '.mp4'; // default
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last;
      if (lastSegment.contains('.')) {
        extension = '.${lastSegment.split('.').last}';
      }
    }
    return '${hash.toString()}$extension';
  }
  
  /// Get local file path for a video URL
  Future<String?> getLocalFilePath(String videoUrl) async {
    final videoDir = await _getVideoDirectory();
    final fileName = _getFileNameFromUrl(videoUrl);
    final filePath = '${videoDir.path}/$fileName';
    final file = File(filePath);
    
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }
  
  /// Check if video is downloaded
  Future<bool> isVideoDownloaded(String videoUrl) async {
    final localPath = await getLocalFilePath(videoUrl);
    return localPath != null;
  }
  
  /// Get download progress (0.0 to 1.0)
  Future<double> getDownloadProgress(String videoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedVideos = prefs.getStringList(_prefsKey) ?? [];
    final fileName = _getFileNameFromUrl(videoUrl);
    
    // Check if download is in progress
    final progressKey = 'download_progress_$fileName';
    final progress = prefs.getDouble(progressKey);
    
    if (progress != null) {
      return progress;
    }
    
    // If downloaded, return 1.0
    if (downloadedVideos.contains(fileName)) {
      return 1.0;
    }
    
    return 0.0;
  }
  
  /// Download video from URL
  /// Returns local file path on success, null on failure
  Future<String?> downloadVideo({
    required String videoUrl,
    required String videoId,
    Function(double progress)? onProgress,
  }) async {
    try {
      print('📥 Starting video download: $videoId');
      
      final videoDir = await _getVideoDirectory();
      final fileName = _getFileNameFromUrl(videoUrl);
      final filePath = '${videoDir.path}/$fileName';
      final file = File(filePath);
      
      // Check if already downloaded
      if (await file.exists()) {
        print('✅ Video already downloaded: $filePath');
        await _markAsDownloaded(fileName);
        return filePath;
      }
      
      // Start download
      final request = http.Request('GET', Uri.parse(videoUrl));
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
      
      print('✅ Video downloaded successfully: $filePath');
      print('📊 File size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      
      return filePath;
    } catch (e) {
      print('❌ Error downloading video: $e');
      return null;
    }
  }
  
  /// Mark video as downloaded
  Future<void> _markAsDownloaded(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedVideos = prefs.getStringList(_prefsKey) ?? [];
    if (!downloadedVideos.contains(fileName)) {
      downloadedVideos.add(fileName);
      await prefs.setStringList(_prefsKey, downloadedVideos);
    }
  }
  
  /// Delete downloaded video
  Future<bool> deleteVideo(String videoUrl) async {
    try {
      final localPath = await getLocalFilePath(videoUrl);
      if (localPath == null) {
        return false;
      }
      
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from downloaded list
      final prefs = await SharedPreferences.getInstance();
      final downloadedVideos = prefs.getStringList(_prefsKey) ?? [];
      final fileName = _getFileNameFromUrl(videoUrl);
      downloadedVideos.remove(fileName);
      await prefs.setStringList(_prefsKey, downloadedVideos);
      
      // Remove progress key if exists
      final progressKey = 'download_progress_$fileName';
      await prefs.remove(progressKey);
      
      print('✅ Video deleted: $localPath');
      return true;
    } catch (e) {
      print('❌ Error deleting video: $e');
      return false;
    }
  }
  
  /// Get all downloaded videos
  Future<List<String>> getDownloadedVideos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }
  
  /// Get total size of downloaded videos in MB
  Future<double> getTotalDownloadSize() async {
    try {
      final videoDir = await _getVideoDirectory();
      if (!await videoDir.exists()) {
        return 0.0;
      }
      
      double totalSize = 0.0;
      await for (final entity in videoDir.list()) {
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
  
  /// Clear all downloaded videos
  Future<bool> clearAllDownloads() async {
    try {
      final videoDir = await _getVideoDirectory();
      if (await videoDir.exists()) {
        await for (final entity in videoDir.list()) {
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
      
      print('✅ All downloaded videos cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing downloads: $e');
      return false;
    }
  }
}

