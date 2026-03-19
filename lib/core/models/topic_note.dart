import 'package:flutter/material.dart';

class TopicNote {
  final String id;
  final String topicId;
  final String title;
  final String content;
  final String? contentJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorValue;
  final int textColorValue;
  final double fontSize;
  final String paperStyle; // 'plain', 'lined', 'grid', 'dots'
  final List<String> tags;
  final bool isPinned;

  TopicNote({
    required this.id,
    required this.topicId,
    required this.title,
    required this.content,
    this.contentJson,
    required this.createdAt,
    required this.updatedAt,
    this.colorValue = 0xFFFFFFFF,
    this.textColorValue = 0xFF000000,
    this.fontSize = 16.0,
    this.paperStyle = 'plain',
    this.tags = const [],
    this.isPinned = false,
  });

  Color get color => Color(colorValue);
  Color get textColor => Color(textColorValue);

  TopicNote copyWith({
    String? title,
    String? content,
    String? contentJson,
    DateTime? updatedAt,
    int? colorValue,
    int? textColorValue,
    double? fontSize,
    String? paperStyle,
    List<String>? tags,
    bool? isPinned,
  }) {
    return TopicNote(
      id: id,
      topicId: topicId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentJson: contentJson ?? this.contentJson,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: colorValue ?? this.colorValue,
      textColorValue: textColorValue ?? this.textColorValue,
      fontSize: fontSize ?? this.fontSize,
      paperStyle: paperStyle ?? this.paperStyle,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topicId': topicId,
      'title': title,
      'content': content,
      'contentJson': contentJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorValue': colorValue,
      'textColorValue': textColorValue,
      'fontSize': fontSize,
      'paperStyle': paperStyle,
      'tags': tags,
      'isPinned': isPinned,
    };
  }

  factory TopicNote.fromMap(Map<String, dynamic> map) {
    return TopicNote(
      id: map['id'],
      topicId: map['topicId'],
      title: map['title'],
      content: map['content'],
      contentJson: map['contentJson'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
      textColorValue: map['textColorValue'] ?? 0xFF212121,
      fontSize: (map['fontSize'] ?? 16.0).toDouble(),
      paperStyle: map['paperStyle'] ?? 'plain',
      tags: List<String>.from(map['tags'] ?? []),
      isPinned: map['isPinned'] ?? false,
    );
  }
}
