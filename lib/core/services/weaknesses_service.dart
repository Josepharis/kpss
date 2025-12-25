import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weakness_question.dart';

class WeaknessesService {
  static const String _key = 'weakness_questions';

  // Tüm eksik soruları getir
  static Future<List<WeaknessQuestion>> getAllWeaknesses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_key);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => WeaknessQuestion.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Konu başlığına göre eksik soruları getir
  static Future<List<WeaknessQuestion>> getWeaknessesByTopic(String topicName) async {
    final allWeaknesses = await getAllWeaknesses();
    return allWeaknesses.where((w) => w.topicName == topicName).toList();
  }

  // Konu başlıklarına göre gruplanmış eksik soruları getir
  static Future<Map<String, List<WeaknessQuestion>>> getWeaknessesGroupedByTopic() async {
    final allWeaknesses = await getAllWeaknesses();
    final Map<String, List<WeaknessQuestion>> grouped = {};

    for (var weakness in allWeaknesses) {
      if (!grouped.containsKey(weakness.topicName)) {
        grouped[weakness.topicName] = [];
      }
      grouped[weakness.topicName]!.add(weakness);
    }

    return grouped;
  }

  // Ders ID'sine göre eksik soruları getir
  static Future<List<WeaknessQuestion>> getWeaknessesByLesson(String lessonId) async {
    final allWeaknesses = await getAllWeaknesses();
    return allWeaknesses.where((w) => w.lessonId == lessonId).toList();
  }

  // Ders bazında gruplanmış eksik soruları getir
  static Future<Map<String, List<WeaknessQuestion>>> getWeaknessesGroupedByLesson() async {
    final allWeaknesses = await getAllWeaknesses();
    final Map<String, List<WeaknessQuestion>> grouped = {};

    for (var weakness in allWeaknesses) {
      if (weakness.lessonId.isEmpty) continue; // Eski veriler için skip
      if (!grouped.containsKey(weakness.lessonId)) {
        grouped[weakness.lessonId] = [];
      }
      grouped[weakness.lessonId]!.add(weakness);
    }

    return grouped;
  }

  // Ders ve konu bazında gruplanmış eksik soruları getir
  static Future<Map<String, Map<String, List<WeaknessQuestion>>>> getWeaknessesGroupedByLessonAndTopic() async {
    final allWeaknesses = await getAllWeaknesses();
    final Map<String, Map<String, List<WeaknessQuestion>>> grouped = {};

    for (var weakness in allWeaknesses) {
      if (weakness.lessonId.isEmpty) continue; // Eski veriler için skip
      
      if (!grouped.containsKey(weakness.lessonId)) {
        grouped[weakness.lessonId] = {};
      }
      
      if (!grouped[weakness.lessonId]!.containsKey(weakness.topicName)) {
        grouped[weakness.lessonId]![weakness.topicName] = [];
      }
      
      grouped[weakness.lessonId]![weakness.topicName]!.add(weakness);
    }

    return grouped;
  }

  // Belirli bir ders ve konuya ait eksik soruları getir
  static Future<List<WeaknessQuestion>> getWeaknessesByLessonAndTopic(String lessonId, String topicName) async {
    final allWeaknesses = await getAllWeaknesses();
    return allWeaknesses.where(
      (w) => w.lessonId == lessonId && w.topicName == topicName,
    ).toList();
  }

  // Eksik soru ekle
  static Future<bool> addWeakness(WeaknessQuestion weakness) async {
    try {
      final allWeaknesses = await getAllWeaknesses();
      
      // Aynı ID'ye sahip soru zaten varsa ekleme
      if (allWeaknesses.any((w) => w.id == weakness.id && w.topicName == weakness.topicName)) {
        return false;
      }

      allWeaknesses.add(weakness);
      return await _saveWeaknesses(allWeaknesses);
    } catch (e) {
      return false;
    }
  }

  // Eksik soruyu kaldır
  static Future<bool> removeWeakness(String questionId, String topicName, {String? lessonId}) async {
    try {
      final allWeaknesses = await getAllWeaknesses();
      if (lessonId != null) {
        allWeaknesses.removeWhere(
          (w) => w.id == questionId && w.topicName == topicName && w.lessonId == lessonId,
        );
      } else {
        allWeaknesses.removeWhere(
          (w) => w.id == questionId && w.topicName == topicName,
        );
      }
      return await _saveWeaknesses(allWeaknesses);
    } catch (e) {
      return false;
    }
  }

  // Tüm eksik soruları temizle
  static Future<bool> clearAllWeaknesses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_key);
    } catch (e) {
      return false;
    }
  }

  // Belirli bir konudaki tüm eksik soruları temizle
  static Future<bool> clearWeaknessesByTopic(String topicName, {String? lessonId}) async {
    try {
      final allWeaknesses = await getAllWeaknesses();
      if (lessonId != null) {
        allWeaknesses.removeWhere((w) => w.topicName == topicName && w.lessonId == lessonId);
      } else {
        allWeaknesses.removeWhere((w) => w.topicName == topicName);
      }
      return await _saveWeaknesses(allWeaknesses);
    } catch (e) {
      return false;
    }
  }

  // Belirli bir dersteki tüm eksik soruları temizle
  static Future<bool> clearWeaknessesByLesson(String lessonId) async {
    try {
      final allWeaknesses = await getAllWeaknesses();
      allWeaknesses.removeWhere((w) => w.lessonId == lessonId);
      return await _saveWeaknesses(allWeaknesses);
    } catch (e) {
      return false;
    }
  }

  // Eksik soruları kaydet
  static Future<bool> _saveWeaknesses(List<WeaknessQuestion> weaknesses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList =
          weaknesses.map((w) => w.toJson()).toList();
      final String jsonString = json.encode(jsonList);
      return await prefs.setString(_key, jsonString);
    } catch (e) {
      return false;
    }
  }

  // Soru zaten eksiklerde mi kontrol et
  static Future<bool> isQuestionInWeaknesses(String questionId, String topicName, {String? lessonId}) async {
    final allWeaknesses = await getAllWeaknesses();
    if (lessonId != null) {
      return allWeaknesses.any(
        (w) => w.id == questionId && w.topicName == topicName && w.lessonId == lessonId,
      );
    }
    return allWeaknesses.any(
      (w) => w.id == questionId && w.topicName == topicName,
    );
  }
}

