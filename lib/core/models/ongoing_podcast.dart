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
      'audioUrl': audioUrl,
    };
  }

  factory OngoingPodcast.fromMap(Map<String, dynamic> map) {
    return OngoingPodcast(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      topic: map['topic'] ?? '',
      currentMinute: map['currentMinute'] ?? 0,
      totalMinutes: map['totalMinutes'] ?? 1,
      progressColor: map['progressColor'] ?? 'blue',
      icon: map['icon'] ?? 'atom',
      topicId: map['topicId'],
      lessonId: map['lessonId'],
      audioUrl: map['audioUrl'] ?? '',
    );
  }
}

