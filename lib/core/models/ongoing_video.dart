class OngoingVideo {
  final String id;
  final String title;
  final String topic;
  final int currentMinute;
  final int totalMinutes;
  final String progressColor;
  final String icon;
  final String topicId;
  final String lessonId;
  final String videoUrl;

  OngoingVideo({
    required this.id,
    required this.title,
    required this.topic,
    required this.currentMinute,
    required this.totalMinutes,
    required this.progressColor,
    required this.icon,
    required this.topicId,
    required this.lessonId,
    required this.videoUrl,
  });

  double get progress => currentMinute / totalMinutes;
}

