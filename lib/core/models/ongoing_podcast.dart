class OngoingPodcast {
  final String id;
  final String title;
  final String topic; // Konu ismi
  final int currentMinute;
  final int totalMinutes;
  final String progressColor;
  final String icon;
  final String? topicId;
  final String? lessonId;
  final String audioUrl;

  OngoingPodcast({
    required this.id,
    required this.title,
    required this.topic,
    required this.currentMinute,
    required this.totalMinutes,
    required this.progressColor,
    required this.icon,
    this.topicId,
    this.lessonId,
    required this.audioUrl,
  });

  double get progress => currentMinute / totalMinutes;
}

