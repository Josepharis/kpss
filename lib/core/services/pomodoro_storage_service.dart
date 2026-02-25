import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pomodoro_session.dart';
import 'progress_service.dart';

class PomodoroStorageService {
  static const String _sessionsKey = 'pomodoro_sessions';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;
  DocumentReference get _userDoc =>
      _firestore.collection('userProgress').doc(_userId ?? 'anonymous');

  Future<List<PomodoroSession>> getAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Önce yerel cache'den bak
      final sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
      if (sessionsJson.isNotEmpty) {
        final sessions =
            sessionsJson
                .map((json) => PomodoroSession.fromJson(jsonDecode(json)))
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));

        // Arka planda Firestore ile senkronize et
        _syncFromFirestore();
        return sessions;
      }

      // 2. Cache'de yoksa Firestore'dan çek
      if (_userId != null) {
        final snapshot = await _userDoc
            .collection('pomodoroSessions')
            .orderBy('date', descending: true)
            .get();
        if (snapshot.docs.isNotEmpty) {
          final sessions = snapshot.docs.map((doc) {
            final data = doc.data();
            return PomodoroSession(
              id: doc.id,
              date: (data['date'] as Timestamp).toDate(),
              sessionCount: data['sessionCount'] as int? ?? 1,
              sessionDuration: data['sessionDuration'] as int? ?? 25,
              totalMinutes: data['totalMinutes'] as int? ?? 25,
              correctAnswers: data['correctAnswers'] as int?,
              wrongAnswers: data['wrongAnswers'] as int?,
              topic: data['topic'] as String?,
              notes: data['notes'] as String?,
            );
          }).toList();

          // Yerel cache'e kaydet
          final encoded = sessions.map((s) => jsonEncode(s.toJson())).toList();
          await prefs.setStringList(_sessionsKey, encoded);
          return sessions;
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error getting pomodoro sessions: $e');
      return [];
    }
  }

  Future<void> saveSession(PomodoroSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = await getAllSessions();
      sessions.add(session);

      // 1. Yerel olarak kaydet
      final sessionsJson = sessions.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_sessionsKey, sessionsJson);

      // 2. Firestore'a kaydet
      if (_userId != null) {
        await _userDoc.collection('pomodoroSessions').doc(session.id).set({
          'date': Timestamp.fromDate(session.date),
          'sessionCount': session.sessionCount,
          'sessionDuration': session.sessionDuration,
          'totalMinutes': session.totalMinutes,
          'correctAnswers': session.correctAnswers,
          'wrongAnswers': session.wrongAnswers,
          'topic': session.topic,
          'notes': session.notes,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      ProgressService.markStatsDirty();
    } catch (e) {
      debugPrint('Error saving pomodoro session: $e');
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = await getAllSessions();
      sessions.removeWhere((s) => s.id == id);

      // 1. Yerel olarak sil
      final sessionsJson = sessions.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_sessionsKey, sessionsJson);

      // 2. Firestore'dan sil
      if (_userId != null) {
        await _userDoc.collection('pomodoroSessions').doc(id).delete();
      }

      ProgressService.markStatsDirty();
    } catch (e) {
      debugPrint('Error deleting pomodoro session: $e');
    }
  }

  Future<void> _syncFromFirestore() async {
    if (_userId == null) return;
    try {
      final snapshot = await _userDoc.collection('pomodoroSessions').get();
      if (snapshot.docs.isNotEmpty) {
        final sessions = snapshot.docs.map((doc) {
          final data = doc.data();
          return PomodoroSession(
            id: doc.id,
            date: (data['date'] as Timestamp).toDate(),
            sessionCount: data['sessionCount'] as int? ?? 1,
            sessionDuration: data['sessionDuration'] as int? ?? 25,
            totalMinutes: data['totalMinutes'] as int? ?? 25,
            correctAnswers: data['correctAnswers'] as int?,
            wrongAnswers: data['wrongAnswers'] as int?,
            topic: data['topic'] as String?,
            notes: data['notes'] as String?,
          );
        }).toList();

        final prefs = await SharedPreferences.getInstance();
        final encoded = sessions.map((s) => jsonEncode(s.toJson())).toList();
        await prefs.setStringList(_sessionsKey, encoded);
      }
    } catch (e) {
      debugPrint('Error syncing pomodoro sessions: $e');
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
      final sessionDate = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );
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
