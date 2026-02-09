import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// PDF notlarını local'de saklamak için servis
/// Notlar JSON formatında cihazın local storage'ında saklanır
class PdfNotesService {
  static PdfNotesService? _instance;
  static PdfNotesService get instance {
    _instance ??= PdfNotesService._();
    return _instance!;
  }

  PdfNotesService._();

  /// PDF URL'den unique bir key oluştur
  String _getPdfKey(String pdfUrl) {
    final bytes = utf8.encode(pdfUrl);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Notların saklanacağı dosya yolunu al
  Future<File> _getNotesFile(String pdfUrl) async {
    final directory = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${directory.path}/pdf_notes');
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    final pdfKey = _getPdfKey(pdfUrl);
    return File('${notesDir.path}/$pdfKey.json');
  }

  /// PDF notlarını kaydet
  Future<bool> saveNotes(String pdfUrl, List<PdfNote> notes) async {
    try {
      final file = await _getNotesFile(pdfUrl);
      final notesData = {
        'pdfUrl': pdfUrl,
        'savedAt': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toMap()).toList(),
      };
      await file.writeAsString(jsonEncode(notesData));
      return true;
    } catch (e) {
      print('❌ Error saving PDF notes: $e');
      return false;
    }
  }

  /// PDF notlarını yükle
  Future<List<PdfNote>> loadNotes(String pdfUrl) async {
    try {
      final file = await _getNotesFile(pdfUrl);
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final notesList = data['notes'] as List<dynamic>;
      return notesList.map((note) => PdfNote.fromMap(note as Map<String, dynamic>)).toList();
    } catch (e) {
      print('❌ Error loading PDF notes: $e');
      return [];
    }
  }

  /// PDF notlarını sil
  Future<bool> deleteNotes(String pdfUrl) async {
    try {
      final file = await _getNotesFile(pdfUrl);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print('❌ Error deleting PDF notes: $e');
      return false;
    }
  }

  /// Notların var olup olmadığını kontrol et
  Future<bool> hasNotes(String pdfUrl) async {
    try {
      final file = await _getNotesFile(pdfUrl);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}

/// PDF üzerindeki bir not
class PdfNote {
  final int pageNumber;
  final String type; // 'drawing', 'text', 'highlight'
  final List<DrawingPoint> points; // Çizim noktaları
  final String? text; // Metin notu
  final Offset? position; // Notun konumu
  final Color color; // Not rengi
  final double strokeWidth; // Çizgi kalınlığı
  final DateTime createdAt;

  PdfNote({
    required this.pageNumber,
    required this.type,
    required this.points,
    this.text,
    this.position,
    required this.color,
    this.strokeWidth = 2.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'pageNumber': pageNumber,
      'type': type,
      'points': points.map((p) => p.toMap()).toList(),
      'text': text,
      'position': position != null ? {'x': position!.dx, 'y': position!.dy} : null,
      'color': {
        'r': color.red,
        'g': color.green,
        'b': color.blue,
        'a': color.alpha,
      },
      'strokeWidth': strokeWidth,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PdfNote.fromMap(Map<String, dynamic> map) {
    return PdfNote(
      pageNumber: map['pageNumber'] as int,
      type: map['type'] as String,
      points: (map['points'] as List<dynamic>)
          .map((p) => DrawingPoint.fromMap(p as Map<String, dynamic>))
          .toList(),
      text: map['text'] as String?,
      position: map['position'] != null
          ? Offset(
              (map['position'] as Map<String, dynamic>)['x'] as double,
              (map['position'] as Map<String, dynamic>)['y'] as double,
            )
          : null,
      color: Color.fromARGB(
        (map['color'] as Map<String, dynamic>)['a'] as int,
        (map['color'] as Map<String, dynamic>)['r'] as int,
        (map['color'] as Map<String, dynamic>)['g'] as int,
        (map['color'] as Map<String, dynamic>)['b'] as int,
      ),
      strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 2.0,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// Çizim noktası
class DrawingPoint {
  final double x;
  final double y;
  final double? pressure; // Basınç (opsiyonel)

  DrawingPoint({
    required this.x,
    required this.y,
    this.pressure,
  });

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
    };
  }

  factory DrawingPoint.fromMap(Map<String, dynamic> map) {
    return DrawingPoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      pressure: map['pressure'] != null ? (map['pressure'] as num).toDouble() : null,
    );
  }

  Offset toOffset() => Offset(x, y);
}
