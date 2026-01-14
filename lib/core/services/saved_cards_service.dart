import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_card.dart';

class SavedCard {
  final String id;
  final String frontText;
  final String backText;
  final String topicId;
  final String topicName;
  final String lessonId;
  final DateTime savedAt;

  SavedCard({
    required this.id,
    required this.frontText,
    required this.backText,
    required this.topicId,
    required this.topicName,
    required this.lessonId,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'frontText': frontText,
      'backText': backText,
      'topicId': topicId,
      'topicName': topicName,
      'lessonId': lessonId,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedCard.fromJson(Map<String, dynamic> json) {
    return SavedCard(
      id: json['id'] ?? '',
      frontText: json['frontText'] ?? '',
      backText: json['backText'] ?? '',
      topicId: json['topicId'] ?? '',
      topicName: json['topicName'] ?? '',
      lessonId: json['lessonId'] ?? '',
      savedAt: json['savedAt'] != null
          ? DateTime.parse(json['savedAt'])
          : DateTime.now(),
    );
  }

  factory SavedCard.fromFlashCard(
    FlashCard card,
    String topicId,
    String topicName,
    String lessonId,
  ) {
    return SavedCard(
      id: card.id,
      frontText: card.frontText,
      backText: card.backText,
      topicId: topicId,
      topicName: topicName,
      lessonId: lessonId,
      savedAt: DateTime.now(),
    );
  }
}

class SavedCardsService {
  static const String _key = 'saved_cards';

  // Tüm kaydedilmiş kartları getir
  static Future<List<SavedCard>> getAllSavedCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_key);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => SavedCard.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Konu başlığına göre kaydedilmiş kartları getir
  static Future<List<SavedCard>> getSavedCardsByTopic(String topicName) async {
    final allCards = await getAllSavedCards();
    return allCards.where((c) => c.topicName == topicName).toList();
  }

  // Konu başlıklarına göre gruplanmış kaydedilmiş kartları getir
  static Future<Map<String, List<SavedCard>>> getSavedCardsGroupedByTopic() async {
    final allCards = await getAllSavedCards();
    final Map<String, List<SavedCard>> grouped = {};

    for (var card in allCards) {
      if (!grouped.containsKey(card.topicName)) {
        grouped[card.topicName] = [];
      }
      grouped[card.topicName]!.add(card);
    }

    return grouped;
  }

  // Ders ID'sine göre kaydedilmiş kartları getir
  static Future<List<SavedCard>> getSavedCardsByLesson(String lessonId) async {
    final allCards = await getAllSavedCards();
    return allCards.where((c) => c.lessonId == lessonId).toList();
  }

  // Ders bazında gruplanmış kaydedilmiş kartları getir
  static Future<Map<String, List<SavedCard>>> getSavedCardsGroupedByLesson() async {
    final allCards = await getAllSavedCards();
    final Map<String, List<SavedCard>> grouped = {};

    for (var card in allCards) {
      if (!grouped.containsKey(card.lessonId)) {
        grouped[card.lessonId] = [];
      }
      grouped[card.lessonId]!.add(card);
    }

    return grouped;
  }

  // Kaydedilmiş kart ekle
  static Future<bool> addSavedCard(SavedCard card) async {
    try {
      final allCards = await getAllSavedCards();
      
      // Aynı ID'ye sahip kart zaten varsa ekleme
      if (allCards.any((c) => c.id == card.id && c.topicId == card.topicId)) {
        return false;
      }

      allCards.add(card);
      return await _saveSavedCards(allCards);
    } catch (e) {
      return false;
    }
  }

  // Kaydedilmiş kartı kaldır
  static Future<bool> removeSavedCard(String cardId, String topicId) async {
    try {
      final allCards = await getAllSavedCards();
      allCards.removeWhere(
        (c) => c.id == cardId && c.topicId == topicId,
      );
      return await _saveSavedCards(allCards);
    } catch (e) {
      return false;
    }
  }

  // Tüm kaydedilmiş kartları temizle
  static Future<bool> clearAllSavedCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_key);
    } catch (e) {
      return false;
    }
  }

  // Belirli bir konudaki tüm kaydedilmiş kartları temizle
  static Future<bool> clearSavedCardsByTopic(String topicName, {String? lessonId}) async {
    try {
      final allCards = await getAllSavedCards();
      if (lessonId != null) {
        allCards.removeWhere((c) => c.topicName == topicName && c.lessonId == lessonId);
      } else {
        allCards.removeWhere((c) => c.topicName == topicName);
      }
      return await _saveSavedCards(allCards);
    } catch (e) {
      return false;
    }
  }

  // Belirli bir dersteki tüm kaydedilmiş kartları temizle
  static Future<bool> clearSavedCardsByLesson(String lessonId) async {
    try {
      final allCards = await getAllSavedCards();
      allCards.removeWhere((c) => c.lessonId == lessonId);
      return await _saveSavedCards(allCards);
    } catch (e) {
      return false;
    }
  }

  // Kaydedilmiş kartları kaydet
  static Future<bool> _saveSavedCards(List<SavedCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          cards.map((c) => c.toJson()).toList();
      final String jsonString = json.encode(jsonList);
      return await prefs.setString(_key, jsonString);
    } catch (e) {
      return false;
    }
  }

  // Kart zaten kaydedilmiş mi kontrol et
  static Future<bool> isCardSaved(String cardId, String topicId) async {
    final allCards = await getAllSavedCards();
    return allCards.any(
      (c) => c.id == cardId && c.topicId == topicId,
    );
  }
}
