class Podcast {
  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final int durationMinutes;
  final String thumbnailUrl;

  Podcast({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.durationMinutes,
    this.thumbnailUrl = '',
  });
}

