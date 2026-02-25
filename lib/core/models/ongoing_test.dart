class OngoingTest {
  final String id;
  final String title;
  final String topic;
  final int currentQuestion;
  final int totalQuestions;
  final String progressColor;
  final String icon;
  final String topicId;
  final String lessonId;
  final int score;
  final int attemptCount;

  OngoingTest({
    required this.id,
    required this.title,
    required this.topic,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.progressColor,
    required this.icon,
    required this.topicId,
    required this.lessonId,
    this.score = 0,
    this.attemptCount = 1,
  });

  double get progress => currentQuestion / totalQuestions;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'currentQuestion': currentQuestion,
      'totalQuestions': totalQuestions,
      'progressColor': progressColor,
      'icon': icon,
      'topicId': topicId,
      'lessonId': lessonId,
      'score': score,
      'attemptCount': attemptCount,
    };
  }

  factory OngoingTest.fromMap(Map<String, dynamic> map) {
    return OngoingTest(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      topic: map['topic'] ?? '',
      currentQuestion: map['currentQuestion'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 1,
      progressColor: map['progressColor'] ?? 'blue',
      icon: map['icon'] ?? 'atom',
      topicId: map['topicId'] ?? '',
      lessonId: map['lessonId'] ?? '',
      score: map['score'] ?? 0,
      attemptCount: map['attemptCount'] ?? 1,
    );
  }
}
