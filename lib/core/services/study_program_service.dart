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
          // Arka planda Firestore ile senkronize et (Eğer Firestore'da daha yenisi varsa)
          _syncFromFirestore();
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

  final _programUpdateController = StreamController<void>.broadcast();
  Stream<void> get onProgramUpdated => _programUpdateController.stream;

  Future<void> saveProgram(StudyProgram program) async {
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
    }
  }

  Future<void> clearProgram() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Yerel olarak sil
      await prefs.remove(_key);

      // 2. Firestore'da sil (vaya pasife çek)
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
          final program = StudyProgram.fromMap(data);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_key, jsonEncode(program.toMap()));
          _programUpdateController.add(null);
        }
      }
    } catch (e) {
      debugPrint('Error syncing study program from Firestore: $e');
    }
  }

  void dispose() {
    _programUpdateController.close();
  }
}
