class OngoingTest {
  final String id;
  final String title;
  final String topic;
  final int currentQuestion;
  final int totalQuestions;
  final String progressColor;
  final String icon;

  OngoingTest({
    required this.id,
    required this.title,
    required this.topic,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.progressColor,
    required this.icon,
  });

  double get progress => currentQuestion / totalQuestions;
}
