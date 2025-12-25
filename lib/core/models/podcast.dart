class Podcast {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final int durationMinutes;
  final String thumbnailUrl;
  final String? topicId; // Hangi konuya ait
  final String? lessonId; // Hangi derse ait
  final int order; // Sıralama için

  Podcast({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.durationMinutes,
    this.thumbnailUrl = '',
    this.topicId,
    this.lessonId,
    this.order = 0,
  });

  // Convert from Firestore document
  factory Podcast.fromMap(Map<String, dynamic> map, String id) {
    return Podcast(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      durationMinutes: (map['durationMinutes'] ?? 0) as int,
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      topicId: map['topicId'] as String?,
      lessonId: map['lessonId'] as String?,
      order: (map['order'] ?? 0) as int,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'audioUrl': audioUrl,
      'durationMinutes': durationMinutes,
      'thumbnailUrl': thumbnailUrl,
      if (topicId != null) 'topicId': topicId,
      if (lessonId != null) 'lessonId': lessonId,
      'order': order,
    };
  }
}

