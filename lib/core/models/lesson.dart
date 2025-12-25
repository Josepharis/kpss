class Lesson {
  final String id;
  final String name;
  final String category; // 'genel_yetenek', 'genel_kultur', 'alan_dersleri'
  final String icon;
  final String color;
  final int topicCount;
  final int questionCount;
  final String description;

  Lesson({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.topicCount,
    required this.questionCount,
    required this.description,
  });
}

