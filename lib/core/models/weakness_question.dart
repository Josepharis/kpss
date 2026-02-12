import 'test_question.dart';

class WeaknessQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String lessonId;
  final String topicName;
  final DateTime addedAt;
  final bool isFromWrongAnswer;
  final String? imageUrl;

  WeaknessQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.lessonId,
    required this.topicName,
    required this.addedAt,
    this.isFromWrongAnswer = false,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'lessonId': lessonId,
      'topicName': topicName,
      'addedAt': addedAt.toIso8601String(),
      'isFromWrongAnswer': isFromWrongAnswer,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  factory WeaknessQuestion.fromJson(Map<String, dynamic> json) {
    return WeaknessQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      explanation: json['explanation'] as String,
      lessonId: json['lessonId'] as String? ?? '',
      topicName: json['topicName'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      isFromWrongAnswer: json['isFromWrongAnswer'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  factory WeaknessQuestion.fromTestQuestion({
    required TestQuestion testQuestion,
    required String lessonId,
    required String topicName,
    bool isFromWrongAnswer = false,
  }) {
    return WeaknessQuestion(
      id: testQuestion.id,
      question: testQuestion.question,
      options: testQuestion.options,
      correctAnswerIndex: testQuestion.correctAnswerIndex,
      explanation: testQuestion.explanation,
      lessonId: lessonId,
      topicName: topicName,
      addedAt: DateTime.now(),
      isFromWrongAnswer: isFromWrongAnswer,
      imageUrl: testQuestion.imageUrl,
    );
  }
}
