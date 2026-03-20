import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;
  DocumentReference get _userDoc =>
      _firestore.collection('userProgress').doc(_userId ?? 'anonymous');

  // --- Throttle: arka plan sync en az 60 saniyede bir çalışır ---
  DateTime? _lastSyncTime;
  static const _syncCooldown = Duration(seconds: 60);

  // --- Self-save bayrağı: kendi kaydettiğimiz güncellemeyi ignore ederiz ---
  bool _isSelfSaving = false;

  Future<StudyProgram?> getProgram() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Önce yerel cache'den bak
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final program = StudyProgram.fromMap(
            Map<String, dynamic>.from(decoded),
          );
          // Arka planda Firestore ile senkronize et ANCAK throttle uygula
          _scheduleBackgroundSync();
          return program;
        }
      }

      // 2. Cache'de yoksa Firestore'dan çek
      if (_userId != null) {
        final doc = await _userDoc
            .collection('metadata')
            .doc('studyProgram')
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final program = StudyProgram.fromMap(data);
            // Yerel cache'i güncelle
            await prefs.setString(_key, jsonEncode(program.toMap()));
            return program;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting study program: $e');
      return null;
    }
  }

  /// Cooldown süresi geçmişse arka planda sync başlatır.
  void _scheduleBackgroundSync() {
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        now.difference(_lastSyncTime!) < _syncCooldown) {
      return; // Henüz çok yakın, sync atlanıyor
    }
    _lastSyncTime = now;
    _syncFromFirestore();
  }

  final _programUpdateController = StreamController<void>.broadcast();
  Stream<void> get onProgramUpdated => _programUpdateController.stream;

  Future<void> saveProgram(StudyProgram program) async {
    _isSelfSaving = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Yerel olarak kaydet
      await prefs.setString(_key, jsonEncode(program.toMap()));

      // 2. Firestore'a kaydet
      if (_userId != null) {
        await _userDoc.collection('metadata').doc('studyProgram').set({
          ...program.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _programUpdateController.add(null);
    } catch (e) {
      debugPrint('Error saving study program: $e');
    } finally {
      // Kısa süre sonra bayrağı sıfırla (stream listener'ın işlemesi için zaman ver)
      Future.microtask(() => _isSelfSaving = false);
    }
  }

  Future<void> clearProgram() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Yerel olarak sil
      await prefs.remove(_key);

      // 2. Firestore'da sil
      if (_userId != null) {
        await _userDoc.collection('metadata').doc('studyProgram').delete();
      }

      _programUpdateController.add(null);
    } catch (e) {
      debugPrint('Error clearing study program: $e');
    }
  }

  Future<void> _syncFromFirestore() async {
    if (_userId == null) return;
    try {
      final doc = await _userDoc
          .collection('metadata')
          .doc('studyProgram')
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final prefs = await SharedPreferences.getInstance();
          final newJson = jsonEncode(StudyProgram.fromMap(data).toMap());
          final oldJson = prefs.getString(_key);

          // Veri değişmemişse UI'ı gereksiz yere tetikleme
          if (newJson == oldJson) {
            debugPrint('StudyProgramService: Firestore sync – veri aynı, emit atlanıyor.');
            return;
          }

          await prefs.setString(_key, newJson);

          // Sadece dışarıdan gelen bir değişiklik ise UI'ı güncelle
          if (!_isSelfSaving) {
            _programUpdateController.add(null);
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing study program from Firestore: $e');
    }
  }

  /// Programı yalnızca local cache'den okur (Firestore çağrısı yok, hızlı).
  Future<StudyProgram?> getProgramFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return StudyProgram.fromMap(Map<String, dynamic>.from(decoded));
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _programUpdateController.close();
  }
}
