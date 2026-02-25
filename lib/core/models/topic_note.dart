import 'package:flutter/material.dart';

class TopicNote {
  final String id;
  final String topicId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int colorValue;
  final List<String> tags;
  final bool isPinned;

  TopicNote({
    required this.id,
    required this.topicId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.colorValue = 0xFFFFFFFF,
    this.tags = const [],
    this.isPinned = false,
  });

  Color get color => Color(colorValue);

  TopicNote copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    int? colorValue,
    List<String>? tags,
    bool? isPinned,
  }) {
    return TopicNote(
      id: id,
      topicId: topicId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: colorValue ?? this.colorValue,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'colorValue': colorValue,
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
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      colorValue: map['colorValue'] ?? 0xFFFFFFFF,
      tags: List<String>.from(map['tags'] ?? []),
      isPinned: map['isPinned'] ?? false,
    );
  }
}
