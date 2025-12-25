import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service to cache podcast durations locally
class PodcastCacheService {
  static const String _cacheKey = 'podcast_durations';
  static Map<String, int>? _cache;

  /// Get cached duration for a podcast URL
  static Future<int?> getDuration(String audioUrl) async {
    if (_cache == null) {
      await _loadCache();
    }
    return _cache?[audioUrl];
  }

  /// Save duration for a podcast URL
  static Future<void> saveDuration(String audioUrl, int durationMinutes) async {
    if (_cache == null) {
      await _loadCache();
    }
    _cache ??= {};
    _cache![audioUrl] = durationMinutes;
    await _saveCache();
  }

  /// Load cache from SharedPreferences
  static Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson != null) {
        _cache = Map<String, int>.from(json.decode(cacheJson));
      } else {
        _cache = {};
      }
    } catch (e) {
      print('Error loading podcast cache: $e');
      _cache = {};
    }
  }

  /// Save cache to SharedPreferences
  static Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(_cache));
    } catch (e) {
      print('Error saving podcast cache: $e');
    }
  }

  /// Clear all cached durations
  static Future<void> clearCache() async {
    _cache = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}

