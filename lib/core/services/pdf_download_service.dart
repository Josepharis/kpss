import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for downloading and managing PDFs locally
class PdfDownloadService {
  static const String _prefsKey = 'downloaded_pdfs';
  
  /// Get local directory for storing PDFs
  Future<Directory> _getPdfDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${directory.path}/pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }
  
  /// Generate a unique file name from PDF URL
  String _getFileNameFromUrl(String pdfUrl) {
    final bytes = utf8.encode(pdfUrl);
    final hash = sha256.convert(bytes);
    return '${hash.toString()}.pdf';
  }
  
  /// Get local file path for a PDF URL
  Future<String?> getLocalFilePath(String pdfUrl) async {
    final pdfDir = await _getPdfDirectory();
    final fileName = _getFileNameFromUrl(pdfUrl);
    final filePath = '${pdfDir.path}/$fileName';
    final file = File(filePath);
    
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }
  
  /// Check if PDF is downloaded
  Future<bool> isPdfDownloaded(String pdfUrl) async {
    final localPath = await getLocalFilePath(pdfUrl);
    return localPath != null;
  }
  
  /// Get download progress (0.0 to 1.0)
  Future<double> getDownloadProgress(String pdfUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedPdfs = prefs.getStringList(_prefsKey) ?? [];
    final fileName = _getFileNameFromUrl(pdfUrl);
    
    // Check if download is in progress
    final progressKey = 'download_progress_$fileName';
    final progress = prefs.getDouble(progressKey);
    
    if (progress != null) {
      return progress;
    }
    
    // If downloaded, return 1.0
    if (downloadedPdfs.contains(fileName)) {
      return 1.0;
    }
    
    return 0.0;
  }
  
  /// Download PDF from URL
  /// Returns local file path on success, null on failure
  Future<String?> downloadPdf({
    required String pdfUrl,
    required String pdfId,
    Function(double progress)? onProgress,
  }) async {
    try {
      print('📥 Starting PDF download: $pdfId');
      
      final pdfDir = await _getPdfDirectory();
      final fileName = _getFileNameFromUrl(pdfUrl);
      final filePath = '${pdfDir.path}/$fileName';
      final file = File(filePath);
      
      // Check if already downloaded
      if (await file.exists()) {
        print('✅ PDF already downloaded: $filePath');
        await _markAsDownloaded(fileName);
        return filePath;
      }
      
      // Start download
      final request = http.Request('GET', Uri.parse(pdfUrl));
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
      
      print('✅ PDF downloaded successfully: $filePath');
      print('📊 File size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      
      return filePath;
    } catch (e) {
      print('❌ Error downloading PDF: $e');
      return null;
    }
  }
  
  /// Mark PDF as downloaded
  Future<void> _markAsDownloaded(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedPdfs = prefs.getStringList(_prefsKey) ?? [];
    if (!downloadedPdfs.contains(fileName)) {
      downloadedPdfs.add(fileName);
      await prefs.setStringList(_prefsKey, downloadedPdfs);
    }
  }
  
  /// Delete downloaded PDF
  Future<bool> deletePdf(String pdfUrl) async {
    try {
      final localPath = await getLocalFilePath(pdfUrl);
      if (localPath == null) {
        return false;
      }
      
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Remove from downloaded list
      final prefs = await SharedPreferences.getInstance();
      final downloadedPdfs = prefs.getStringList(_prefsKey) ?? [];
      final fileName = _getFileNameFromUrl(pdfUrl);
      downloadedPdfs.remove(fileName);
      await prefs.setStringList(_prefsKey, downloadedPdfs);
      
      // Remove progress key if exists
      final progressKey = 'download_progress_$fileName';
      await prefs.remove(progressKey);
      
      print('✅ PDF deleted: $localPath');
      return true;
    } catch (e) {
      print('❌ Error deleting PDF: $e');
      return false;
    }
  }
  
  /// Get all downloaded PDFs
  Future<List<String>> getDownloadedPdfs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }
  
  /// Get total size of downloaded PDFs in MB
  Future<double> getTotalDownloadSize() async {
    try {
      final pdfDir = await _getPdfDirectory();
      if (!await pdfDir.exists()) {
        return 0.0;
      }
      
      double totalSize = 0.0;
      await for (final entity in pdfDir.list()) {
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
  
  /// Clear all downloaded PDFs
  Future<bool> clearAllDownloads() async {
    try {
      final pdfDir = await _getPdfDirectory();
      if (await pdfDir.exists()) {
        await for (final entity in pdfDir.list()) {
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
      
      print('✅ All downloaded PDFs cleared');
      return true;
    } catch (e) {
      print('❌ Error clearing downloads: $e');
      return false;
    }
  }
}

