import 'package:cloud_firestore/cloud_firestore.dart';

enum ErrorContentType { question, card }

enum ErrorType {
  contentError,
  optionError,
  multipleCorrect,
  typo,
  other,
}

extension ErrorTypeExtension on ErrorType {
  String getLabel(String contentType) {
    switch (this) {
      case ErrorType.contentError:
        return contentType == 'flash_card' ? 'Kart İçeriğinde Hata' : 'Soru İçeriğinde Hata';
      case ErrorType.optionError:
        return 'Şıklarda Hata';
      case ErrorType.multipleCorrect:
        return 'Birden Fazla Doğru Cevap';
      case ErrorType.typo:
        return 'Yazım Yanlışı';
      case ErrorType.other:
        return 'Diğer';
    }
  }

  // Still keeping old getter for backward compatibility or simple usage if needed, but updated
  String get label => getLabel('question');
}

class ErrorReport {
  final String? id;
  final String userId;
  final String userName;
  final String contentId;
  final String contentType; // 'question' or 'flash_card'
  final String errorType;
  final String description;
  final String topicId;
  final String topicName;
  final String lessonId;
  final DateTime timestamp;
  final bool isResolved;
  final String? contentPreview; // For quick view in admin panel

  ErrorReport({
    this.id,
    required this.userId,
    required this.userName,
    required this.contentId,
    required this.contentType,
    required this.errorType,
    required this.description,
    required this.topicId,
    required this.topicName,
    required this.lessonId,
    required this.timestamp,
    this.isResolved = false,
    this.contentPreview,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'contentId': contentId,
      'contentType': contentType,
      'errorType': errorType,
      'description': description,
      'topicId': topicId,
      'topicName': topicName,
      'lessonId': lessonId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isResolved': isResolved,
      if (contentPreview != null) 'contentPreview': contentPreview,
    };
  }

  factory ErrorReport.fromMap(Map<String, dynamic> map, String id) {
    return ErrorReport(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonim',
      contentId: map['contentId'] ?? '',
      contentType: map['contentType'] ?? '',
      errorType: map['errorType'] ?? 'Diğer',
      description: map['description'] ?? '',
      topicId: map['topicId'] ?? '',
      topicName: map['topicName'] ?? '',
      lessonId: map['lessonId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isResolved: map['isResolved'] ?? false,
      contentPreview: map['contentPreview'],
    );
  }
}
