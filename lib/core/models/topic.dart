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
  final int order; // Sıralama için

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
    this.order = 0,
  });

  // Convert from Firestore document
  factory Topic.fromMap(Map<String, dynamic> map, String id) {
    return Topic(
      id: id,
      lessonId: map['lessonId'] ?? '',
      name: map['name'] ?? '',
      subtitle: map['subtitle'] ?? '',
      duration: map['duration'] ?? '0h 0min',
      averageQuestionCount: (map['averageQuestionCount'] ?? 0) as int,
      testCount: (map['testCount'] ?? 0) as int,
      podcastCount: (map['podcastCount'] ?? 0) as int,
      videoCount: (map['videoCount'] ?? 0) as int,
      noteCount: (map['noteCount'] ?? 0) as int,
      progress: (map['progress'] ?? 0.0) as double,
      order: (map['order'] ?? 0) as int,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'lessonId': lessonId,
      'name': name,
      'subtitle': subtitle,
      'duration': duration,
      'averageQuestionCount': averageQuestionCount,
      'testCount': testCount,
      'podcastCount': podcastCount,
      'videoCount': videoCount,
      'noteCount': noteCount,
      'progress': progress,
      'order': order,
    };
  }
}
