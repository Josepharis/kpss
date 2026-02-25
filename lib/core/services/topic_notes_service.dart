import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/topic_note.dart';

class TopicNotesService {
  static final TopicNotesService _instance = TopicNotesService._internal();
  factory TopicNotesService() => _instance;
  TopicNotesService._internal();

  static TopicNotesService get instance => _instance;

  Future<File> _getNotesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/topic_notes.json');
  }

  Future<List<TopicNote>> getAllNotes() async {
    try {
      final file = await _getNotesFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => TopicNote.fromMap(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TopicNote>> getNotesForTopic(String topicId) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note.topicId == topicId).toList();
  }

  Future<void> saveNote(TopicNote note) async {
    final allNotes = await getAllNotes();
    final index = allNotes.indexWhere((element) => element.id == note.id);
    if (index != -1) {
      allNotes[index] = note;
    } else {
      allNotes.add(note);
    }
    await _saveAllNotes(allNotes);
  }

  Future<void> deleteNote(String noteId) async {
    final allNotes = await getAllNotes();
    allNotes.removeWhere((element) => element.id == noteId);
    await _saveAllNotes(allNotes);
  }

  Future<void> _saveAllNotes(List<TopicNote> notes) async {
    try {
      final file = await _getNotesFile();
      final jsonList = notes.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving notes: $e');
    }
  }
}
