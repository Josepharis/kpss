import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/quick_access_item.dart';

/// Service to manage quick access items (recently viewed topics)
class QuickAccessService {
  static const String _cacheKey = 'quick_access_items';
  static const int _maxItems = 6; // Maximum number of quick access items

  static Future<Map<String, int>> _loadCachedContentCounts(String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contentCountsJson = prefs.getString('content_counts_$topicId');
      if (contentCountsJson == null || contentCountsJson.isEmpty) return {};

      final Map<String, dynamic> decoded = jsonDecode(contentCountsJson) as Map<String, dynamic>;
      int readInt(String key) => (decoded[key] as int?) ?? 0;

      return {
        'videoCount': readInt('videoCount'),
        'podcastCount': readInt('podcastCount'),
        'flashCardCount': readInt('flashCardCount'),
        'pdfCount': readInt('pdfCount'),
      };
    } catch (_) {
      return {};
    }
  }

  /// Add a topic to quick access (manual favorite)
  static Future<void> addQuickAccessItem({
    required String topicId,
    required String lessonId,
    required String topicName,
    required String lessonName,
    int podcastCount = 0,
    int videoCount = 0,
    int flashCardCount = 0,
    int pdfCount = 0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getQuickAccessItems();
      
      // Check if already exists
      if (items.any((item) => item.topicId == topicId)) {
        return; // Already exists
      }
      
      // Add new item
      final newItem = QuickAccessItem(
        topicId: topicId,
        lessonId: lessonId,
        topicName: topicName,
        lessonName: lessonName,
        lastAccessedTimestamp: DateTime.now().millisecondsSinceEpoch,
        podcastCount: podcastCount,
        videoCount: videoCount,
        flashCardCount: flashCardCount,
        pdfCount: pdfCount,
      );
      
      items.add(newItem);
      
      // Keep only the most recent items
      if (items.length > _maxItems) {
        items.sort((a, b) => b.lastAccessedTimestamp.compareTo(a.lastAccessedTimestamp));
        items.removeRange(_maxItems, items.length);
      }
      
      // Save to cache
      final itemsJson = jsonEncode(items.map((item) => item.toMap()).toList());
      await prefs.setString(_cacheKey, itemsJson);
    } catch (e) {
      // Silent error handling
    }
  }

  /// Check if a topic is in quick access
  static Future<bool> isInQuickAccess(String topicId) async {
    try {
      final items = await getQuickAccessItems();
      return items.any((item) => item.topicId == topicId);
    } catch (e) {
      return false;
    }
  }

  /// Get all quick access items (sorted by last accessed, most recent first)
  static Future<List<QuickAccessItem>> getQuickAccessItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final itemsJson = prefs.getString(_cacheKey);
      
      if (itemsJson == null || itemsJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> itemsList = jsonDecode(itemsJson);
      final items = itemsList
          .map((json) => QuickAccessItem.fromMap(json as Map<String, dynamic>))
          .toList();
      
      // Sort by last accessed timestamp (most recent first)
      items.sort((a, b) => b.lastAccessedTimestamp.compareTo(a.lastAccessedTimestamp));
      
      return items;
    } catch (e) {
      return [];
    }
  }

  /// Update content counts for a topic
  static Future<void> updateContentCounts({
    required String topicId,
    int? podcastCount,
    int? videoCount,
    int? flashCardCount,
    int? pdfCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getQuickAccessItems();
      
      final index = items.indexWhere((item) => item.topicId == topicId);
      if (index != -1) {
        final item = items[index];
        items[index] = item.copyWith(
          podcastCount: podcastCount ?? item.podcastCount,
          videoCount: videoCount ?? item.videoCount,
          flashCardCount: flashCardCount ?? item.flashCardCount,
          pdfCount: pdfCount ?? item.pdfCount,
        );
        
        // Save updated items
        final itemsJson = jsonEncode(items.map((item) => item.toMap()).toList());
        await prefs.setString(_cacheKey, itemsJson);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Remove a quick access item (unfavorite)
  static Future<void> removeQuickAccessItem(String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getQuickAccessItems();
      
      items.removeWhere((item) => item.topicId == topicId);
      
      // Save updated items
      final itemsJson = jsonEncode(items.map((item) => item.toMap()).toList());
      await prefs.setString(_cacheKey, itemsJson);
    } catch (e) {
      // Silent error handling
    }
  }

  /// Toggle quick access item (add if not exists, remove if exists)
  static Future<bool> toggleQuickAccessItem({
    required String topicId,
    required String lessonId,
    required String topicName,
    required String lessonName,
    int podcastCount = 0,
    int videoCount = 0,
    int flashCardCount = 0,
    int pdfCount = 0,
  }) async {
    try {
      final isInQuickAccess = await QuickAccessService.isInQuickAccess(topicId);
      if (isInQuickAccess) {
        await removeQuickAccessItem(topicId);
        return false;
      } else {
        // Favoriye eklerken içerik sayıları bazen 0 geliyor (özellikle konu listesinde).
        // Varsa local cache'den (content_counts_<topicId>) sayıları çekip kartı boş bırakmayalım.
        final cached = await _loadCachedContentCounts(topicId);
        final resolvedPodcastCount = podcastCount > 0 ? podcastCount : (cached['podcastCount'] ?? 0);
        final resolvedVideoCount = videoCount > 0 ? videoCount : (cached['videoCount'] ?? 0);
        final resolvedFlashCardCount = flashCardCount > 0 ? flashCardCount : (cached['flashCardCount'] ?? 0);
        final resolvedPdfCount = pdfCount > 0 ? pdfCount : (cached['pdfCount'] ?? 0);

        await addQuickAccessItem(
          topicId: topicId,
          lessonId: lessonId,
          topicName: topicName,
          lessonName: lessonName,
          podcastCount: resolvedPodcastCount,
          videoCount: resolvedVideoCount,
          flashCardCount: resolvedFlashCardCount,
          pdfCount: resolvedPdfCount,
        );
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  /// Clear all quick access items
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      // Silent error handling
    }
  }
}
