class Lesson {
  final String id;
  final String name;
  final String category; // 'genel_yetenek', 'genel_kultur', 'alan_dersleri'
  final String icon;
  final String color;
  final int topicCount;
  final int questionCount;
  final String description;
  final int order; // Sıralama için

  Lesson({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.topicCount,
    required this.questionCount,
    required this.description,
    this.order = 0,
  });

  // Convert from Firestore document
  factory Lesson.fromMap(Map<String, dynamic> map, String id) {
    return Lesson(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      icon: map['icon'] ?? 'book',
      color: map['color'] ?? 'blue',
      topicCount: (map['topicCount'] ?? 0) as int,
      questionCount: (map['questionCount'] ?? 0) as int,
      description: map['description'] ?? '',
      order: (map['order'] ?? 0) as int,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'icon': icon,
      'color': color,
      'topicCount': topicCount,
      'questionCount': questionCount,
      'description': description,
      'order': order,
    };
  }
}

