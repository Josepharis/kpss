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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'currentMinute': currentMinute,
      'totalMinutes': totalMinutes,
      'progressColor': progressColor,
      'icon': icon,
      'topicId': topicId,
      'lessonId': lessonId,
      'videoUrl': videoUrl,
    };
  }

  factory OngoingVideo.fromMap(Map<String, dynamic> map) {
    return OngoingVideo(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      topic: map['topic'] ?? '',
      currentMinute: map['currentMinute'] ?? 0,
      totalMinutes: map['totalMinutes'] ?? 1,
      progressColor: map['progressColor'] ?? 'red',
      icon: map['icon'] ?? 'atom',
      topicId: map['topicId'] ?? '',
      lessonId: map['lessonId'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
    );
  }
}

