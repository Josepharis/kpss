import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_program.dart';

class StudyProgramService {
  static StudyProgramService? _instance;
  static StudyProgramService get instance {
    _instance ??= StudyProgramService._();
    return _instance!;
  }

  StudyProgramService._();

  static const _key = 'study_program_v1';

  Future<StudyProgram?> getProgram() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return StudyProgram.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgram(StudyProgram program) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(program.toMap()));
  }

  Future<void> clearProgram() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

