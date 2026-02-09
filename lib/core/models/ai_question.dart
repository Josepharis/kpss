class AiQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const AiQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
    };
  }

  factory AiQuestion.fromMap(Map<String, dynamic> map) {
    final optionsRaw = map['options'];
    return AiQuestion(
      question: (map['question'] ?? '') as String,
      options: (optionsRaw is List)
          ? optionsRaw.map((e) => e.toString()).toList()
          : const <String>[],
      correctIndex: (map['correctIndex'] ?? 0) as int,
      explanation: (map['explanation'] ?? '') as String,
    );
  }
}

