class Video {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final int durationMinutes;
  final String topicId;
  final String lessonId;
  final int order;

  Video({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.durationMinutes,
    required this.topicId,
    required this.lessonId,
    required this.order,
  });
}

