class PomodoroSession {
  final String id;
  final DateTime date;
  final int sessionCount;
  final int sessionDuration; // minutes
  final int totalMinutes;
  final int totalSeconds;
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
    required this.totalSeconds,
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
      'totalSeconds': totalSeconds,
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
      totalSeconds: json['totalSeconds'] as int? ?? (json['totalMinutes'] as int) * 60,
      topic: json['topic'] as String?,
      correctAnswers: json['correctAnswers'] as int?,
      wrongAnswers: json['wrongAnswers'] as int?,
      totalQuestions: json['totalQuestions'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

