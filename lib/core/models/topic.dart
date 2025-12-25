class Topic {
  final String id;
  final String lessonId;
  final String name;
  final String subtitle;
  final String duration; // e.g., "2h 30min"
  final int averageQuestionCount;
  final int testCount;
  final int podcastCount;
  final int videoCount;
  final int noteCount;
  final double progress; // 0.0 - 1.0

  Topic({
    required this.id,
    required this.lessonId,
    required this.name,
    required this.subtitle,
    required this.duration,
    required this.averageQuestionCount,
    required this.testCount,
    required this.podcastCount,
    required this.videoCount,
    required this.noteCount,
    this.progress = 0.0,
  });
}
