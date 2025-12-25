class OngoingPodcast {
  final String id;
  final String title;
  final int currentMinute;
  final int totalMinutes;
  final String progressColor;
  final String icon;

  OngoingPodcast({
    required this.id,
    required this.title,
    required this.currentMinute,
    required this.totalMinutes,
    required this.progressColor,
    required this.icon,
  });

  double get progress => currentMinute / totalMinutes;
}

