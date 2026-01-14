class OngoingFlashCard {
  final String id;
  final String title;
  final String topic;
  final int currentCard;
  final int totalCards;
  final String progressColor;
  final String icon;
  final String topicId;
  final String lessonId;

  OngoingFlashCard({
    required this.id,
    required this.title,
    required this.topic,
    required this.currentCard,
    required this.totalCards,
    required this.progressColor,
    required this.icon,
    required this.topicId,
    required this.lessonId,
  });

  double get progress => currentCard / totalCards;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'topic': topic,
      'currentCard': currentCard,
      'totalCards': totalCards,
      'progressColor': progressColor,
      'icon': icon,
      'topicId': topicId,
      'lessonId': lessonId,
    };
  }

  factory OngoingFlashCard.fromMap(Map<String, dynamic> map) {
    return OngoingFlashCard(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      topic: map['topic'] ?? '',
      currentCard: map['currentCard'] ?? 0,
      totalCards: map['totalCards'] ?? 1,
      progressColor: map['progressColor'] ?? 'green',
      icon: map['icon'] ?? 'book',
      topicId: map['topicId'] ?? '',
      lessonId: map['lessonId'] ?? '',
    );
  }
}
