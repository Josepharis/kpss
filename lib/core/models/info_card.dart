class InfoCard {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String color;
  final String topicId;
  final String lessonId;
  final int cardCount;

  InfoCard({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.topicId,
    required this.lessonId,
    required this.cardCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon': icon,
      'color': color,
      'topicId': topicId,
      'lessonId': lessonId,
      'cardCount': cardCount,
    };
  }

  factory InfoCard.fromMap(Map<String, dynamic> map) {
    return InfoCard(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? 'book',
      color: map['color'] ?? 'green',
      topicId: map['topicId'] ?? '',
      lessonId: map['lessonId'] ?? '',
      cardCount: map['cardCount'] ?? 0,
    );
  }
}

