class DailySummary {
  final int solvedQuestions;
  final int studyTimeMinutes;
  final int lessonCount;
  final double successRate;

  DailySummary({
    required this.solvedQuestions,
    required this.studyTimeMinutes,
    required this.lessonCount,
    required this.successRate,
  });

  String get studyTimeFormatted {
    final hours = studyTimeMinutes ~/ 60;
    final minutes = studyTimeMinutes % 60;
    if (hours > 0) {
      return '${hours}s ${minutes}dk';
    }
    return '${minutes}dk';
  }
}

