import 'test_question.dart';

class WeaknessQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String lessonId; // Ders ID
  final String topicName; // Konu adı
  final DateTime addedAt;
  final bool isFromWrongAnswer; // Yanlış cevaplanan soru mu yoksa manuel eklenen mi

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
  });

  // JSON'a dönüştürme
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
    };
  }

  // JSON'dan oluşturma
  factory WeaknessQuestion.fromJson(Map<String, dynamic> json) {
    return WeaknessQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      explanation: json['explanation'] as String,
      lessonId: json['lessonId'] as String? ?? '', // Eski veriler için backward compatibility
      topicName: json['topicName'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      isFromWrongAnswer: json['isFromWrongAnswer'] as bool? ?? false,
    );
  }

  // TestQuestion'dan WeaknessQuestion'a dönüştürme
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
    );
  }
}

