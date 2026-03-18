import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final String id;
  final String title;
  final String date;
  final String? url;
  final String? content;
  final DateTime createdAt;

  NewsItem({
    required this.id,
    required this.title,
    required this.date,
    this.url,
    this.content,
    required this.createdAt,
  });

  factory NewsItem.fromMap(String id, Map<String, dynamic> map) {
    return NewsItem(
      id: id,
      title: map['title'] ?? '',
      date: map['date'] ?? '',
      url: map['url'],
      content: map['content'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DailyInfo {
  final String id;
  final String title;
  final String content;
  final DateTime date;

  DailyInfo({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
  });

  factory DailyInfo.fromMap(String id, Map<String, dynamic> map) {
    return DailyInfo(
      id: id,
      title: map['title'] ?? 'Biliyor Muydunuz?',
      content: map['content'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ExamDate {
  final String id;
  final String title;
  final DateTime date;
  final String? url;

  ExamDate({
    required this.id,
    required this.title,
    required this.date,
    this.url,
  });

  factory ExamDate.fromMap(String id, Map<String, dynamic> map) {
    return ExamDate(
      id: id,
      title: map['title'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      url: map['url'],
    );
  }
}
