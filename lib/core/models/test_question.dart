class TestQuestion {
  final String id;
  final String question;
  final List<String> options;
  /// Her seçenek için altı çizilecek kelime (soru "altı çizili sözcük" dediğinde kullanılır).
  /// options ile aynı sırada, [options[i]] içinde underline edilecek kelime [underlinedWords[i]].
  final List<String>? underlinedWords;
  final int correctAnswerIndex;
  final String explanation;
  final int timeLimitSeconds; // seconds
  final String? topicId; // Hangi konuya ait
  final String? lessonId; // Hangi derse ait
  final String? source; // Kaynak bilgisi
  final int order; // Sıralama için

  TestQuestion({
    required this.id,
    required this.question,
    required this.options,
    this.underlinedWords,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.timeLimitSeconds,
    this.topicId,
    this.lessonId,
    this.source,
    this.order = 0,
  });

  // Convert from Firestore document
  factory TestQuestion.fromMap(Map<String, dynamic> map, String id) {
    final options = List<String>.from(map['options'] ?? []);
    final rawUnderlined = map['underlinedWords'];
    List<String>? underlinedWords;
    if (rawUnderlined is List && rawUnderlined.length == options.length) {
      underlinedWords = rawUnderlined.map((e) => e?.toString() ?? '').toList();
    }
    return TestQuestion(
      id: id,
      question: map['question'] ?? '',
      options: options,
      underlinedWords: underlinedWords,
      correctAnswerIndex: (map['correctAnswerIndex'] ?? 0) as int,
      explanation: map['explanation'] ?? '',
      timeLimitSeconds: (map['timeLimitSeconds'] ?? 60) as int,
      topicId: map['topicId'] as String?,
      lessonId: map['lessonId'] as String?,
      source: map['source'] as String?,
      order: (map['order'] ?? 0) as int,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      if (underlinedWords != null) 'underlinedWords': underlinedWords,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'timeLimitSeconds': timeLimitSeconds,
      if (topicId != null) 'topicId': topicId,
      if (lessonId != null) 'lessonId': lessonId,
      if (source != null) 'source': source,
      'order': order,
    };
  }
}

