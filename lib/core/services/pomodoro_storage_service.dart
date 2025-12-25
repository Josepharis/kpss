import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pomodoro_session.dart';

class PomodoroStorageService {
  static const String _sessionsKey = 'pomodoro_sessions';

  Future<List<PomodoroSession>> getAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
      
      return sessionsJson
          .map((json) => PomodoroSession.fromJson(jsonDecode(json)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSession(PomodoroSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = await getAllSessions();
      sessions.add(session);
      
      final sessionsJson = sessions
          .map((s) => jsonEncode(s.toJson()))
          .toList();
      
      await prefs.setStringList(_sessionsKey, sessionsJson);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = await getAllSessions();
      sessions.removeWhere((s) => s.id == id);
      
      final sessionsJson = sessions
          .map((s) => jsonEncode(s.toJson()))
          .toList();
      
      await prefs.setStringList(_sessionsKey, sessionsJson);
    } catch (e) {
      // Handle error
    }
  }

  Future<Map<DateTime, List<PomodoroSession>>> getSessionsByDate() async {
    final sessions = await getAllSessions();
    final Map<DateTime, List<PomodoroSession>> grouped = {};
    
    for (final session in sessions) {
      final date = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
      
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(session);
    }
    
    return grouped;
  }

  Future<int> getTotalMinutesForDate(DateTime date) async {
    final sessions = await getAllSessions();
    final targetDate = DateTime(date.year, date.month, date.day);
    
    int total = 0;
    for (final session in sessions) {
      final sessionDate = DateTime(session.date.year, session.date.month, session.date.day);
      if (sessionDate.isAtSameMomentAs(targetDate)) {
        total += session.totalMinutes;
      }
    }
    return total;
  }

  Future<int> getTotalSessions() async {
    final sessions = await getAllSessions();
    return sessions.length;
  }

  Future<int> getTotalMinutes() async {
    final sessions = await getAllSessions();
    int total = 0;
    for (final session in sessions) {
      total += session.totalMinutes;
    }
    return total;
  }
}

