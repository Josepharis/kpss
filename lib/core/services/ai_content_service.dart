import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_material.dart';
import '../models/ai_question.dart';

class AiContentService {
  static AiContentService? _instance;
  static AiContentService get instance {
    _instance ??= AiContentService._();
    return _instance!;
  }

  AiContentService._();

  String _questionsKey(String topicId) => 'ai_questions_$topicId';
  String _materialKey(String topicId) => 'ai_material_$topicId';

  Future<List<AiQuestion>> getQuestions(String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_questionsKey(topicId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => AiQuestion.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveQuestions(String topicId, List<AiQuestion> questions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(questions.map((q) => q.toMap()).toList());
    await prefs.setString(_questionsKey(topicId), jsonString);
  }

  Future<void> clearQuestions(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_questionsKey(topicId));
  }

  Future<AiMaterial?> getMaterial(String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_materialKey(topicId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AiMaterial.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMaterial(String topicId, AiMaterial material) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_materialKey(topicId), jsonEncode(material.toMap()));
  }

  Future<void> clearMaterial(String topicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_materialKey(topicId));
  }
}

