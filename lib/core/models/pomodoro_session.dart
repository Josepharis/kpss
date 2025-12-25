class PomodoroSession {
  final String id;
  final DateTime date;
  final int sessionCount;
  final int sessionDuration; // minutes
  final int totalMinutes;
  final String? topic;
  final int? correctAnswers;
  final int? wrongAnswers;
  final int? totalQuestions;
  final String? notes;

  PomodoroSession({
    required this.id,
    required this.date,
    required this.sessionCount,
    required this.sessionDuration,
    required this.totalMinutes,
    this.topic,
    this.correctAnswers,
    this.wrongAnswers,
    this.totalQuestions,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'sessionCount': sessionCount,
      'sessionDuration': sessionDuration,
      'totalMinutes': totalMinutes,
      'topic': topic,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'totalQuestions': totalQuestions,
      'notes': notes,
    };
  }

  factory PomodoroSession.fromJson(Map<String, dynamic> json) {
    return PomodoroSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      sessionCount: json['sessionCount'] as int,
      sessionDuration: json['sessionDuration'] as int,
      totalMinutes: json['totalMinutes'] as int,
      topic: json['topic'] as String?,
      correctAnswers: json['correctAnswers'] as int?,
      wrongAnswers: json['wrongAnswers'] as int?,
      totalQuestions: json['totalQuestions'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

